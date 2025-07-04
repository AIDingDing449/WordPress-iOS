import WebKit
import CoreMedia
import WordPressData

@objc
public protocol SharingAuthorizationDelegate: NSObjectProtocol {
    @objc
    func authorize(_ publicizer: PublicizeService, didFailWithError error: NSError)

    @objc
    func authorizeDidSucceed(_ publicizer: PublicizeService)

    @objc
    func authorizeDidCancel(_ publicizer: PublicizeService)
}

class SharingAuthorizationWebViewController: WebKitViewController {
    private static let loginURL = "https://wordpress.com/wp-login.php"

    /// Verification loading -- dismiss on completion
    ///
    private var loadingVerify: Bool = false

    /// Publicize service being authorized
    ///
    private let publicizer: PublicizeService

    private var hosts = [String]()

    private weak var delegate: SharingAuthorizationDelegate?

    init(with publicizer: PublicizeService, url: URL, for blog: Blog, delegate: SharingAuthorizationDelegate) {
        self.delegate = delegate
        self.publicizer = publicizer

        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticate(blog: blog)
        configuration.secureInteraction = true

        super.init(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

     // MARK: - View Lifecycle

     override func viewWillDisappear(_ animated: Bool) {
         super.viewWillDisappear(animated)

         cleanupCookies()
     }

    // MARK: - Cookies Management

    /// Saves the host from the specidied URL for cleaning up cookies when done.
    ///
    /// - Parameters:
    ///     - url: the URL to retrieve the host from.
    ///
    func saveHostForCookiesCleanup(from url: URL) {
        guard let host = url.host,
            !host.contains("wordpress"),
            !hosts.contains(host) else {
                return
        }

        let components = host.components(separatedBy: ".")

        // A bit of paranioa here. The components should never be less than two but just in case...
        guard let hostName = components.count > 1 ? components[components.count - 2] : components.first else {
            return
        }

        hosts.append(hostName)
    }

    /// Cleanup cookies
    ///
    func cleanupCookies() {
        let storage = HTTPCookieStorage.shared

        guard let cookies = storage.cookies else {
            // Nothing to cleanup
            return
        }

        for cookie in cookies {
            for host in hosts {
                if cookie.domain.contains(host) {
                    storage.deleteCookie(cookie)
                }
            }
        }
    }

    // MARK: - Misc

    override func close() {
        guard let delegate else {
            super.close()
            return
        }

        delegate.authorizeDidCancel(publicizer)
    }

    private func handleAuthorizationAllowed() {
        // Note: There are situations where this can be called in error due to how
        // individual services choose to reply to an authorization request.
        // Delegates should expect to handle a false positive.
        delegate?.authorizeDidSucceed(publicizer)
    }
}

// MARK: - WKNavigationDelegate

extension SharingAuthorizationWebViewController {
    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decidePolicy(webView: webView, navigationAction: navigationAction, decisionHandler: decisionHandler)
    }

    private func decidePolicy(webView: WKWebView, navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // Prevent a second verify load by someone happy clicking.
        guard !loadingVerify,
            let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
        }

        let action = PublicizeConnectionURLMatcher.authorizeAction(for: url)

        switch action {
        case .none:
            fallthrough
        case .unknown:
            fallthrough
        case .request:
            super.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
            return
        case .verify:
            loadingVerify = true
            decisionHandler(.allow)
            return
        case .deny:
            decisionHandler(.cancel)
            close()
            return
        }
    }

    override func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if loadingVerify && (error as NSError).code == NSURLErrorCancelled {
            // Authenticating to Facebook and Twitter can return an false
            // NSURLErrorCancelled (-999) error. However the connection still succeeds.
            handleAuthorizationAllowed()
            return
        }

        super.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            saveHostForCookiesCleanup(from: url)
        }

        if loadingVerify {
            handleAuthorizationAllowed()
        } else {
            super.webView(webView, didFinish: navigation)
        }
    }
}
