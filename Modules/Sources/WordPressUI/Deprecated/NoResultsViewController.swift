import UIKit
import WordPressShared
import Reachability

@objc public protocol NoResultsViewControllerDelegate {
    @objc optional func actionButtonPressed()
    @objc optional func dismissButtonPressed()
}

/// A view to show when there are no results for a given situation.
/// Ex: My Sites > account has no sites; My Sites > all sites are hidden.
/// The title will always show.
/// The image will always show unless:
///     - an accessoryView is provided.
///     - hideImage is set to true.
/// The action button is shown by default, but will be hidden if button title is not provided.
/// The subtitle is optional and will only show if provided.
/// If this view is presented as a result of connectivity issue we will override the title, subtitle, image and accessorySubview (if it was set) to default values defined in the NoConnection struct
///
/// - warning: Soft-deprecated
@objc public class NoResultsViewController: UIViewController {

    // MARK: - Properties

    @objc public weak var delegate: NoResultsViewControllerDelegate?
    @IBOutlet weak var noResultsView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleTextView: UITextView!
    @IBOutlet weak var subtitleImageView: UIImageView!
    @IBOutlet weak var actionButton: FancyButton!
    @IBOutlet weak var accessoryView: UIView!
    @IBOutlet weak var accessoryStackView: UIStackView!
    @IBOutlet weak var labelStackView: UIStackView!
    @IBOutlet weak var labelButtonStackView: UIStackView!

    public private(set) var isReachable = false

    // To allow storing values until view is loaded.
    private var titleText: String?
    private var attributedTitleText: NSAttributedString?
    private var subtitleText: String?
    private var attributedSubtitleText: NSAttributedString?
    private var buttonText: String?
    private var imageName: String?
    private var subtitleImageName: String?
    private var accessorySubview: UIView?
    private var hideImage = false

    var labelStackViewSpacing: CGFloat = 10
    var labelButtonStackViewSpacing: CGFloat = 20

    /// Allows caller to customize subtitle attributed text after default styling.
    public typealias AttributedSubtitleConfiguration = (_ attributedText: NSAttributedString) -> NSAttributedString?
    /// Called after default styling of attributed subtitle, if non nil.
    private var configureAttributedSubtitle: AttributedSubtitleConfiguration? = nil

    private var displayTitleViewOnly = false
    private var titleOnlyLabel: UILabel?
    // To adjust title view on rotation.
    private var titleLabelLeadingConstraint: NSLayoutConstraint?
    private var titleLabelTrailingConstraint: NSLayoutConstraint?
    private var titleLabelCenterXConstraint: NSLayoutConstraint?
    private var titleLabelMaxWidthConstraint: NSLayoutConstraint?
    private var titleLabelTopConstraint: NSLayoutConstraint?

    //For No results on connection issue
    private let reachability = Reachability.forInternetConnection()
    /// sets an additional/alternate handler for the action button that can be directly injected
    public var actionButtonHandler: (() -> Void)?
    /// sets an additional/alternate handler for the dismiss button that can be directly injected
    public var dismissButtonHandler: (() -> Void)?

    public var buttonMenu: UIMenu?

    // MARK: - View

    public override func viewDidLoad() {
        super.viewDidLoad()
        WPStyleGuide.configureColors(view: view, tableView: nil)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reachability?.startNotifier()
        configureView()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reachability?.stopNotifier()
    }

    public override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        configureView()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setAccessoryViewsVisibility()
        // `traitCollectionDidChange` is not fired for iOS 16.0 + Media adding flow. The reason why the constraints update call was moved to here.
        // Since `viewWillTransition` is always called when the orientation changes (portrait | landscape), it will work for all scenarios.
        DispatchQueue.main.async {
            self.configureTitleViewConstraints()
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustTitleOnlyLabelHeight()
    }

    /// Public method to get controller instance and set view values.
    ///
    /// - Parameters:
    ///   - title:              Main descriptive text. Required.
    ///   - buttonTitle:        Title of action button. Optional.
    ///   - subtitle:           Secondary descriptive text. Optional.
    ///   - attributedSubtitle: Secondary descriptive attributed text. Optional.
    ///   - attributedSubtitleConfiguration: Called after default styling, for subtitle attributed text customization.
    ///   - image:              Name of image file to use. Optional.
    ///   - subtitleImage:      Name of image file to use in place of subtitle. Optional.
    ///   - accessoryView:      View to show instead of the image. Optional.
    ///
    @objc public class func controllerWith(title: String,
                                    attributedTitle: NSAttributedString? = nil,
                                    buttonTitle: String? = nil,
                                    subtitle: String? = nil,
                                    attributedSubtitle: NSAttributedString? = nil,
                                    attributedSubtitleConfiguration: AttributedSubtitleConfiguration? = nil,
                                    image: String? = nil,
                                    subtitleImage: String? = nil,
                                    accessoryView: UIView? = nil) -> NoResultsViewController {
        let controller = NoResultsViewController.controller()
        controller.configure(title: title, buttonTitle: buttonTitle, subtitle: subtitle, attributedSubtitle: attributedSubtitle, attributedSubtitleConfiguration: attributedSubtitleConfiguration, image: image, subtitleImage: subtitleImage, accessoryView: accessoryView)
        return controller
    }

    /// Public method to get controller instance.
    /// As this only creates the controller, the configure method should be called
    /// to set the view values before presenting the No Results View.
    ///
    @objc public class func controller() -> NoResultsViewController {
        let storyBoard = UIStoryboard(name: "NoResults", bundle: Bundle.module)
        let controller = storyBoard.instantiateViewController(withIdentifier: "NoResults") as! NoResultsViewController
        return controller
    }

    /// Public method to provide values for text elements.
    ///
    /// - Parameters:
    ///   - title:              Main descriptive text. Required.
    ///   - buttonTitle:        Title of action button. Optional.
    ///   - subtitle:           Secondary descriptive text. Optional.
    ///   - attributedSubtitle: Secondary descriptive attributed text. Optional.
    ///   - attributedSubtitleConfiguration: Called after default styling, for subtitle attributed text customization.
    ///   - image:              Name of image file to use. Optional.
    ///   - subtitleImage:      Name of image file to use in place of subtitle. Optional.
    ///   - accessoryView:      View to show instead of the image. Optional.
    ///
    @objc public func configure(title: String,
                         attributedTitle: NSAttributedString? = nil,
                         noConnectionTitle: String? = nil,
                         buttonTitle: String? = nil,
                         subtitle: String? = nil,
                         noConnectionSubtitle: String? = nil,
                         attributedSubtitle: NSAttributedString? = nil,
                         attributedSubtitleConfiguration: AttributedSubtitleConfiguration? = nil,
                         image: String? = nil,
                         subtitleImage: String? = nil,
                         accessoryView: UIView? = nil) {
        isReachable = reachability?.isReachable() ?? false
        if !isReachable {
            titleText = noConnectionTitle != nil ? noConnectionTitle : NoConnection.title
            let subtitle = noConnectionSubtitle != nil ? noConnectionSubtitle : NoConnection.subTitle
            subtitleText = subtitle
            attributedSubtitleText = NSAttributedString(string: subtitleText!)
            configureAttributedSubtitle = nil
            attributedTitleText = nil
        } else {
            titleText = title
            subtitleText = subtitle
            attributedSubtitleText = attributedSubtitle
            attributedTitleText = attributedTitle
            configureAttributedSubtitle = attributedSubtitleConfiguration
        }

        buttonText = buttonTitle
        imageName = !isReachable ? NoConnection.imageName : image
        subtitleImageName = subtitleImage
        accessorySubview = !isReachable ? nil : accessoryView
        displayTitleViewOnly = false
    }

    /// Public method to show the title specifically formatted for no search results.
    /// When the view is configured, it will display just a label with specific constraints.
    ///
    /// - Parameters:
    ///   - title:  Main descriptive text. Required.
    public func configureForNoSearchResults(title: String) {
        configure(title: title)
        displayTitleViewOnly = true
    }

    /// Public method to remove No Results View from parent view.
    ///
    @objc public func removeFromView() {
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }

    /// Public method to show a 'Dismiss' button in the navigation bar in place of the 'Back' button.
    /// Accepts an optional title, if none is provided, will default to 'Dismiss'
    public func showDismissButton(title: String? = nil) {
        navigationItem.hidesBackButton = true
        let buttonTitle = title ?? AppLocalizedString(
            "noResultsViewController.dismissButton",
            value: "Dismiss",
            comment: "Dismiss button title."
        )

        let dismissButton = UIBarButtonItem(title: buttonTitle,
                                            style: .done,
                                            target: self,
                                            action: #selector(self.dismissButtonPressed))
        dismissButton.accessibilityLabel = buttonTitle
        navigationItem.leftBarButtonItem = dismissButton
    }

    /// Public method to get an attributed string styled for No Results.
    ///
    /// - Parameters:
    ///   - attributedString: The attributed string to be styled.
    ///
    private func applyMessageStyleTo(attributedString: NSAttributedString) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = subtitleTextView.textAlignment

        let attributes: [NSAttributedString.Key: Any] = [
            .font: subtitleTextView.font!,
            .foregroundColor: subtitleTextView.textColor!,
            .paragraphStyle: paragraphStyle
        ]

        let fullTextRange = NSRange(location: 0, length: attributedString.string.utf16.count)
        let finalAttributedString = NSMutableAttributedString(attributedString: attributedString)
        finalAttributedString.addAttributes(attributes, range: fullTextRange)

        return finalAttributedString
    }

    @objc public class func loadingAccessoryView() -> UIView {
        let indicator = UIActivityIndicatorView()
        indicator.startAnimating()
        return indicator
    }

    /// Public method to hide/show the image view.
    ///
    @objc public func hideImageView(_ hide: Bool = true) {
        hideImage = hide
    }

    /// Public method to expose the private configure view method
    ///
    public func updateView() {
        configureView()
    }

    /// Public method to reset the button text
    ///
    public func resetButtonText() {
        buttonText = nil
    }
}

private extension NoResultsViewController {

    // MARK: - View

    func configureView() {
        labelStackView.spacing = labelStackViewSpacing
        labelButtonStackView.spacing = labelButtonStackViewSpacing

        titleLabel.text = titleText
        titleLabel.textColor = .label

        if let titleText {
            titleLabel.attributedText = nil
            titleLabel.text = titleText
        }

        if let attributedTitleText {
            titleLabel.attributedText = attributedTitleText
        }

        subtitleTextView.textColor = .secondaryLabel

        if let subtitleText {
            subtitleTextView.attributedText = nil
            subtitleTextView.text = subtitleText
            subtitleTextView.isSelectable = false
        }

        if let attributedSubtitleText {
            subtitleTextView.attributedText = applyMessageStyleTo(attributedString: attributedSubtitleText)
            if let attributedSubtitle = configureAttributedSubtitle?(subtitleTextView.attributedText) {
                subtitleTextView.attributedText = attributedSubtitle
            }
            subtitleTextView.isSelectable = true
        }

        let hasSubtitleText = subtitleText != nil || attributedSubtitleText != nil
        let hasSubtitleImage = subtitleImageName != nil
        let showSubtitle = hasSubtitleText && !hasSubtitleImage
        subtitleTextView.isHidden = !showSubtitle
        subtitleImageView.isHidden = !hasSubtitleImage
        subtitleImageView.tintColor = titleLabel.textColor
        configureSubtitleView()

        if let buttonText {
            actionButton?.setTitle(buttonText, for: UIControl.State())
            actionButton?.setTitle(buttonText, for: .highlighted)
            actionButton?.titleLabel?.adjustsFontForContentSizeCategory = true
            actionButton?.accessibilityIdentifier = accessibilityIdentifier(for: buttonText)
            actionButton.isHidden = false
            if let buttonMenu {
                actionButton.menu = buttonMenu
                actionButton.showsMenuAsPrimaryAction = true
            } else {
                actionButton.showsMenuAsPrimaryAction = false
            }
        } else {
            actionButton.isHidden = true
        }

        if let accessorySubview {
            accessoryView.subviews.forEach { view in
                view.removeFromSuperview()
            }
            accessoryView.addSubview(accessorySubview)
            /// - note: `is` added to avoid introducing breaking changes. In
            /// reality, this view has to add _some_ contraints.
            if accessorySubview is UIActivityIndicatorView {
                accessorySubview.pinCenter()
            }
        }

        if let imageName {
            imageView.image = UIImage(named: imageName)
        }

        if let subtitleImageName {
            subtitleImageView.image = UIImage(named: subtitleImageName)
        }

        setAccessoryViewsVisibility()
        configureForTitleViewOnly()

        configureForAccessibility()

        view.layoutIfNeeded()
    }

    func configureSubtitleView() {
        // remove the extra space iOS puts on a UITextView
        subtitleTextView.textContainerInset = UIEdgeInsets.zero
        subtitleTextView.textContainer.lineFragmentPadding = 0
    }

    func setAccessoryViewsVisibility() {

        if hideImage {
            accessoryStackView.isHidden = true
            return
        }

        // Always hide the accessory/image stack view when in iPhone landscape.
        accessoryStackView.isHidden = UIDevice.current.orientation.isLandscape && WPDeviceIdentification.isiPhone()

        // If there is an accessory view, show that.
        accessoryView.isHidden = accessorySubview == nil
        // Otherwise, show the image view, unless it's set never to show.
        imageView.isHidden = (hideImage == true) ? true : !accessoryView.isHidden
    }

    // MARK: - Configure for Title View Only

    func configureForTitleViewOnly() {

        titleOnlyLabel?.removeFromSuperview()

        guard displayTitleViewOnly == true else {
            noResultsView.isHidden = false
            return
        }

        titleOnlyLabel = copyTitleLabel()

        guard let titleOnlyLabel else {
            return
        }

        noResultsView.isHidden = true
        titleOnlyLabel.frame = view.frame
        view.addSubview(titleOnlyLabel)
        configureTitleViewConstraints()
    }

    func copyTitleLabel() -> UILabel? {
        // Copy the `titleLabel` to get the style for Title View Only label

        // Note: unarchivedObjectOfClass:fromData:error: sets secure coding to true
        // We setup our own unarchiver to work around that
        guard
            let titleLabel,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: titleLabel, requiringSecureCoding: false),
            let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        else {
            return nil
        }

        unarchiver.requiresSecureCoding = false

        return try? unarchiver.decodeTopLevelObject(of: UILabel.self, forKey: "root")
    }

    func configureTitleViewConstraints() {

        guard displayTitleViewOnly else {
            return
        }

        resetTitleViewConstraints()
        titleOnlyLabel?.translatesAutoresizingMaskIntoConstraints = false

        let availableWidth = view.frame.width - TitleLabelConstraints.leading + TitleLabelConstraints.trailing

        if availableWidth < TitleLabelConstraints.maxWidth {
            guard let titleLabelLeadingConstraint,
                let titleLabelTrailingConstraint,
                let titleLabelTopConstraint else {
                    return
            }

            NSLayoutConstraint.activate([titleLabelTopConstraint, titleLabelLeadingConstraint, titleLabelTrailingConstraint])
        } else {
            guard let titleLabelMaxWidthConstraint,
                let titleLabelCenterXConstraint,
                let titleLabelTopConstraint else {
                    return
            }
            titleLabelTopConstraint.constant = TitleLabelConstraints.topLandscape
            NSLayoutConstraint.activate([titleLabelTopConstraint, titleLabelMaxWidthConstraint, titleLabelCenterXConstraint])
        }
    }

    func resetTitleViewConstraints() {
        titleLabelTopConstraint?.isActive = false
        titleLabelTrailingConstraint?.isActive = false
        titleLabelLeadingConstraint?.isActive = false
        titleLabelMaxWidthConstraint?.isActive = false
        titleLabelCenterXConstraint?.isActive = false

        guard let titleOnlyLabel else {
            return
        }

        titleLabelTopConstraint = titleOnlyLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: TitleLabelConstraints.top)
        titleLabelLeadingConstraint = titleOnlyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: TitleLabelConstraints.leading)
        titleLabelTrailingConstraint = titleOnlyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: TitleLabelConstraints.trailing)
        titleLabelCenterXConstraint = titleOnlyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        titleLabelMaxWidthConstraint = titleOnlyLabel.widthAnchor.constraint(lessThanOrEqualToConstant: TitleLabelConstraints.maxWidth)
    }

    func adjustTitleOnlyLabelHeight() {

        guard let titleOnlyLabel else {
            return
        }

        var titleOnlyLabelFrame = titleOnlyLabel.frame
        titleOnlyLabel.sizeToFit()
        titleOnlyLabelFrame.size.height = titleOnlyLabel.frame.height
        titleOnlyLabel.frame = titleOnlyLabelFrame
    }

    struct TitleLabelConstraints {
        static let top = CGFloat(64)
        static let topLandscape = CGFloat(32)
        static let leading = CGFloat(38)
        static let trailing = CGFloat(-38)
        static let maxWidth = CGFloat(360)
    }

    // MARK: - Button Handling

    @IBAction func actionButtonPressed(_ sender: UIButton) {
        delegate?.actionButtonPressed?()
        actionButtonHandler?()
    }

    @objc func dismissButtonPressed() {
        delegate?.dismissButtonPressed?()
        dismissButtonHandler?()
    }

    // MARK: - Helpers

    func accessibilityIdentifier(for string: String) -> String {
        let buttonIdFormat = AppLocalizedString("%@ Button", comment: "Accessibility identifier for buttons.")
        return String(format: buttonIdFormat, string)
    }

    struct NoConnection {
        static let title: String = AppLocalizedString("Unable to load this content right now.", comment: "Default title shown for no-results when the device is offline.")
        static let subTitle: String = AppLocalizedString("Check your network connection and try again.", comment: "Default subtitle for no-results when there is no connection")
        static let imageName = "cloud"
    }
}

// MARK: - Accessibility

private extension NoResultsViewController {
    func configureForAccessibility() {
        // Reset
        view.isAccessibilityElement = false
        view.accessibilityIdentifier = nil
        view.accessibilityLabel = nil
        view.accessibilityElements = nil
        view.accessibilityTraits = .none

        if displayTitleViewOnly {
            view.isAccessibilityElement = true
            view.accessibilityIdentifier = .noResultsTitleViewAccessibilityIdentifier
            view.accessibilityLabel = titleLabel.text
            view.accessibilityTraits = .staticText
        } else {
            view.accessibilityElements = [labelStackView!, actionButton!]

            labelStackView.accessibilityTraits = .staticText
            labelStackView.isAccessibilityElement = true
            labelStackView.accessibilityIdentifier = .noResultsLabelStackViewAccessibilityIdentifier
            labelStackView.accessibilityLabel = [
                titleLabel.text,
                subtitleTextView.isHidden ? nil : subtitleTextView.attributedText.string
            ].compactMap { $0 }.joined(separator: ". ")
        }
    }
}

// MARK: - Accessibility Identifiers

private extension String {
    static let noResultsTitleViewAccessibilityIdentifier = "no-results-title-view"
    static let noResultsLabelStackViewAccessibilityIdentifier = "no-results-label-stack-view"
}
