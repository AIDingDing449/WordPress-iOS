import Foundation
import WordPressData
import WordPressShared
import WordPressUI

/**
 *  @brief      Support for filtering themes by purchasability
 *  @details    Currently purchasing themes via native apps is unsupported
 */
public enum ThemeType {
    case all
    case free
    case premium

    static let mayPurchase = false

    static let types = [all, free, premium]

    var title: String {
        switch self {
        case .all:
            return NSLocalizedString("All", comment: "Browse all themes selection title")
        case .free:
            return NSLocalizedString("Free", comment: "Browse free themes selection title")
        case .premium:
            return NSLocalizedString("Premium", comment: "Browse premium themes selection title")
        }
    }

    var predicate: NSPredicate? {
        switch self {
        case .all:
            return nil
        case .free:
            return NSPredicate(format: "premium == 0")
        case .premium:
            return NSPredicate(format: "premium == 1")
        }
    }
}

/**
 *  @brief      Publicly exposed theme interaction support
 *  @details    Held as weak reference by owned subviews
 */
public protocol ThemePresenter: AnyObject {
    var filterType: ThemeType { get set }

    var screenshotWidth: Int { get }

    func currentTheme() -> Theme?
    func activateTheme(_ theme: Theme?)

    func presentCustomizeForTheme(_ theme: Theme?)
    func presentPreviewForTheme(_ theme: Theme?)
    func presentDetailsForTheme(_ theme: Theme?)
    func presentSupportForTheme(_ theme: Theme?)
    func presentViewForTheme(_ theme: Theme?)
}

/// Invalidates the layout whenever the collection view's bounds change
@objc open class ThemeBrowserCollectionViewLayout: UICollectionViewFlowLayout {
    open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return shouldInvalidateForNewBounds(newBounds)
    }

    open override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewFlowLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds) as! UICollectionViewFlowLayoutInvalidationContext
        context.invalidateFlowLayoutDelegateMetrics = shouldInvalidateForNewBounds(newBounds)

        return context
    }

    fileprivate func shouldInvalidateForNewBounds(_ newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }

        return (newBounds.width != collectionView.bounds.width || newBounds.height != collectionView.bounds.height)
    }
}

@objc open class ThemeBrowserViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, NSFetchedResultsControllerDelegate, UISearchControllerDelegate, UISearchResultsUpdating, ThemePresenter, WPContentSyncHelperDelegate {

    // MARK: - Constants

    @objc static let reuseIdentifierForThemesHeader = "ThemeBrowserSectionHeaderViewThemes"
    @objc static let reuseIdentifierForCustomThemesHeader = "ThemeBrowserSectionHeaderViewCustomThemes"
    static let themesLoaderFrame = CGRect(x: 0.0, y: 0.0, width: 40.0, height: 20.0)

    // MARK: - Properties: must be set by parent

    /**
     *  @brief      The blog this VC will work with.
     *  @details    Must be set by the creator of this VC.
     */
    @objc open var blog: Blog!

    // MARK: - Properties

    @IBOutlet weak var collectionView: UICollectionView!

    // swiftlint:disable:next weak_delegate
    fileprivate lazy var customizerNavigationDelegate: ThemeWebNavigationDelegate = {
        return ThemeWebNavigationDelegate()
    }()

    /**
     *  @brief      The FRCs this VC will use to display filtered content.
     */
    fileprivate lazy var themesController: NSFetchedResultsController<NSFetchRequestResult> = {
        return self.createThemesFetchedResultsController()
    }()

    fileprivate lazy var customThemesController: NSFetchedResultsController<NSFetchRequestResult> = {
        return self.createThemesFetchedResultsController()
    }()

    fileprivate func createThemesFetchedResultsController() -> NSFetchedResultsController<NSFetchRequestResult> {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Theme.entityName())
        fetchRequest.fetchBatchSize = 20
        let sort = NSSortDescriptor(key: "order", ascending: true)
        fetchRequest.sortDescriptors = [sort]
        let frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.themeService.coreDataStack.mainContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        frc.delegate = self

        return frc
    }

    fileprivate var themeCount: NSInteger {
        return themesController.fetchedObjects?.count ?? 0
    }

    fileprivate var customThemeCount: NSInteger {
        return blog.supports(BlogFeature.customThemes) ? (customThemesController.fetchedObjects?.count ?? 0) : 0
    }

    // Absolute count of available themes for the site, as it comes from the ThemeService

    fileprivate var totalThemeCount: NSInteger = 0 {
        didSet {
            themesHeader?.themeCount = totalThemeCount
        }
    }

    fileprivate var totalCustomThemeCount: NSInteger = 0 {
        didSet {
            customThemesHeader?.themeCount = totalCustomThemeCount
        }
    }

    fileprivate var themesHeader: ThemeBrowserSectionHeaderView? {
        didSet {
            themesHeader?.descriptionLabel.text = NSLocalizedString("WordPress.com Themes",
                                                                    comment: "Title for the WordPress.com themes section, should be the same as in Calypso").localizedUppercase
            themesHeader?.themeCount = totalThemeCount > 0 ? totalThemeCount : themeCount
        }
    }

    fileprivate var customThemesHeader: ThemeBrowserSectionHeaderView? {
        didSet {
            customThemesHeader?.descriptionLabel.text = NSLocalizedString("Uploaded themes",
                                                                          comment: "Title for the user uploaded themes section, should be the same as in Calypso").localizedUppercase
            customThemesHeader?.themeCount = totalCustomThemeCount > 0 ? totalCustomThemeCount : customThemeCount
        }
    }

    fileprivate var hideSectionHeaders: Bool = false

    fileprivate var searchController: UISearchController!

    fileprivate var searchName = "" {
        didSet {
            if searchName != oldValue {
                fetchThemes()
                reloadThemes()
            }
       }
    }

    fileprivate var suspendedSearch = ""

    @objc func resumingSearch() -> Bool {
        return !suspendedSearch.trim().isEmpty
    }

    fileprivate var activityIndicator: UIActivityIndicatorView = {
        let indicatorView = UIActivityIndicatorView(style: .medium)
        indicatorView.frame = themesLoaderFrame
        //TODO update color with white headers
        indicatorView.color = .white
        indicatorView.startAnimating()
        return indicatorView
       }()

    open var filterType: ThemeType = ThemeType.mayPurchase ? .all : .free

    /**
     *  @brief      Collection view support
     */

    fileprivate enum Section {
        case info
        case customThemes
        case themes
    }
    fileprivate var sections: [Section]!

    fileprivate func reloadThemes() {
        collectionView?.reloadData()
        updateResults()
    }

    fileprivate func themeAtIndexPath(_ indexPath: IndexPath) -> Theme? {
        if sections[indexPath.section] == .themes {
            return themesController.object(at: IndexPath(row: indexPath.row, section: 0)) as? Theme
        } else if sections[indexPath.section] == .customThemes {
            return customThemesController.object(at: IndexPath(row: indexPath.row, section: 0)) as? Theme
        }
        return nil
    }

    fileprivate func updateActivateButton(isLoading: Bool) {
        if isLoading {
            activateButton?.customView = activityIndicator
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
            activateButton?.customView = nil
            activateButton?.isEnabled = false
            activateButton?.title = ThemeAction.active.title
        }
    }

    fileprivate var presentingTheme: Theme?

    private var noResultsViewController: NoResultsViewController?

    private struct NoResultsTitles {
        static let noThemes = NSLocalizedString("No themes matching your search", comment: "Text displayed when theme name search has no matches")
        static let fetchingThemes = NSLocalizedString("Fetching Themes...", comment: "Text displayed while fetching themes")
    }

    private var noResultsShown: Bool {
        return noResultsViewController?.parent != nil
    }

    private var isFirstAppearance = true

    /**
     *  @brief      Load theme screenshots at maximum displayed width
     */
    @objc open var screenshotWidth: Int = {
        guard let window = UIApplication.shared.mainWindow else {
            assertionFailure("The mainWindow is not set")
            return Int(Styles.imageWidthForFrameWidth(852))
        }
        let windowSize = window.bounds.size
        let vWidth = Styles.imageWidthForFrameWidth(windowSize.width)
        let hWidth = Styles.imageWidthForFrameWidth(windowSize.height)
        let maxWidth = Int(max(hWidth, vWidth))
        return maxWidth
    }()

    /**
     *  @brief      The themes service we'll use in this VC and its helpers
     */
    fileprivate let themeService = ThemeService(coreDataStack: ContextManager.shared)
    fileprivate var themesSyncHelper: WPContentSyncHelper!
    fileprivate var themesSyncingPage = 0
    fileprivate var customThemesSyncHelper: WPContentSyncHelper!
    fileprivate let syncPadding = 5
    fileprivate var activateButton: UIBarButtonItem?

    // MARK: - Private Aliases

    fileprivate typealias Styles = WPStyleGuide.Themes

     /**
     *  @brief      Convenience method for browser instantiation
     *
     *  @param      blog     The blog to browse themes for
     *
     *  @returns    ThemeBrowserViewController instance
     */
    @objc open class func browserWithBlog(_ blog: Blog) -> ThemeBrowserViewController {
        let storyboard = UIStoryboard(name: "ThemeBrowser", bundle: .keystone)
        let viewController = storyboard.instantiateInitialViewController() as! ThemeBrowserViewController
        viewController.blog = blog

        return viewController
    }

    // MARK: - UIViewController

    open override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.backgroundColor = .secondarySystemBackground

        title = NSLocalizedString("Themes", comment: "Title of Themes browser page")

        fetchThemes()
        sections = (themeCount == 0 && customThemeCount == 0) ? [.customThemes, .themes] :
                                                                [.info, .customThemes, .themes]

        configureSearchController()

        updateActiveTheme()
        setupThemesSyncHelper()
        if blog.supports(BlogFeature.customThemes) {
            setupCustomThemesSyncHelper()
        }
        syncContent()
    }

    fileprivate func configureSearchController() {
        definesPresentationContext = true

        searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = searchController

        searchController.delegate = self
        searchController.searchResultsUpdater = self

        collectionView.register(ThemeBrowserSectionHeaderView.defaultNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ThemeBrowserViewController.reuseIdentifierForThemesHeader)

        collectionView.register(ThemeBrowserSectionHeaderView.defaultNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ThemeBrowserViewController.reuseIdentifierForCustomThemesHeader)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        collectionView?.collectionViewLayout.invalidateLayout()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        registerForKeyboardNotifications()

        if resumingSearch() {
            beginSearchFor(suspendedSearch)
            suspendedSearch = ""
        }

        if isFirstAppearance {
            navigationItem.hidesSearchBarWhenScrolling = false
        }

        guard let theme = presentingTheme else {
            return
        }
        presentingTheme = nil
        if !theme.isCurrentTheme() {
            // presented page may have activated this theme
            updateActiveTheme()
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if isFirstAppearance {
            navigationItem.hidesSearchBarWhenScrolling = true
            isFirstAppearance = false
        }
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        unregisterForKeyboardNotifications()
    }

    fileprivate func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(ThemeBrowserViewController.keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ThemeBrowserViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    fileprivate func unregisterForKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc open func keyboardDidShow(_ notification: Foundation.Notification) {
        let keyboardFrame = localKeyboardFrameFromNotification(notification)
        let keyboardHeight = collectionView.frame.maxY - keyboardFrame.origin.y
//
        collectionView.contentInset.bottom = keyboardHeight
        collectionView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }

    @objc open func keyboardWillHide(_ notification: Foundation.Notification) {
        let tabBarHeight = tabBarController?.tabBar.bounds.height ?? 0

        collectionView.contentInset.bottom = tabBarHeight
        collectionView.verticalScrollIndicatorInsets.bottom = tabBarHeight
    }

    fileprivate func localKeyboardFrameFromNotification(_ notification: Foundation.Notification) -> CGRect {
        let key = UIResponder.keyboardFrameEndUserInfoKey
        guard let keyboardFrame = (notification.userInfo?[key] as? NSValue)?.cgRectValue else {
                return .zero
        }

        // Convert the frame from window coordinates
        return view.convert(keyboardFrame, from: nil)
    }

    // MARK: - Syncing the list of themes

    fileprivate func updateActiveTheme() {
        let lastActiveThemeId = blog.currentThemeId

        _ = themeService.getActiveTheme(for: blog,
            success: { [weak self] (theme: Theme?) in
                if lastActiveThemeId != theme?.themeId {
                    self?.collectionView?.collectionViewLayout.invalidateLayout()
                }
            },
            failure: { (error) in
                DDLogError("Error updating active theme: \(String(describing: error?.localizedDescription))")
        })
    }

    fileprivate func setupThemesSyncHelper() {
        themesSyncHelper = WPContentSyncHelper()
        themesSyncHelper.delegate = self
    }

    fileprivate func setupCustomThemesSyncHelper() {
        customThemesSyncHelper = WPContentSyncHelper()
        customThemesSyncHelper.delegate = self
    }

    fileprivate func syncContent() {
        if themesSyncHelper.syncContent() &&
            (!blog.supports(BlogFeature.customThemes) ||
                customThemesSyncHelper.syncContent()) {
            updateResults()
        }
    }

    fileprivate func syncMoreThemesIfNeeded(_ indexPath: IndexPath) {
        let paddedCount = indexPath.row + syncPadding
        if paddedCount >= themeCount && themesSyncHelper.hasMoreContent && themesSyncHelper.syncMoreContent() {
            updateResults()
        }
    }

    private func syncThemePage(_ page: NSInteger, search: String, success: ((_ hasMore: Bool) -> Void)?, failure: ((_ error: NSError) -> Void)?) {
        assert(page > 0)
        themesSyncingPage = page
        _ = themeService.getThemesFor(blog,
            page: themesSyncingPage,
            search: search,
            sync: page == 1,
            success: {[weak self](themes: [Theme]?, hasMore: Bool, themeCount: NSInteger) in
                if let success {
                    success(hasMore)
                }
                self?.totalThemeCount = themeCount
            },
            failure: { (error) in
                DDLogError("Error syncing themes: \(String(describing: error?.localizedDescription))")
                if let failure,
                    let error {
                    failure(error as NSError)
                }
            })
    }

    fileprivate func syncCustomThemes(success: ((_ hasMore: Bool) -> Void)?, failure: ((_ error: NSError) -> Void)?) {
        _ = themeService.getCustomThemes(for: blog,
            sync: true,
            success: {[weak self](themes: [Theme]?, hasMore: Bool, themeCount: NSInteger) in
                if let success {
                    success(hasMore)
                }
                self?.totalCustomThemeCount = themeCount
            },
            failure: { (error) in
                DDLogError("Error syncing themes: \(String(describing: error?.localizedDescription))")
                if let failure,
                    let error {
                    failure(error as NSError)
                }
            })
    }

    @objc open func currentTheme() -> Theme? {
        guard let themeId = blog.currentThemeId, !themeId.isEmpty else {
            return nil
        }

        for theme in blog.themes as! Set<Theme> {
            if theme.themeId == themeId {
                return theme
            }
        }

        return nil
    }

    // MARK: - WPContentSyncHelperDelegate

    public func syncHelper(_ syncHelper: WPContentSyncHelper, syncContentWithUserInteraction userInteraction: Bool, success: ((_ hasMore: Bool) -> Void)?, failure: ((_ error: NSError) -> Void)?) {
        if syncHelper == themesSyncHelper {
            syncThemePage(1, search: searchName, success: success, failure: failure)
        } else if syncHelper == customThemesSyncHelper {
            syncCustomThemes(success: success, failure: failure)
        }
    }

    public func syncHelper(_ syncHelper: WPContentSyncHelper, syncMoreWithSuccess success: ((_ hasMore: Bool) -> Void)?, failure: ((_ error: NSError) -> Void)?) {
        if syncHelper == themesSyncHelper {
            let nextPage = themesSyncingPage + 1
            syncThemePage(nextPage, search: searchName, success: success, failure: failure)
        }
    }

    public func syncContentEnded(_ syncHelper: WPContentSyncHelper) {
        updateResults()
        let lastVisibleTheme = collectionView?.indexPathsForVisibleItems.last ?? IndexPath(item: 0, section: 0)
        if syncHelper == themesSyncHelper {
            syncMoreThemesIfNeeded(lastVisibleTheme)
        }
    }

    public func hasNoMoreContent(_ syncHelper: WPContentSyncHelper) {
        if syncHelper == themesSyncHelper {
            themesSyncingPage = 0
        }
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    // MARK: - UICollectionViewDataSource

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sections[section] {
        case .info:
            return 0
        case .customThemes:
            return customThemeCount
        case .themes:
            return themeCount
        }
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ThemeBrowserCell.reuseIdentifier, for: indexPath) as! ThemeBrowserCell

        cell.presenter = self
        cell.theme = themeAtIndexPath(indexPath)

        if sections[indexPath.section] == .themes {
            syncMoreThemesIfNeeded(indexPath)
        }

        return cell
    }

    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            if sections[indexPath.section] == .info {
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ThemeBrowserHeaderView.reuseIdentifier, for: indexPath) as! ThemeBrowserHeaderView
                header.presenter = self
                return header
            } else {
                // We don't want the collectionView to reuse the section headers
                // since we need to keep a reference to them to update the counts
                if sections[indexPath.section] == .customThemes {
                    customThemesHeader = (collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ThemeBrowserViewController.reuseIdentifierForCustomThemesHeader, for: indexPath) as! ThemeBrowserSectionHeaderView)
                    customThemesHeader?.isHidden = customThemeCount == 0

                    return customThemesHeader!
                } else {
                    themesHeader = (collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ThemeBrowserViewController.reuseIdentifierForCustomThemesHeader, for: indexPath) as! ThemeBrowserSectionHeaderView)
                    themesHeader?.isHidden = themeCount == 0
                    return themesHeader!
                }
            }
        case UICollectionView.elementKindSectionFooter:
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ThemeBrowserFooterView", for: indexPath)
            return footer
        default:
            fatalError("Unexpected theme browser element")
        }
    }

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    // MARK: - UICollectionViewDelegate

    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let theme = themeAtIndexPath(indexPath) {
            if theme.isCurrentTheme() {
                presentCustomizeForTheme(theme)
            } else {
                theme.custom ? presentDetailsForTheme(theme) : presentViewForTheme(theme)
            }
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: NSInteger) -> CGSize {
        switch sections[section] {
        case .themes, .customThemes:
            if !hideSectionHeaders
                && blog.supports(BlogFeature.customThemes) {
                return CGSize(width: 0, height: ThemeBrowserSectionHeaderView.height)
            }
            return .zero
        case .info:
            let horizontallyCompact = traitCollection.horizontalSizeClass == .compact
            let height = Styles.headerHeight(horizontallyCompact)

            return CGSize(width: 0, height: height)
        }
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let parentViewWidth = collectionView.frame.size.width

        return Styles.cellSizeForFrameWidth(parentViewWidth)
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
            guard sections[section] == .themes && themesSyncHelper.isLoadingMore else {
                return CGSize.zero
            }

            return CGSize(width: 0, height: Styles.footerHeight)
    }

    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        switch sections[section] {
        case .customThemes:
            if !blog.supports(BlogFeature.customThemes) {
                return .zero
            }
            return Styles.themeMargins
        case .themes:
            return Styles.themeMargins
        case .info:
            return Styles.infoMargins
        }
    }

    // MARK: - Search support

    private var searchDebounceTimer: Timer?
    private let searchDebounceInterval: TimeInterval = 0.5

    private func resetRemoteSearch() {
        themesSyncingPage = 0

        if blog.supports(BlogFeature.customThemes) {
            themesSyncHelper.syncContent()
        }
    }

    fileprivate func beginSearchFor(_ pattern: String) {
        searchController.isActive = true
        searchController.searchBar.text = pattern

        updateSearchName(pattern)
    }

    private func updateSearchName(_ searchText: String) {
        // Cancel any existing timer
        searchDebounceTimer?.invalidate()

        // If search text is empty, update immediately and reset remote search
        if searchText.isEmpty {
            self.searchName = searchText
            self.fetchThemes()
            self.resetRemoteSearch()
            self.reloadThemes()
            return
        }

        // Check if we have a previously longer search that is now under 3 characters
        let previouslyHadRemoteSearch = self.searchName.count >= 3

        // Create a new timer for debounce
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: searchDebounceInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.searchName = searchText

            // Apply local search immediately
            self.fetchThemes()

            // Remote search only applies to WordPress.com themes and only if customThemes are supported.
            // The remote endpoint support search just for 3+ characters
            if self.blog.supports(BlogFeature.customThemes) {
                if searchText.count >= 3 {
                    // Reset to first page when searching
                    self.themesSyncingPage = 0
                    self.themesSyncHelper.syncContent()
                } else if previouslyHadRemoteSearch {
                    // If we previously had 3+ characters but now have less,
                    // we need to reset the remote search results
                    self.resetRemoteSearch()
                }
            }

            // Always reload with local results
            self.reloadThemes()
        }
    }

    // MARK: - UISearchControllerDelegate

    open func willPresentSearchController(_ searchController: UISearchController) {
        hideSectionHeaders = true
        if sections[0] == .info {
            collectionView?.collectionViewLayout.invalidateLayout()
            setInfoSectionHidden(true)
        }
    }

    open func didPresentSearchController(_ searchController: UISearchController) {
        WPAppAnalytics.track(.themesAccessedSearch, blog: blog)
    }

    open func willDismissSearchController(_ searchController: UISearchController) {
        hideSectionHeaders = false
        searchName = ""
        searchController.searchBar.text = ""
        resetRemoteSearch()
    }

    open func didDismissSearchController(_ searchController: UISearchController) {
        if sections[0] == .themes || sections[0] == .customThemes {
            setInfoSectionHidden(false)
        }
    }

    fileprivate func setInfoSectionHidden(_ hidden: Bool) {
        let hide = {
            self.collectionView?.deleteSections(IndexSet(integer: 0))
            self.sections = [.customThemes, .themes]
        }

        let show = {
            self.collectionView?.insertSections(IndexSet(integer: 0))
            self.sections = [.info, .customThemes, .themes]
        }

        collectionView.performBatchUpdates({
            hidden ? hide() : show()
        })
    }

    // MARK: - UISearchResultsUpdating

    open func updateSearchResults(for searchController: UISearchController) {
        updateSearchName(searchController.searchBar.text ?? "")
    }

    // MARK: - NSFetchedResultsController helpers

    fileprivate func browsePredicate() -> NSPredicate? {
        return browsePredicateThemesWithCustomValue(false)
    }

    fileprivate func customThemesBrowsePredicate() -> NSPredicate? {
        let browsePredicate = browsePredicateThemesWithCustomValue(true)

        // Search predicate for custom themes (local search only)
        if !searchName.isEmpty {
            let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@", searchName)
            if let existingPredicate = browsePredicate {
                return NSCompoundPredicate(andPredicateWithSubpredicates: [existingPredicate, searchPredicate])
            } else {
                return searchPredicate
            }
        }

        return browsePredicate
    }

    fileprivate func browsePredicateThemesWithCustomValue(_ custom: Bool) -> NSPredicate? {
        let blogPredicate = NSPredicate(format: "blog == %@ AND custom == %d", self.blog, custom ? 1 : 0)

        let subpredicates = [blogPredicate, filterType.predicate].compactMap { $0 }

        // For regular themes, add local search predicate if:
        // 1. Not using custom themes feature, or
        // 2. Search term is less than 3 characters (we'll only search locally for short terms)
        if !searchName.isEmpty && !custom && (!blog.supports(BlogFeature.customThemes) || searchName.count < 3) {
            let searchPredicate = NSPredicate(format: "name CONTAINS[cd] %@", searchName)
            return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates + [searchPredicate])
        }

        switch subpredicates.count {
        case 1:
            return subpredicates[0]
        default:
            return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        }
    }

    fileprivate func fetchThemes() {
        do {
            themesController.fetchRequest.predicate = browsePredicate()
            try themesController.performFetch()
            if self.blog.supports(BlogFeature.customThemes) {
                customThemesController.fetchRequest.predicate = customThemesBrowsePredicate()
                try customThemesController.performFetch()
            }
        } catch {
            DDLogError("Error fetching themes: \(error)")
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    open func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        reloadThemes()
    }

    // MARK: - ThemePresenter
    // optional closure that will be executed when the presented WebkitViewController closes
    @objc var onWebkitViewControllerClose: (() -> Void)?

    @objc open func activateTheme(_ theme: Theme?) {
        guard let theme, !theme.isCurrentTheme() else {
            return
        }

        updateActivateButton(isLoading: true)

        _ = themeService.activate(theme,
            for: blog,
            success: { [weak self] (theme: Theme?) in
            WPAppAnalytics.track(.themesChangedTheme, properties: ["theme_id": theme?.themeId ?? ""], blog: self?.blog)

                self?.collectionView?.reloadData()

                let successTitle = NSLocalizedString("Theme Activated", comment: "Title of alert when theme activation succeeds")
                let successFormat = NSLocalizedString("Thanks for choosing %@ by %@", comment: "Message of alert when theme activation succeeds")
                let successMessage = String(format: successFormat, theme?.name ?? "", theme?.author ?? "")
                let manageTitle = NSLocalizedString("Manage site", comment: "Return to blog screen action when theme activation succeeds")

                self?.updateActivateButton(isLoading: false)

                let alertController = UIAlertController(title: successTitle,
                    message: successMessage,
                    preferredStyle: .alert)
                alertController.addActionWithTitle(manageTitle,
                    style: .default,
                    handler: { [weak self] (action: UIAlertAction) in
                        _ = self?.navigationController?.popViewController(animated: true)
                    })
            alertController.addDefaultActionWithTitle(SharedStrings.Button.ok, handler: nil)
                alertController.presentFromRootViewController()
            },
            failure: { [weak self] (error) in
                DDLogError("Error activating theme \(String(describing: theme.themeId)): \(String(describing: error?.localizedDescription))")

                let errorTitle = NSLocalizedString("Activation Error", comment: "Title of alert when theme activation fails")

                self?.activityIndicator.stopAnimating()
                self?.activateButton?.customView = nil

                let alertController = UIAlertController(title: errorTitle,
                    message: error?.localizedDescription,
                    preferredStyle: .alert)
            alertController.addDefaultActionWithTitle(SharedStrings.Button.ok, handler: nil)
                alertController.presentFromRootViewController()
        })
    }

    @objc open func installThemeAndPresentCustomizer(_ theme: Theme) {
        _ = themeService.installTheme(theme,
            for: blog,
            success: { [weak self] in
                self?.presentUrlForTheme(theme, url: theme.customizeUrl(), activeButton: !theme.isCurrentTheme())
            }, failure: nil)
    }

    @objc open func presentCustomizeForTheme(_ theme: Theme?) {
        WPAppAnalytics.track(.themesCustomizeAccessed, blog: self.blog)
        presentUrlForTheme(theme, url: theme?.customizeUrl(), activeButton: false, modalStyle: .fullScreen)
    }

    @objc open func presentPreviewForTheme(_ theme: Theme?) {
        WPAppAnalytics.track(.themesPreviewedSite, blog: self.blog)
        // In order to Try & Customize a theme we first need to install it (Jetpack sites)
        if let theme, self.blog.supports(.customThemes) && !theme.custom {
            installThemeAndPresentCustomizer(theme)
        } else {
            presentUrlForTheme(theme, url: theme?.customizeUrl(), activeButton: !(theme?.isCurrentTheme() ?? true))
        }
    }

    @objc open func presentDetailsForTheme(_ theme: Theme?) {
        WPAppAnalytics.track(.themesDetailsAccessed, blog: self.blog)
        presentUrlForTheme(theme, url: theme?.detailsUrl())
    }

    @objc open func presentSupportForTheme(_ theme: Theme?) {
        WPAppAnalytics.track(.themesSupportAccessed, blog: self.blog)
        presentUrlForTheme(theme, url: theme?.supportUrl())
    }

    @objc open func presentViewForTheme(_ theme: Theme?) {
        WPAppAnalytics.track(.themesDemoAccessed, blog: self.blog)
        presentUrlForTheme(theme, url: theme?.viewUrl(), onClose: onWebkitViewControllerClose)
    }

    @objc open func presentUrlForTheme(
        _ theme: Theme?,
        url: String?,
        activeButton: Bool = true,
        modalStyle: UIModalPresentationStyle = .pageSheet,
        onClose: (() -> Void)? = nil
    ) {
        guard let theme, let url = url.flatMap(URL.init(string:)) else {
            return
        }

        suspendedSearch = searchName
        presentingTheme = theme
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticate(blog: theme.blog)
        configuration.secureInteraction = true
        configuration.customTitle = theme.name
        configuration.navigationDelegate = customizerNavigationDelegate
        configuration.onClose = onClose

        let title = activeButton ? ThemeAction.activate.title : ThemeAction.active.title
        activateButton = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(ThemeBrowserViewController.activatePresentingTheme))
        activateButton?.isEnabled = !theme.isCurrentTheme()

        let webViewController = WebViewControllerFactory.controller(configuration: configuration, source: "theme_browser")
        webViewController.navigationItem.rightBarButtonItem = activateButton

        let navigation = UINavigationController(rootViewController: webViewController)
        navigation.modalPresentationStyle = modalStyle
        if #available(iOS 18, *), let indexPath = collectionView.indexPathsForSelectedItems?.first {
            navigation.preferredTransition = .zoom(sourceViewProvider: { [weak self] _ in
                self?.collectionView.cellForItem(at: indexPath)?.contentView
            })
        }

        if searchController != nil && searchController.isActive {
            searchController.dismiss(animated: true, completion: {
                self.present(navigation, animated: true)
            })
        } else {
            present(navigation, animated: true)
        }
    }

    @objc open func activatePresentingTheme() {
        suspendedSearch = ""
        activateTheme(presentingTheme)
        presentingTheme = nil
    }
}

// MARK: - NoResults Handling

private extension ThemeBrowserViewController {

    func updateResults() {
        if themeCount == 0 && customThemeCount == 0 {
            showNoResults()
        } else {
            hideNoResults()
        }
    }

    func showNoResults() {

        guard !noResultsShown else {
            return
        }

        if noResultsViewController == nil {
            noResultsViewController = NoResultsViewController.controller()
        }

        guard let noResultsViewController else {
            return
        }

        if searchController.isActive {
            noResultsViewController.configureForNoSearchResults(title: NoResultsTitles.noThemes)
        } else {
            noResultsViewController.configure(title: NoResultsTitles.fetchingThemes, accessoryView: NoResultsViewController.loadingAccessoryView())
        }

        addChild(noResultsViewController)
        collectionView.addSubview(noResultsViewController.view)
        noResultsViewController.view.frame = collectionView.frame
        noResultsViewController.didMove(toParent: self)
    }

    func hideNoResults() {

        guard noResultsShown else {
            return
        }

        noResultsViewController?.removeFromView()

        if searchController.isActive {
            collectionView?.reloadData()
        } else {
            sections = [.info, .customThemes, .themes]
            collectionView?.collectionViewLayout.invalidateLayout()
        }
    }
}
