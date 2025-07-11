import UIKit
@preconcurrency import WebKit
import Gridicons
import Combine
import WordPressData
import WordPressShared

protocol JetpackConnectionWebDelegate: AnyObject {
    func jetpackConnectionCompleted()
    func jetpackConnectionCanceled()
}

class JetpackConnectionWebViewController: UIViewController {
    let blog: Blog
    let webView: WKWebView
    let progressView = WebProgressView()
    weak var delegate: JetpackConnectionWebDelegate?

    // Sometimes wp-login doesn't redirect to the expected URL, so we're storing
    // it and redirecting manually
    fileprivate var pendingSiteRedirect: URL?
    fileprivate var account: WPAccount?

    private var analyticsErrorWasTracked = false

    /// Only used to handle site-connection state and establish user-connection required for the app
    private var nativeConnectionService: JetpackNativeConnectionService?
    private var subscriptions: Set<AnyCancellable> = []

    init(blog: Blog) {
        self.blog = blog
        let configuration = WKWebViewConfiguration()
        if Debug.enabled {
            configuration.websiteDataStore = .nonPersistent()
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        title = NSLocalizedString("Set up Jetpack", comment: "Title for the Jetpack Installation & Connection")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let stackView = UIStackView(arrangedSubviews: [
            progressView,
            webView
            ])
        stackView.axis = .vertical
        view = stackView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        progressView.observeProgress(webView: webView)

        if isModal() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(JetpackConnectionWebViewController.cancel))
        }

        if let jetpack = blog.jetpack, jetpack.isSiteConnection {
            startNativeConnectionFlow()
        } else {
            startConnectionFlow()
        }
    }

    func startConnectionFlow() {
        let url: URL
        if let escapedSiteURL = blog.homeURL?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            url = URL(string: "https://wordpress.com/jetpack/connect?url=\(escapedSiteURL)&mobile_redirect=\(mobileRedirectURL)&from=mobile")!
        } else {
            url = URL(string: "https://wordpress.com/jetpack/connect?mobile_redirect=\(mobileRedirectURL)&from=mobile")!
        }

        let request = URLRequest(url: url)
        webView.load(request)

        WPAnalytics.track(.installJetpackWebviewSelect)
    }

    @objc func cancel() {
        delegate?.jetpackConnectionCanceled()
    }
}

extension JetpackConnectionWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
            navigationAction.request.httpMethod == "GET",
            navigationAction.targetFrame?.isMainFrame ?? false,
            let step = flowStep(url: url) else {
                decisionHandler(.allow)
                return
        }

        Debug.log("🚀🔌 Step: \(step)")
        if step.isAdminPage,
            let redirect = pendingSiteRedirect {
            pendingSiteRedirect = nil
            decisionHandler(.cancel)
            webView.load(URLRequest(url: redirect))
            return
        }

        switch step {
        case .siteLoginForm(let redirect):
            performSiteLogin(redirect: redirect, decisionHandler: decisionHandler)
        case .dotComLoginForm(let redirect):
            decisionHandler(.cancel)
            performDotComLogin(redirect: redirect)
        case .mobileRedirect:
            decisionHandler(.cancel)
            handleMobileRedirect()
        default:
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if analyticsErrorWasTracked {
            return
        }

        WPAnalytics.track(.installJetpackWebviewFailed)
        analyticsErrorWasTracked.toggle()
    }
}

private extension URL {
    func matchesPath(in other: URL) -> Bool {
        return scheme == other.scheme
            && host == other.host
            && port == other.port
            && path == other.path
    }
}

private extension JetpackConnectionWebViewController {
    enum FlowStep: CustomStringConvertible {
        case siteLoginForm(redirect: URL)
        case sitePluginDetail
        case sitePluginInstallation
        case sitePlugins
        case siteAdmin
        case dotComLoginForm(redirect: URL)
        case mobileRedirect

        var description: String {
            switch self {
            case .siteLoginForm(let redirect):
                return "Site login form, redirecting to \(redirect)"
            case .sitePluginDetail:
                return "Plugin detail page"
            case .sitePluginInstallation:
                return "Plugin installation page"
            case .sitePlugins:
                return "Installed plugins page"
            case .siteAdmin:
                return "Unknown wp-admin page"
            case .dotComLoginForm(let redirect):
                return "WordPress.com login, redirecting to \(redirect)"
            case .mobileRedirect:
                return "Mobile Redirect, end of the connection flow"
            }
        }

        var isAdminPage: Bool {
            switch self {
            case .sitePluginDetail, .sitePluginInstallation, .sitePlugins, .siteAdmin:
                return true
            case .siteLoginForm, .dotComLoginForm, .mobileRedirect:
                return false
            }
        }
    }

    func flowStep(url: URL) -> FlowStep? {
        switch url {
        case isSiteLogin:
            return extractRedirect(url: url)
                .map(FlowStep.siteLoginForm)
        case isDotComLogin:
            return extractRedirect(url: url)
                .map(FlowStep.dotComLoginForm)
        case isSiteAdmin(path: "plugin-install.php"):
            return .sitePluginDetail
        case isSiteAdmin(path: "update.php?action=install-plugin"):
            return .sitePluginInstallation
        case isSiteAdmin(path: "plugins.php"):
            return .sitePlugins
        case isSiteAdmin(path: ""):
            return .siteAdmin
        case mobileRedirectURL:
            return .mobileRedirect
        default:
            return nil
        }
    }

    var mobileRedirectURL: URL {
        return URL(string: "wordpress://jetpack-connection")!
    }

    func isSiteLogin(url: URL) -> Bool {
        guard let loginURL = URL(string: blog.loginUrl()) else {
            return false
        }

        return url.matchesPath(in: loginURL)
    }

    /// Returns a function that matches a wp-admin URL with the given path
    ///
    func isSiteAdmin(path: String) -> (URL) -> Bool {
        guard let adminURL = URL(string: blog.adminUrl(withPath: path)) else {
            return { _ in return false }
        }
        return { url in
            return url.absoluteString.hasPrefix(adminURL.absoluteString)
        }
    }

    func isDotComLogin(url: URL) -> Bool {
        let dotComLoginURL = URL(string: "https://wordpress.com/log-in")!
        let dotComJetpackLoginURL = URL(string: "https://wordpress.com/log-in/jetpack")!
        return url.matchesPath(in: dotComLoginURL) || url.matchesPath(in: dotComJetpackLoginURL)
    }

    func extractRedirect(url: URL) -> URL? {
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "redirect_to" })?
            .value
            .flatMap(URL.init(string:))
    }

    func handleMobileRedirect() {
        let service = BlogService(coreDataStack: ContextManager.shared)
        let success: () -> Void = { [weak self] in
            self?.delegate?.jetpackConnectionCompleted()
        }
        let failure: (Error) -> Void = { (error) in
            DDLogError("\(error)")
            success()
        }
        service.syncBlog(
            blog,
            success: { [weak self] in
                guard let self else { return }

                guard let account = self.account ?? self.defaultAccount() else {
                    // There could be no account in some cases where user has connected
                    // their site to .com account on webView
                    // without logging into the account in the app
                    Task { @MainActor in
                        let email = self.blog.jetpack?.connectedEmail
                        let accountID = await WordPressDotComAuthenticator().signIn(from: self, context: .jetpackSite(accountEmail: email))
                        if let accountID {
                            let account = try ContextManager.shared.mainContext.existingObject(with: accountID)
                            service.associateSyncedBlogs(
                                toJetpackAccount: account,
                                success: success,
                                failure: failure
                            )
                        }
                    }

                    return
                }
                service.associateSyncedBlogs(
                    toJetpackAccount: account,
                    success: success,
                    failure: failure
                )
            },
            failure: failure
        )
    }

    func performSiteLogin(redirect: URL, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let authenticator = RequestAuthenticator(blog: blog) else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)

        authenticator.request(url: redirect, cookieJar: webView.configuration.websiteDataStore.httpCookieStore, completion: { request in
            DDLogDebug("Performing site login to \(String(describing: request.url))")
            self.pendingSiteRedirect = redirect
            self.webView.load(request)
        })
    }

    func performDotComLogin(redirect: URL) {
        if let account = defaultAccount(),
            let token = account.authToken {
            authenticateWithDotCom(username: account.username, token: token, redirect: redirect)
        } else {
            presentDotComLogin(redirect: redirect)
        }
    }

    func authenticateWithDotCom(username: String, token: String, redirect: URL) {
        let authenticator = RequestAuthenticator(credentials: .dotCom(username: username, authToken: token, authenticationType: .regular))

        authenticator.request(url: redirect, cookieJar: webView.configuration.websiteDataStore.httpCookieStore, completion: { request in
            DDLogDebug("Performing WordPress.com login to \(String(describing: request.url))")
            self.webView.load(request)
        })
    }

    func presentDotComLogin(redirect: URL) {

        Task { @MainActor in
            let email = self.blog.jetpack?.connectedEmail
            guard let _ = await WordPressDotComAuthenticator().signIn(from: self, context: .jetpackSite(accountEmail: email)) else {
                return
            }

            self.performDotComLogin(redirect: redirect)
        }
    }

    func defaultAccount() -> WPAccount? {
        try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext)
    }

    enum Debug {
        static var enabled: Bool {
            return CommandLine.arguments.contains("-debugJetpackConnectionFlow")
        }

        static func log(_ message: String) {
            guard enabled else {
                return
            }
            DDLogDebug("\(message)")
        }
    }
}

/// If Jetpack is in site-connection state (Jetpack plugin is connected to the site but the site is not connected to .com account)
/// JetpackConnectionWebViewController conection flows that use jetpack/connect/ URL do not work
/// Using Jetpack REST APIs to fetch the required connection URLs to establish user-connection state
/// See https://github.com/wordpress-mobile/WordPress-iOS/issues/16489
///
private extension JetpackConnectionWebViewController {
    func startNativeConnectionFlow() {
        guard let api = blog.selfHostedSiteRestApi else {
            DDLogInfo("WordPressOrgRestAPI not loaded to perform native Jetpack connection")
            startConnectionFlow()
            return
        }

        WPAnalytics.track(.jetpackPluginConnectUserAccountStarted)

        /// Observe all types of redictions happening on WKWebView which are not triggering decidePolicy delegate
        subscriptions.removeAll()
        webView.publisher(for: \.url)
            .sink { [weak self] url in
                guard let self, let siteURL = self.blog.url else { return }
                self.handleNativeConnection(url?.absoluteString ?? "", siteURL: siteURL)
            }
            .store(in: &subscriptions)

        nativeConnectionService = JetpackNativeConnectionService(api: api)

        nativeConnectionService?.fetchJetpackConnectionURL() { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let url):
                let request = URLRequest(url: url)
                self.webView.load(request)
            case .failure(let error):
                DDLogError("Failed fetching Jetpack connection URL: \(error.localizedDescription)")
                self.delegate?.jetpackConnectionCanceled()

                WPAnalytics.track(.jetpackPluginConnectUserAccountFailed)
            }
        }
    }

    func handleNativeConnection(_ url: String, siteURL: String) {
        let plansPage = "https://wordpress.com/jetpack/connect/plans"
        // When the web view navigates to Jetpack plans page we can assume that the setup has completed.
        if url.hasPrefix(plansPage) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.nativeConnectionService?.fetchJetpackUser() { result in
                    switch result {
                    case .success(let user):
                        if user.isConnected {
                            DDLogInfo("Jetpack user is connected after native connection flow is completed")

                            WPAnalytics.track(.jetpackPluginConnectUserAccountCompleted)
                        } else {
                            DDLogError("Jetpack user is not connected after native connection flow is completed")

                            WPAnalytics.track(.jetpackPluginConnectUserAccountFailed)
                        }
                    case .failure(let error):
                        DDLogError("Failed fetching Jetpack user: \(error.localizedDescription)")

                        WPAnalytics.track(.jetpackPluginConnectUserAccountFailed)
                    }

                    self.handleMobileRedirect()
                }
            }
        }
    }
}
