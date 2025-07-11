import UIKit
import BuildSettingsKit
import WordPressData
import WordPressShared
import AutomatticAbout
import GravatarUI

public class MeViewController: UITableViewController {
    var handler: ImmuTableViewHandler!
    var isSidebarModeEnabled = false

    private lazy var headerView = MeHeaderView()

    // MARK: - Table View Controller

    public override init(style: UITableView.Style) {
        super.init(style: style)
        navigationItem.title = NSLocalizedString("Me", comment: "Me page title")
        clearsSelectionOnViewWillAppear = false
    }

    public required convenience init() {
        self.init(style: .insetGrouped)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(refreshModelWithNotification(_:)), name: .ZendeskPushNotificationReceivedNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(refreshModelWithNotification(_:)), name: .ZendeskPushNotificationClearedNotification, object: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        if isSidebarModeEnabled {
            /// We can't use trait collection here because on iPad .form sheet is still
            /// considered to be ` .compact` size class, so it has to be invoked manually.
            headerView.configureHorizontalMode()
        }
        headerView.delegate = self

        ImmuTable.registerRows([
            VerifyEmailRow.self,
            NavigationItemRow.self,
            IndicatorNavigationItemRow.self,
            ButtonRow.self,
            DestructiveButtonRow.self
        ], tableView: self.tableView)

        handler = ImmuTableViewHandler(takeOver: self)
        WPStyleGuide.configureAutomaticHeightRows(for: tableView)

        NotificationCenter.default.addObserver(self, selector: #selector(MeViewController.accountDidChange), name: .wpAccountDefaultWordPressComAccountChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MeViewController.refreshAccountDetailsAndSettings), name: UIApplication.didBecomeActiveNotification, object: nil)

        WPStyleGuide.configureColors(view: view, tableView: tableView)
        tableView.accessibilityIdentifier = "Me Table"

        reloadViewModel()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        tableView.layoutHeaderView()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        refreshAccountDetailsAndSettings()
        animateDeselectionInteractively()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        registerUserActivity()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        // Required to update the tableview cell disclosure indicators
        reloadViewModel()
    }

    @objc fileprivate func accountDidChange() {
        reloadViewModel()
    }

    @objc fileprivate func reloadViewModel() {
        let account = defaultAccount()

        // Warning: If you set the header view after the table model, the
        // table's top margin will be wrong.
        //
        // My guess is the table view adjusts the height of the first section
        // based on if there's a header or not.
        if let account {
            headerView.update(with: MeHeaderViewModel(account: account))
        }
        tableView.tableHeaderView = headerView

        // Then we'll reload the table view model (prompting a table reload)
        handler.viewModel = tableViewModel(with: account)
    }

    private var appSettingsRow: NavigationItemRow {
        return NavigationItemRow(
            title: RowTitles.appSettings,
            icon: UIImage(named: UIDevice.isPad() ? "wpl-tablet" : "wpl-phone")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            accessoryType: .disclosureIndicator,
            action: pushAppSettings(),
            accessibilityIdentifier: "appSettings"
        )
    }

    fileprivate func tableViewModel(with account: WPAccount?) -> ImmuTable {
        let accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator
        let loggedIn = account != nil

        var verificationSection: ImmuTableSection?
        if let account, account.verificationStatus == .unverified {
            verificationSection = ImmuTableSection(rows: [VerifyEmailRow()])
        }

        let myProfile = NavigationItemRow(
            title: RowTitles.myProfile,
            icon: UIImage(named: "site-menu-people")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            accessoryType: accessoryType,
            action: presentGravatarAboutEditorAction(),
            accessibilityIdentifier: "myProfile")

        let qrLogin = NavigationItemRow(
            title: RowTitles.qrLogin,
            icon: UIImage(named: "wpl-capture-photo")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            accessoryType: accessoryType,
            action: presentQRLogin(),
            accessibilityIdentifier: "qrLogin")

        let accountSettings = NavigationItemRow(
            title: RowTitles.accountSettings,
            icon: UIImage(named: "wpl-gearshape")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            accessoryType: accessoryType,
            action: pushAccountSettings(),
            accessibilityIdentifier: "accountSettings")

        let domains = NavigationItemRow(
            title: AllDomainsListViewController.Strings.title,
            icon: UIImage(named: "wpl-globe")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            accessoryType: accessoryType,
            action: { [weak self] action in
                self?.showOrPushController(AllDomainsListViewController())
                WPAnalytics.track(.meDomainsTapped)
            },
            accessibilityIdentifier: "myDomains"
        )

        let helpAndSupportIndicator = IndicatorNavigationItemRow(
            title: RowTitles.support,
            icon: UIImage(named: "wpl-help")?.withRenderingMode(.alwaysTemplate),
            tintColor: .label,
            showIndicator: ZendeskUtils.showSupportNotificationIndicator,
            accessoryType: accessoryType,
            action: pushHelp())

        let logIn = ButtonRow(
            title: RowTitles.logIn,
            action: presentLogin())

        let logOut = DestructiveButtonRow(
            title: RowTitles.logOut,
            action: logoutRowWasPressed(),
            accessibilityIdentifier: "logOutFromWPcomButton")

        let wordPressComAccount = HeaderTitles.wpAccount

        let shouldShowQRLoginRow = FeatureFlag.qrCodeLogin.enabled && !(account?.settings?.twoStepEnabled ?? false)

        var sections: [ImmuTableSection] = []

        // Add verification section first if it exists
        if let verificationSection {
            sections.append(verificationSection)
        }

        sections.append(contentsOf: [
            ImmuTableSection(rows: {
                var rows: [ImmuTableRow] = [appSettingsRow]
                if loggedIn {
                    var loggedInRows = [myProfile, accountSettings]
                    if shouldShowQRLoginRow {
                        loggedInRows.append(qrLogin)
                    }
                    if BuildSettings.current.brand == .jetpack, RemoteFeatureFlag.domainManagement.enabled() && !isSidebarModeEnabled {
                        loggedInRows.append(domains)
                    }
                    rows = loggedInRows + rows
                }
                return rows
            }()),
            ImmuTableSection(rows: [helpAndSupportIndicator]),
        ])

        sections.append(
            ImmuTableSection(rows: [
                ButtonRow(
                    title: ShareAppContentPresenter.RowConstants.buttonTitle,
                    textAlignment: .left,
                    isLoading: sharePresenter.isLoading,
                    action: displayShareFlow()
                ),
                ButtonRow(
                    title: RowTitles.about,
                    textAlignment: .left,
                    action: pushAbout(),
                    accessibilityIdentifier: "About"
                )
            ])
        )

        // last section
        sections.append(
            .init(headerText: wordPressComAccount, rows: {
                return [loggedIn ? logOut : logIn]
            }())
        )

        return ImmuTable(sections: sections)
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let isNewSelection = (indexPath != tableView.indexPathForSelectedRow)

        if isNewSelection {
            return indexPath
        } else {
            return nil
        }
    }

    // MARK: - Actions

    fileprivate func presentGravatarAboutEditorAction() -> ImmuTableAction {
        return { [unowned self] row in
            presentGravatarQuickEditor(initialPage: .aboutEditor)
        }
    }

    fileprivate func presentGravatarQuickEditor(initialPage: AvatarPickerAndAboutEditorConfiguration.Page) {
        let scope = QuickEditorScopeOption.avatarPickerAndAboutInfoEditor(.init(
            contentLayout: .horizontal(),
            fields: [.displayName, .aboutMe, .firstName, .lastName],
            initialPage: initialPage
        ))

        let presenter = GravatarQuickEditorPresenter() { [weak self] in
            self?.refreshAccountDetailsAndSettings()
        }

        presenter?.presentQuickEditor(
            on: self,
            scope: scope
        )
    }

    fileprivate func pushAccountSettings() -> ImmuTableAction {
        return { [unowned self] row in
            if let account = self.defaultAccount() {
                WPAppAnalytics.track(.openedAccountSettings)
                guard let controller = AccountSettingsViewController(account: account) else {
                    return
                }
                self.showOrPushController(controller)
            }
        }
    }

    private func presentQRLogin() -> ImmuTableAction {
        return { [weak self] row in
            guard let self else {
                return
            }

            self.tableView.deselectSelectedRowWithAnimation(true)
            QRLoginCoordinator.present(from: self, origin: .menu)
        }
    }

    func pushAppSettings() -> ImmuTableAction {
        return { [unowned self] row in
            self.navigateToAppSettings()
        }
    }

    func pushHelp() -> ImmuTableAction {
        return { [unowned self] row in
            let controller = SupportTableViewController(style: .insetGrouped)
            self.showOrPushController(controller)
        }
    }

    private func pushAbout() -> ImmuTableAction {
        return { [unowned self] _ in
            let configuration = AppAboutScreenConfiguration(sharePresenter: self.sharePresenter)
            let controller = AutomatticAboutScreen.controller(appInfo: AppAboutScreenConfiguration.appInfo,
                                                              configuration: configuration,
                                                              fonts: AppAboutScreenConfiguration.fonts)
            self.present(controller, animated: true) {
                self.tableView.deselectSelectedRowWithAnimation(true)
            }
        }
    }

    func displayShareFlow() -> ImmuTableAction {
        return { [unowned self] row in
            defer {
                self.tableView.deselectSelectedRowWithAnimation(true)
            }

            guard let selectedIndexPath = self.tableView.indexPathForSelectedRow,
                  let selectedCell = self.tableView.cellForRow(at: selectedIndexPath) else {
                return
            }

            self.sharePresenter.present(for: BuildSettings.current.shareAppName, in: self, source: .me, sourceView: selectedCell)
        }
    }

    fileprivate func presentLogin() -> ImmuTableAction {
        return { [unowned self] row in
            self.tableView.deselectSelectedRowWithAnimation(true)
            self.promptForLoginOrSignup()
        }
    }

    fileprivate func logoutRowWasPressed() -> ImmuTableAction {
        return { [unowned self] row in
            self.tableView.deselectSelectedRowWithAnimation(true)
            self.displayLogOutAlert()
        }
    }

    /// Selects the Account Settings row and pushes the Account Settings view controller
    ///
    func navigateToAccountSettings() {
        navigateToTarget(for: RowTitles.accountSettings)
    }

    /// Selects the All Domains row and pushes the All Domains view controller
    ///
    public func navigateToAllDomains() {
        navigateToTarget(for: AllDomainsListViewController.Strings.title)
    }

    /// Selects the App Settings row and pushes the App Settings view controller
    ///
    func navigateToAppSettings(completion: ((AppSettingsViewController) -> Void)? = nil) {
        self.selectRowForTitle(appSettingsRow.title)
        WPAppAnalytics.track(.openedAppSettings)
        let destination = AppSettingsViewController()
        self.showOrPushController(destination) {
            completion?(destination)
        }
    }

    /// Selects the Help & Support row and pushes the Support view controller
    ///
    func navigateToHelpAndSupport() {
        navigateToTarget(for: RowTitles.support)
    }

    fileprivate func navigateToTarget(for rowTitle: String) {
        let matchRow: ((ImmuTableRow) -> Bool) = { row in
            if let row = row as? NavigationItemRow {
                return row.title == rowTitle
            } else if let row = row as? IndicatorNavigationItemRow {
                return row.title == rowTitle
            }
            return false
        }

        if let sections = handler?.viewModel.sections,
           let section = sections.firstIndex(where: { $0.rows.contains(where: matchRow) }),
           let row = sections[section].rows.firstIndex(where: matchRow) {
            let indexPath = IndexPath(row: row, section: section)

            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
            handler.tableView(self.tableView, didSelectRowAt: indexPath)
        }
    }

    private func selectRowForTitle(_ rowTitle: String) {
        self.tableView.selectRow(at: indexPathForRowTitle(rowTitle), animated: true, scrollPosition: .middle)
    }

    private func indexPathForRowTitle(_ rowTitle: String) -> IndexPath? {
        let matchRow: ((ImmuTableRow) -> Bool) = { row in
            if let row = row as? NavigationItemRow {
                return row.title == rowTitle
            } else if let row = row as? IndicatorNavigationItemRow {
                return row.title == rowTitle
            }
            return false
        }

        guard let sections = handler?.viewModel.sections,
              let section = sections.firstIndex(where: { $0.rows.contains(where: matchRow) }),
              let row = sections[section].rows.firstIndex(where: matchRow) else {
            return nil
        }
        return IndexPath(row: row, section: section)
    }

    private func showOrPushController(_ controller: UIViewController, completion: (() -> Void)? = nil) {
        if let navigationController {
            navigationController.pushViewController(controller, animated: true, rightBarButton: self.isSidebarModeEnabled ? nil : self.navigationItem.rightBarButtonItem)
            navigationController.transitionCoordinator?.animate(alongsideTransition: nil, completion: { _ in
                completion?()
            })
        } else {
            completion?()
        }
    }

    // MARK: - Helpers

    // FIXME: (@koke 2015-12-17) Not cool. Let's stop passing managed objects
    // and initializing stuff with safer values like userID
    fileprivate func defaultAccount() -> WPAccount? {
        return try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext)
    }

    @objc fileprivate func refreshAccountDetailsAndSettings() {
        guard let account = defaultAccount(), let userID = account.userID, let api = account.wordPressComRestApi else {
            reloadViewModel()
            return
        }

        let accountService = AccountService(coreDataStack: ContextManager.shared)
        let accountSettingsService = AccountSettingsService(userID: userID.intValue, api: api)

        Task {
            do {
                async let refreshDetails: Void = Self.refreshAccountDetails(with: accountService, account: account)
                async let refreshSettings: Void = Self.refreshAccountSettings(with: accountSettingsService)
                let _ = try await [refreshDetails, refreshSettings]
                self.reloadViewModel()
            } catch let error {
                DDLogError("\(error.localizedDescription)")
            }
        }
    }

    fileprivate static func refreshAccountDetails(with service: AccountService, account: WPAccount) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            service.updateUserDetails(for: account, success: {
                continuation.resume()
            }, failure: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    fileprivate static func refreshAccountSettings(with service: AccountSettingsService) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            service.refreshSettings { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - LogOut

    private func displayLogOutAlert() {
        let alert = UIAlertController(title: logOutAlertTitle, message: nil, preferredStyle: .alert)
        alert.addActionWithTitle(LogoutAlert.cancelAction, style: .cancel)
        alert.addActionWithTitle(LogoutAlert.logoutAction, style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true) {
                AccountHelper.logOutDefaultWordPressComAccount()
            }
        }

        present(alert, animated: true)
    }

    private var logOutAlertTitle: String {
        let context = ContextManager.shared.mainContext
        let count = AbstractPost.countLocalPosts(in: context)

        guard count > 0 else {
            return LogoutAlert.defaultTitle
        }

        let format = count > 1 ? LogoutAlert.unsavedTitlePlural : LogoutAlert.unsavedTitleSingular
        return String(format: format, count)
    }

    // MARK: - Private Properties

    /// Shows an actionsheet with options to Log In or Create a WordPress site.
    /// This is a temporary stop-gap measure to preserve for users only logged
    /// into a self-hosted site the ability to create a WordPress.com account.
    ///
    fileprivate func promptForLoginOrSignup() {
        Task {
            await WordPressDotComAuthenticator().signIn(from: self, context: .default)
        }
    }

    private lazy var sharePresenter: ShareAppContentPresenter = {
        let presenter = ShareAppContentPresenter(account: defaultAccount())
        presenter.delegate = self
        return presenter
    }()
}

// MARK: - SearchableActivity Conformance

extension MeViewController: SearchableActivityConvertable {
    public var activityType: String {
        return WPActivityType.me.rawValue
    }

    public var activityTitle: String {
        return NSLocalizedString("Me", comment: "Title of the 'Me' tab - used for spotlight indexing on iOS.")
    }

    public var activityKeywords: Set<String>? {
        let keyWordString = NSLocalizedString("wordpress, me, settings, account, notification log out, logout, log in, login, help, support",
                                              comment: "This is a comma separated list of keywords used for spotlight indexing of the 'Me' tab.")
        let keywordArray = keyWordString.arrayOfTags()

        guard !keywordArray.isEmpty else {
            return nil
        }

        return Set(keywordArray)
    }
}

// MARK: - Constants

extension MeViewController {
    enum RowTitles {
        static let appSettings = NSLocalizedString("App Settings", comment: "Link to App Settings section")
        static let myProfile = NSLocalizedString("My Profile", comment: "Link to My Profile section")
        static let accountSettings = NSLocalizedString("Account Settings", comment: "Link to Account Settings section")
        static let qrLogin = NSLocalizedString("Scan Login Code", comment: "Link to opening the QR login scanner")
        static let support = NSLocalizedString("Help & Support", comment: "Link to Help section")
        static let logIn = NSLocalizedString("Log In", comment: "Label for logging in to WordPress.com account")
        static let logOut = NSLocalizedString("Log Out", comment: "Label for logging out from WordPress.com account")
        static var about: String {
            switch BuildSettings.current.brand {
            case .wordpress:
                NSLocalizedString("About WordPress", comment: "Link to About screen for WordPress for iOS")
            case .jetpack:
                NSLocalizedString("About Jetpack for iOS", comment: "Link to About screen for Jetpack for iOS")
            case .reader:
                NSLocalizedString("About Reader for iOS", comment: "Link to About screen for Jetpack for iOS")
            }
        }
    }

    enum HeaderTitles {
        static let wpAccount = NSLocalizedString("WordPress.com Account", comment: "WordPress.com sign-in/sign-out section header title")
    }

    enum LogoutAlert {
        static var defaultTitle: String {
            switch BuildSettings.current.brand {
            case .wordpress:
                NSLocalizedString("Log out of WordPress?", comment: "LogOut confirmation text, whenever there are no local changes")
            case .jetpack:
                NSLocalizedString("Log out of Jetpack?", comment: "LogOut confirmation text, whenever there are no local changes")
            case .reader:
                NSLocalizedString("Log out of Reader?", comment: "LogOut confirmation text, whenever there are no local changes")
            }
        }

        static let unsavedTitleSingular = NSLocalizedString("You have changes to %d post that hasn't been uploaded to your site. Logging out now will delete those changes. Log out anyway?",
                                                            comment: "Warning displayed before logging out. The %d placeholder will contain the number of local posts (SINGULAR!)")
        static let unsavedTitlePlural = NSLocalizedString("You have changes to %d posts that haven’t been uploaded to your site. Logging out now will delete those changes. Log out anyway?",
                                                          comment: "Warning displayed before logging out. The %d placeholder will contain the number of local posts (PLURAL!)")
        static let cancelAction = NSLocalizedString("Cancel", comment: "Verb. A button title. Tapping cancels an action.")
        static let logoutAction = NSLocalizedString("Log Out", comment: "Button for confirming logging out from WordPress.com account")
    }
}

// MARK: - Private Extension for Notification handling

private extension MeViewController {

    @objc func refreshModelWithNotification(_ notification: Foundation.Notification) {
        reloadViewModel()
    }
}

// MARK: - ShareAppContentPresenterDelegate

extension MeViewController: ShareAppContentPresenterDelegate {
    func didUpdateLoadingState(_ loading: Bool) {
        reloadViewModel()
    }
}

// MARK: - Jetpack powered badge
extension MeViewController {

    public override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == handler.viewModel.sections.count - 1,
              JetpackBrandingVisibility.all.enabled else {
            return nil
        }
        let textProvider = JetpackBrandingTextProvider(screen: JetpackBadgeScreen.me)
        return JetpackButton.makeBadgeView(title: textProvider.brandingText(),
                                           target: self,
                                           selector: #selector(jetpackButtonTapped))
    }

    @objc private func jetpackButtonTapped() {
        JetpackBrandingCoordinator.presentOverlay(from: self)
        JetpackBrandingAnalyticsHelper.trackJetpackPoweredBadgeTapped(screen: .me)
    }
}

// MARK: - Header avatar tap handler (MeHeaderViewDelegate)

extension MeViewController: MeHeaderViewDelegate {
    func meHeaderViewDidTapOnIconView(_ view: MeHeaderView) {
        presentGravatarQuickEditor(initialPage: .avatarPicker)
    }
}

private enum Strings {
    static let submitFeedback = NSLocalizedString("meMenu.submitFeedback", value: "Send Feedback", comment: "Me tab menu items")
}
