import UIKit
import WordPressUI

class CollapsableHeaderViewController: UIViewController, NoResultsViewHost {
    enum SeparatorStyle {
        case visible
        case automatic
        case hidden
    }

    let scrollableView: UIScrollView
    let accessoryView: UIView?
    let mainTitle: String
    let navigationBarTitle: String?
    let prompt: String?
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let defaultActionTitle: String?
    open var accessoryBarHeight: CGFloat {
        return 44
    }

    open var separatorStyle: SeparatorStyle {
        return self.hasAccessoryBar ? .visible : .automatic
    }

    // If set to true, the header will always be pushed down after rotating from compact to regular
    // If set to false, this will only happen for no results views (default behavior).
    var alwaysResetHeaderOnRotation: Bool {
        false
    }

    // If set to true, all header titles will always be shown.
    // If set to false, largeTitleView and promptView labels are hidden in compact height (default behavior).
    //
    var alwaysShowHeaderTitles: Bool {
        false
    }

    // Set this property to true to add a custom footerView with custom sizing when scrollableView is UITableView.
    var allowCustomTableFooterView: Bool {
        false
    }

    private let hasDefaultAction: Bool
    private var notificationObservers: [NSObjectProtocol] = []
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var headerView: CollapsableHeaderView!

    let titleView: UILabel = {
        let title = UILabel(frame: .zero)
        title.adjustsFontForContentSizeCategory = true
        title.font = WPStyleGuide.serifFontForTextStyle(UIFont.TextStyle.largeTitle, fontWeight: .semibold).withSize(17)
        title.isHidden = true
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 2 / 3
        return title
    }()

    @IBOutlet weak var largeTitleTopSpacingConstraint: NSLayoutConstraint!

    @IBOutlet weak var headerStackView: UIStackView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var largeTitleView: UILabel!
    private var headerImage: UIImage?

    @IBOutlet weak var promptView: UILabel!
    @IBOutlet weak var accessoryBar: UIView!
    @IBOutlet weak var accessoryBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryBarTopCompactConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var defaultActionButton: UIButton!
    @IBOutlet weak var secondaryActionButton: UIButton!
    @IBOutlet weak var primaryActionButton: UIButton!
    @IBOutlet weak var selectedStateButtonsContainer: UIStackView!
    @IBOutlet weak var seperator: UIView!

    /// Flag indicating if the action button stack view (selectedStateButtonsContainer) is vertical.
    /// Used when calculating the footer height.
    private var usesVerticalActionButtons: Bool = false

    /// This  is used as a means to adapt to different text sizes to force the desired layout and then active `headerHeightConstraint`
    /// when scrolling begins to allow pushing the non static items out of the scrollable area.
    @IBOutlet weak var initialHeaderTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleToSubtitleSpacing: NSLayoutConstraint!
    @IBOutlet weak var subtitleToCategoryBarSpacing: NSLayoutConstraint!

    /// As the Header expands it allows a little bit of extra room between the bottom of the filter bar and the bottom of the header view.
    /// These next two constaints help account for that slight adustment.
    @IBOutlet weak var minHeaderBottomSpacing: NSLayoutConstraint!
    @IBOutlet weak var maxHeaderBottomSpacing: NSLayoutConstraint!
    @IBOutlet weak var scrollableContainerBottomConstraint: NSLayoutConstraint!

    @IBOutlet var visualEffects: [UIVisualEffectView]! {
        didSet {
            visualEffects.forEach { (visualEffect) in
                visualEffect.effect = UIBlurEffect.init(style: .systemChromeMaterial)
                // Allow touches to pass through to the scroll view behind the header.
                visualEffect.contentView.isUserInteractionEnabled = false
            }
        }
    }

    private var footerHeight: CGFloat {
        let verticalMargins: CGFloat = 16
        let buttonHeight: CGFloat = 44
        let safeArea = (UIApplication.shared.mainWindow?.safeAreaInsets.bottom ?? 0)

        var height = verticalMargins + buttonHeight + verticalMargins + safeArea

        if usesVerticalActionButtons && !secondaryActionButton.isHidden {
            height += (buttonHeight + selectedStateButtonsContainer.spacing)
        }

        return height
    }

    private var isShowingNoResults: Bool = false {
        didSet {
            if oldValue != isShowingNoResults {
                updateHeaderDisplay()
            }
        }
    }

    private let hasAccessoryBar: Bool
    private var shouldHideAccessoryBar: Bool {
        return isShowingNoResults || !hasAccessoryBar
    }

    private var shouldUseCompactLayout: Bool {
        return !alwaysShowHeaderTitles && traitCollection.verticalSizeClass == .compact
    }

    private var topInset: CGFloat = 0
    private var _maxHeaderHeight: CGFloat = 0
    private var maxHeaderHeight: CGFloat {
        if shouldUseCompactLayout {
            return minHeaderHeight
        } else {
            return _maxHeaderHeight
        }
    }

    private var _midHeaderHeight: CGFloat = 0
    private var midHeaderHeight: CGFloat {
        if shouldUseCompactLayout {
            return minHeaderHeight
        } else {
            return _midHeaderHeight
        }
    }
    private var minHeaderHeight: CGFloat = 0

    private var accentColor: UIColor {
        return UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if traitCollection.userInterfaceStyle == .dark {
                return UIAppColor.primary(.shade40)
            } else {
                return UIAppColor.primary(.shade50)
            }
        }
    }

    // MARK: - Static Helpers
    public static func closeButton(target: Any?, action: Selector) -> UIBarButtonItem {
        let closeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        closeButton.layer.cornerRadius = 15
        closeButton.accessibilityLabel = NSLocalizedString("Close", comment: "Dismisses the current screen")
        closeButton.accessibilityIdentifier = "close-button"
        closeButton.setImage(UIImage.gridicon(.crossSmall), for: .normal)
        closeButton.addTarget(target, action: action, for: .touchUpInside)

        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.systemFill
            } else {
                return UIColor.quaternarySystemFill
            }
        }

        return UIBarButtonItem(customView: closeButton)
    }

    // MARK: - Initializers
    /// Configure and display the no results view controller
    ///
    /// - Parameters:
    ///   - scrollableView: Populates the scrollable area of this container. Required.
    ///   - mainTitle: The Large title and small title in the header. Required.
    ///   - navigationBarTitle: The Large title in the header. Optional.
    ///   - headerImage: An image displayed in the header. Optional.
    ///   - prompt: The subtitle/prompt in the header. Required.
    ///   - primaryActionTitle: The button title for the right most button when an item is selected. Required.
    ///   - secondaryActionTitle: The button title for the left most button when an item is selected. Optional - nil results in the left most button being hidden when an item is selected.
    ///   - defaultActionTitle: The button title for the button that is displayed when no item is selected. Optional - nil results in the footer being hidden when no item is selected.
    ///   - accessoryView: The view to be placed in the placeholder of the accessory bar. Optional - The default is nil.
    ///
    init(scrollableView: UIScrollView,
         mainTitle: String,
         navigationBarTitle: String? = nil,
         headerImage: UIImage? = nil,
         prompt: String? = nil,
         primaryActionTitle: String,
         secondaryActionTitle: String? = nil,
         defaultActionTitle: String? = nil,
         accessoryView: UIView? = nil) {
        self.scrollableView = scrollableView
        self.mainTitle = mainTitle
        self.navigationBarTitle = navigationBarTitle
        self.headerImage = headerImage
        self.prompt = prompt
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.defaultActionTitle = defaultActionTitle
        self.hasAccessoryBar = (accessoryView != nil)
        self.hasDefaultAction = (defaultActionTitle != nil)
        self.accessoryView = accessoryView
        super.init(nibName: "\(CollapsableHeaderViewController.self)", bundle: .main)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        insertChildView()
        insertAccessoryView()
        configureSubtitleToCategoryBarSpacing()
        configureHeaderImageView()
        navigationItem.titleView = titleView
        largeTitleView.font = UIFont.make(.recoleta, textStyle: .largeTitle, weight: .medium)
        toggleFilterBarConstraints()
        styleButtons()
        setStaticText()
        scrollableView.delegate = self

        updateSeperatorStyle()
    }

    /// The estimated content size of the scroll view. This is used to adjust the content insests to allow the header to be scrollable to be collapsable still when
    /// it's not populated with enough data. This is desirable to help maintain the header's state when the filtered options change and reduce the content size.
    open func estimatedContentSize() -> CGSize {
        return scrollableView.contentSize
    }

    override func viewWillAppear(_ animated: Bool) {
        if !isViewOnScreen() {
            layoutHeader()
        }

        configureHeaderTitleVisibility()
        startObservingKeyboardChanges()
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        stopObservingKeyboardChanges()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        guard isShowingNoResults || alwaysResetHeaderOnRotation else {
            return
        }

        coordinator.animate(alongsideTransition: nil) { (_) in
            self.accessoryBarTopCompactConstraint.isActive = self.shouldUseCompactLayout
            self.updateHeaderDisplay()
            // we're keeping this only for no results,
            // as originally intended before introducing the flag alwaysResetHeaderOnRotation
            if self.shouldHideAccessoryBar, self.isShowingNoResults {
                self.disableInitialLayoutHelpers()
                self.snapToHeight(self.scrollableView, height: self.minHeaderHeight, animated: false)
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            styleButtons()
        }

        if let previousTraitCollection, traitCollection.verticalSizeClass != previousTraitCollection.verticalSizeClass {
            isUserInitiatedScroll = false
            configureHeaderTitleVisibility()
            layoutHeaderInsets()

            // This helps reset the header changes after a rotation.
            scrollViewDidScroll(scrollableView)
            scrollViewDidEndDecelerating(scrollableView)
        } else {
            layoutHeader()
            snapToHeight(scrollableView)
        }
    }

    // MARK: - Footer Actions
    @IBAction open func defaultActionSelected(_ sender: Any) {
        /* This should be overriden in a child class in order to enable support. */
    }

    @IBAction open func primaryActionSelected(_ sender: Any) {
        /* This should be overriden in a child class in order to enable support. */
    }

    @IBAction open func secondaryActionSelected(_ sender: Any) {
        /* This should be overriden in a child class in order to enable support. */
    }

    // MARK: - Format Nav Bar

    // MARK: - View Styling
    private func setStaticText() {
        titleView.text = navigationBarTitle ?? mainTitle
        titleView.sizeToFit()
        largeTitleView.text = mainTitle
        promptView.isHidden = prompt == nil
        promptView.text = prompt
        primaryActionButton.setTitle(primaryActionTitle, for: .normal)

        if let defaultActionTitle {
            defaultActionButton.setTitle(defaultActionTitle, for: .normal)
        } else {
            footerHeightContraint.constant = 0
            footerView.layoutIfNeeded()
            defaultActionButton.isHidden = true
            selectedStateButtonsContainer.isHidden = false
        }

        if let secondaryActionTitle {
            secondaryActionButton.setTitle(secondaryActionTitle, for: .normal)
        } else {
            secondaryActionButton.isHidden = true
        }
    }

    private func insertChildView() {
        scrollableView.translatesAutoresizingMaskIntoConstraints = false
        scrollableView.clipsToBounds = false
        let top = NSLayoutConstraint(item: scrollableView, attribute: .top, relatedBy: .equal, toItem: containerView, attribute: .top, multiplier: 1, constant: 0)
        let bottom = NSLayoutConstraint(item: scrollableView, attribute: .bottom, relatedBy: .equal, toItem: containerView, attribute: .bottom, multiplier: 1, constant: 0)
        let leading = NSLayoutConstraint(item: scrollableView, attribute: .leading, relatedBy: .equal, toItem: containerView, attribute: .leading, multiplier: 1, constant: 0)
        let trailing = NSLayoutConstraint(item: scrollableView, attribute: .trailing, relatedBy: .equal, toItem: containerView, attribute: .trailing, multiplier: 1, constant: 0)
        containerView.addSubview(scrollableView)
        containerView.addConstraints([top, bottom, leading, trailing])
    }

    private func insertAccessoryView() {
        guard let accessoryView else {
            return
        }

        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        let top = NSLayoutConstraint(item: accessoryView, attribute: .top, relatedBy: .equal, toItem: accessoryBar, attribute: .top, multiplier: 1, constant: 0)
        let bottom = NSLayoutConstraint(item: accessoryView, attribute: .bottom, relatedBy: .equal, toItem: accessoryBar, attribute: .bottom, multiplier: 1, constant: 0)
        let leading = NSLayoutConstraint(item: accessoryView, attribute: .leading, relatedBy: .equal, toItem: accessoryBar, attribute: .leading, multiplier: 1, constant: 0)
        let trailing = NSLayoutConstraint(item: accessoryView, attribute: .trailing, relatedBy: .equal, toItem: accessoryBar, attribute: .trailing, multiplier: 1, constant: 0)
        accessoryBar.addSubview(accessoryView)
        accessoryBar.addConstraints([top, bottom, leading, trailing])
    }

    private func configureHeaderImageView() {
        headerImageView.isHidden = (headerImage == nil)
        headerImageView.image = headerImage
    }

    private func configureSubtitleToCategoryBarSpacing() {
        if prompt?.isEmpty ?? true {
            subtitleToCategoryBarSpacing.constant = 0
        }
    }

    func configureHeaderTitleVisibility() {
        largeTitleView.isHidden = shouldUseCompactLayout
        promptView.isHidden = shouldUseCompactLayout
    }

    private func styleButtons() {
        let seperator = UIColor.separator

        [defaultActionButton, secondaryActionButton].forEach { (button) in
            button?.titleLabel?.font = WPStyleGuide.fontForTextStyle(.body, fontWeight: .medium)
            button?.titleLabel?.adjustsFontSizeToFitWidth = true
            button?.titleLabel?.adjustsFontForContentSizeCategory = true
            button?.layer.borderColor = seperator.cgColor
            button?.layer.borderWidth = 1
            button?.layer.cornerRadius = 8
        }

        primaryActionButton.titleLabel?.font = WPStyleGuide.fontForTextStyle(.body, fontWeight: .medium)
        primaryActionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        primaryActionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        primaryActionButton.backgroundColor = accentColor
        primaryActionButton.layer.cornerRadius = 8
    }

    // MARK: - Header and Footer Sizing
    private func toggleFilterBarConstraints() {
        accessoryBarHeightConstraint.constant = shouldHideAccessoryBar ? 0 : accessoryBarHeight
        let collapseBottomSpacing = shouldHideAccessoryBar || (separatorStyle == .hidden)
        maxHeaderBottomSpacing.constant = collapseBottomSpacing ? 1 : 24
        minHeaderBottomSpacing.constant = collapseBottomSpacing ? 1 : 9
    }

    private func updateHeaderDisplay() {
        headerHeightConstraint.isActive = false
        initialHeaderTopConstraint.isActive = true
        toggleFilterBarConstraints()
        accessoryBar.layoutIfNeeded()
        headerView.layoutIfNeeded()
        calculateHeaderSnapPoints()
        layoutHeaderInsets()
    }

    private func calculateHeaderSnapPoints() {
        let accessoryBarSpacing: CGFloat
        if shouldHideAccessoryBar {
            minHeaderHeight = 1
            accessoryBarSpacing = minHeaderHeight
        } else {
            minHeaderHeight = accessoryBarHeightConstraint.constant + minHeaderBottomSpacing.constant
            accessoryBarSpacing = accessoryBarHeightConstraint.constant + maxHeaderBottomSpacing.constant
        }
        _midHeaderHeight = titleToSubtitleSpacing.constant + promptView.frame.height + subtitleToCategoryBarSpacing.constant + accessoryBarSpacing
        _maxHeaderHeight = largeTitleTopSpacingConstraint.constant + headerStackView.frame.height + _midHeaderHeight
    }

    private func layoutHeaderInsets() {
        let topInset: CGFloat = maxHeaderHeight
        if let tableView = scrollableView as? UITableView {
            tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: topInset))
            tableView.tableHeaderView?.backgroundColor = .clear
        } else {
            self.topInset = topInset
            scrollableView.contentInset.top = topInset
        }

        updateFooterInsets()
    }

    /*
     * Calculates the needed space for the footer to allow the header to still collapse but also to prevent unneeded space
     * at the bottome of the tableView when multiple cells are rendered.
     */
    private func updateFooterInsets() {
        /// Update the footer height if it's being displayed.
        if footerHeightContraint.constant > 0 {
            footerHeightContraint.constant = footerHeight
        }

        /// The needed distance to fill the rest of the screen to allow the header to still collapse when scrolling (or to maintain a collapsed header if it was already collapsed when selecting a filter)
        let distanceToBottom = scrollableView.frame.height - minHeaderHeight - estimatedContentSize().height
        let newHeight: CGFloat = max(footerHeight, distanceToBottom)
        if let tableView = scrollableView as? UITableView {

            guard !allowCustomTableFooterView else {
                return
            }

            tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: newHeight))
            tableView.tableFooterView?.isGhostableDisabled = true
            tableView.tableFooterView?.backgroundColor = .clear
        } else {
            scrollableView.contentInset.bottom = newHeight
        }
    }

    private func layoutHeader() {
        [headerView, footerView].forEach({
            $0?.setNeedsLayout()
            $0?.layoutIfNeeded()
        })

        calculateHeaderSnapPoints()
        layoutHeaderInsets()
        updateTitleViewVisibility(false)
    }

    // MARK: - Subclass callbacks

    /// A public interface to notify the container that the content has loaded data or is attempting too.
    public func displayNoResultsController(title: String, subtitle: String?, resultsDelegate: NoResultsViewControllerDelegate?) {
        guard !isShowingNoResults else {
            return
        }

        isShowingNoResults = true
        disableInitialLayoutHelpers()
        snapToHeight(scrollableView, height: minHeaderHeight)
        configureAndDisplayNoResults(on: containerView,
                                     title: title,
                                     subtitle: subtitle,
                                     noConnectionSubtitle: subtitle,
                                     buttonTitle: NSLocalizedString("Retry", comment: "A prompt to attempt the failed network request again"),
                                     customizationBlock: { (noResultsController) in
                                        noResultsController.delegate = resultsDelegate
                                     })
    }

    public func dismissNoResultsController() {
        guard isShowingNoResults else {
            return
        }

        isShowingNoResults = false
        snapToHeight(scrollableView, height: maxHeaderHeight)
        hideNoResults()
    }

    /// A public interface to notify the container that the action buttons need to be vertical instead of horizontal (the default).
    /// In this scenario, it is assumed:
    /// - The primary and secondary action buttons are always displayed.
    /// - The defaultActionButton is never displayed.
    /// Therefore:
    /// - The footerView with the action buttons is shown.
    /// - The selectedStateButtonsContainer axis is set to vertical.
    /// - The primaryActionButton is moved to the top of the stack view.
    func configureVerticalButtonView() {
        usesVerticalActionButtons = true

        footerView.backgroundColor = .systemBackground
        footerHeightContraint.constant = footerHeight
        selectedStateButtonsContainer.axis = .vertical

        selectedStateButtonsContainer.removeArrangedSubview(primaryActionButton)
        selectedStateButtonsContainer.insertArrangedSubview(primaryActionButton, at: 0)
    }

    /// A public interface to hide the header blur.
    func hideHeaderVisualEffects() {
        visualEffects.forEach { (visualEffect) in
            visualEffect.isHidden = true
        }
    }

    /// In scenarios where the content offset before content changes doesn't align with the available space after the content changes then the offset can be lost. In
    /// order to preserve the header's collpased state we cache the offset and attempt to reapply it if needed.
    private var stashedOffset: CGPoint? = nil

    /// Tracks if the current scroll behavior was intiated by a user drag event
    private var isUserInitiatedScroll = false

    /// A public interface to notify the container that the content size of the scroll view is about to change. This is useful in adjusting the bottom insets to allow the
    /// view to still be scrollable with the content size is less than the total space of the expanded screen.
    public func contentSizeWillChange() {
        stashedOffset = scrollableView.contentOffset
        updateFooterInsets()
    }

    /// A public interface to notify the container that the selected state for an items has changed.
    public func itemSelectionChanged(_ hasSelectedItem: Bool) {
        let animationSpeed = CollapsableHeaderCollectionViewCell.selectionAnimationSpeed
        guard hasDefaultAction else {
            UIView.animate(withDuration: animationSpeed, delay: 0, options: .curveEaseInOut, animations: {
                self.footerHeightContraint.constant = hasSelectedItem ? self.footerHeight : 0
                self.footerView.setNeedsLayout()
                // call layoutIfNeeded on the parent view to smoothly update constraints
                // more info: https://stackoverflow.com/a/12664093
                self.view.layoutIfNeeded()
            })
            return
        }

        guard hasSelectedItem == selectedStateButtonsContainer.isHidden else {
            return
        }

        defaultActionButton.isHidden = false
        selectedStateButtonsContainer.isHidden = false

        defaultActionButton.alpha = hasSelectedItem ? 1 : 0
        selectedStateButtonsContainer.alpha = hasSelectedItem ? 0 : 1

        let alpha: CGFloat = hasSelectedItem ? 0 : 1
        let selectedStateContainerAlpha: CGFloat = hasSelectedItem ? 1 : 0

        UIView.animate(withDuration: animationSpeed, delay: 0, options: .transitionCrossDissolve, animations: {
            self.defaultActionButton.alpha = alpha
            self.selectedStateButtonsContainer.alpha = selectedStateContainerAlpha
        }) { (_) in
            self.defaultActionButton.isHidden = hasSelectedItem
            self.selectedStateButtonsContainer.isHidden = !hasSelectedItem
        }
    }

    // MARK: - Seperator styling
    private func updateSeperatorStyle(animated: Bool = true) {
        let shouldBeHidden: Bool
        switch separatorStyle {
        case .automatic:
            shouldBeHidden = headerHeightConstraint.constant > minHeaderHeight && !shouldUseCompactLayout
        case .visible:
            shouldBeHidden = false
        case .hidden:
            shouldBeHidden = true
        }

        seperator.animatableSetIsHidden(shouldBeHidden, animated: animated)
    }
}

// MARK: - UIScrollViewDelegate
extension CollapsableHeaderViewController: UIScrollViewDelegate {

    private func disableInitialLayoutHelpers() {
        if !headerHeightConstraint.isActive {
            initialHeaderTopConstraint.isActive = false
            headerHeightConstraint.isActive = true
        }
    }

    /// Restores the stashed content offset if it appears as if it's been reset.
    private func restoreContentOffsetIfNeeded(_ scrollView: UIScrollView) {
        guard var stashedOffset else {
            return
        }

        stashedOffset = resolveContentOffsetCollisions(scrollView, cachedOffset: stashedOffset)
        scrollView.contentOffset = stashedOffset
    }

    private func resolveContentOffsetCollisions(_ scrollView: UIScrollView, cachedOffset: CGPoint) -> CGPoint {
        var adjustedOffset = cachedOffset

        /// If the content size has changed enough to where the cached offset would scroll beyond the allowable bounds then we reset to the minum scroll height to
        /// maintain the header's size.
        if scrollView.contentSize.height - cachedOffset.y < scrollView.frame.height {
            adjustedOffset.y = maxHeaderHeight - headerHeightConstraint.constant
            stashedOffset = adjustedOffset
        }

        return adjustedOffset
    }

    private func resizeHeaderIfNeeded(_ scrollView: UIScrollView) {
        let scrollOffset = scrollView.contentOffset.y + topInset
        let newHeaderViewHeight = maxHeaderHeight - scrollOffset

        if newHeaderViewHeight < minHeaderHeight {
            headerHeightConstraint.constant = minHeaderHeight
        } else {
            headerHeightConstraint.constant = newHeaderViewHeight
        }
    }

    internal func updateTitleViewVisibility(_ animated: Bool = true) {
        var shouldHide = shouldUseCompactLayout ? false : (headerHeightConstraint.constant > midHeaderHeight)
        shouldHide = headerHeightConstraint.isActive ? shouldHide : true
        titleView.animatableSetIsHidden(shouldHide, animated: animated)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        /// Clear the stashed offset because the user has initiated a change
        stashedOffset = nil
        isUserInitiatedScroll = true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard stashedOffset == nil || stashedOffset == CGPoint.zero else {
            restoreContentOffsetIfNeeded(scrollView)
            return
        }

        guard !shouldUseCompactLayout,
              !isShowingNoResults else {
            updateTitleViewVisibility(true)
            updateSeperatorStyle()
            return
        }
        disableInitialLayoutHelpers()
        resizeHeaderIfNeeded(scrollView)
        updateTitleViewVisibility(isUserInitiatedScroll)
        updateSeperatorStyle()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToHeight(scrollView)
        isUserInitiatedScroll = false
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToHeight(scrollView)
        }
    }

    private func snapToHeight(_ scrollView: UIScrollView) {
        guard !shouldUseCompactLayout else {
            return
        }

        if headerStackView.frame.midY > 0 {
            snapToHeight(scrollView, height: maxHeaderHeight)
        } else if promptView.frame.midY > 0 {
            snapToHeight(scrollView, height: midHeaderHeight)
        } else if headerHeightConstraint.constant != minHeaderHeight {
            snapToHeight(scrollView, height: minHeaderHeight)
        }
    }

    public func expandHeader() {
        guard !shouldUseCompactLayout else {
            return
        }
        snapToHeight(scrollableView, height: maxHeaderHeight)
    }

    private func snapToHeight(_ scrollView: UIScrollView, height: CGFloat, animated: Bool = true) {
        scrollView.contentOffset.y = maxHeaderHeight - height - topInset
        headerHeightConstraint.constant = height
        updateTitleViewVisibility(animated)
        updateSeperatorStyle(animated: animated)

        guard animated else {
            headerView.setNeedsLayout()
            headerView.layoutIfNeeded()
            return
        }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: .curveEaseInOut, animations: {
            self.headerView.setNeedsLayout()
            self.headerView.layoutIfNeeded()
        }, completion: nil)
    }
}

// MARK: - Keyboard Adjustments
extension CollapsableHeaderViewController {
    private func startObservingKeyboardChanges() {
        let willShowObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] (notification) in
            guard let self else { return }
            UIView.animate(withKeyboard: notification) { (_, endFrame) in
                self.scrollableContainerBottomConstraint.constant = endFrame.height - self.footerHeight
            }
        }

        let willHideObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] (notification) in
            guard let self else { return }
            UIView.animate(withKeyboard: notification) { (_, _) in
                self.scrollableContainerBottomConstraint.constant = 0
            }
        }

        let willChangeFrameObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] (notification) in
            guard let self else { return }
            UIView.animate(withKeyboard: notification) { (_, endFrame) in
                self.scrollableContainerBottomConstraint.constant = endFrame.height - self.footerHeight
            }
        }

        notificationObservers.append(willShowObserver)
        notificationObservers.append(willHideObserver)
        notificationObservers.append(willChangeFrameObserver)
    }

    private func stopObservingKeyboardChanges() {
        notificationObservers.forEach { (observer) in
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers = []
    }
}
