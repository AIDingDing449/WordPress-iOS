import Foundation
import UIKit
import WordPressData
import WordPressShared
import WordPressAuthenticator
import WordPressUI
import WordPressAPIInternal

protocol JetpackConnectionSupport: AnyObject {
    init?(blog: Blog)

    var blog: Blog { get set }

    var promptType: JetpackLoginPromptType { get set }

    var completionBlock: (() -> Void)? { get set }

    func refreshUI()
}

typealias ConnectJetpackViewController = UIViewController & JetpackConnectionSupport

extension UIViewController {
    static func jetpackConnection(blog: Blog) -> ConnectJetpackViewController {
        // `RESTAPIJetpackLoginViewController` use REST API to connect sites to Jetpack, which provides a much better
        // UX than `JetpackLoginViewController` which connects sites via web-views.
        return RESTAPIJetpackLoginViewController(blog: blog) ?? JetpackLoginViewController(blog: blog)
    }
}

extension JetpackLoginViewController: JetpackConnectionSupport {
    func refreshUI() {
        updateMessageAndButton()
    }
}

/// A view controller that presents a Jetpack login form.
///
public class JetpackLoginViewController: UIViewController {

    // MARK: - Constants

    var blog: Blog

    // This variable is used to prevent signing into another WP.com account, if the site is not connected to the already signed-in default account.
    private var shouldDisableLogin: Bool {
        guard let defaultAccount = try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext) else {
            return false
        }
        return defaultAccount.email != blog.jetpack?.connectedEmail
    }

    // MARK: - Properties

    // Defaulting to stats because since that one is written in ObcC we don't have access to the enum there.
    var promptType: JetpackLoginPromptType = .stats

    public typealias CompletionBlock = () -> Void
    /// This completion handler closure is executed when the authentication process handled
    /// by this VC is completed.
    ///
    @objc open var completionBlock: CompletionBlock?

    @IBOutlet fileprivate weak var jetpackImage: UIImageView!
    @IBOutlet fileprivate weak var descriptionLabel: UILabel!
    @IBOutlet fileprivate weak var signinButton: WPNUXMainButton!
    @IBOutlet fileprivate weak var connectUserButton: NUXButton!
    @IBOutlet fileprivate weak var installJetpackButton: WPNUXMainButton!
    @IBOutlet private var tacButton: UIButton!
    @IBOutlet private var faqButton: UIButton!

    // MARK: - Initializers

    /// Required initializer for JetpackLoginViewController
    ///
    /// - Parameter blog: The current blog
    ///
    @objc public required init(blog: Blog) {
        self.blog = blog
        super.init(nibName: "JetpackLoginViewController", bundle: .keystone)
    }

    public required init?(coder aDecoder: NSCoder) {
        preconditionFailure("Jetpack Login View Controller must be initialized by code")
    }

    // MARK: - LifeCycle Methods

    public override func viewDidLoad() {
        super.viewDidLoad()
        WPStyleGuide.configureColors(view: view, tableView: nil)
        setupControls()
    }

    public override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        toggleHidingImageView(for: newCollection)
    }

    // MARK: - Configuration

    /// One time setup of the form textfields and buttons
    ///
    fileprivate func setupControls() {
        jetpackImage.image = promptType.image
        toggleHidingImageView(for: traitCollection)

        descriptionLabel.font = WPStyleGuide.fontForTextStyle(.body)
        descriptionLabel.textColor = .label

        tacButton.titleLabel?.numberOfLines = 0

        faqButton.titleLabel?.font = WPStyleGuide.fontForTextStyle(.subheadline, fontWeight: .medium)
        faqButton.setTitleColor(UIAppColor.primary, for: .normal)

        updateMessageAndButton()
    }

    private func toggleHidingImageView(for collection: UITraitCollection) {
        jetpackImage.isHidden = collection.containsTraits(in: UITraitCollection(verticalSizeClass: .compact))
    }

    // MARK: - UI Helpers

    func updateMessageAndButton() {
        guard let jetpack = blog.jetpack else {
            return
        }

        var message: String

        if jetpack.isSiteConnection {
            message = promptType.connectMessage
        } else if jetpack.isConnected {
            if let connectedEmail = jetpack.connectedEmail, shouldDisableLogin {
                message = Constants.Jetpack.connectToDefaultAccount(connectedEmail: connectedEmail)
            } else {
                message = jetpack.isUpdatedToRequiredVersion ? Constants.Jetpack.isUpdated : Constants.Jetpack.updateRequired
            }
        } else {
            message = promptType.installMessage
        }

        descriptionLabel.text = message
        descriptionLabel.sizeToFit()

        installJetpackButton.setTitle(Constants.Buttons.jetpackInstallTitle, for: .normal)
        installJetpackButton.isHidden = blog.hasJetpack
        installJetpackButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)

        connectUserButton.setTitle(Constants.Buttons.connectUserTitle, for: .normal)
        connectUserButton.isHidden = !(blog.hasJetpack && jetpack.isSiteConnection)
        connectUserButton.titleLabel?.numberOfLines = 2
        connectUserButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)

        signinButton.setTitle(Constants.Buttons.loginTitle, for: .normal)
        signinButton.isHidden = shouldDisableLogin || !(blog.hasJetpack && !jetpack.isSiteConnection)

        let paragraph = NSMutableParagraphStyle(minLineHeight: WPStyleGuide.fontSizeForTextStyle(.footnote),
                                                lineBreakMode: .byWordWrapping,
                                                alignment: .center)
        let attributes: [NSAttributedString.Key: Any] = [.font: WPStyleGuide.fontForTextStyle(.footnote),
                                                         .foregroundColor: UIColor.secondaryLabel,
                                                         .paragraphStyle: paragraph]
        let attributedTitle = NSMutableAttributedString(string: Constants.Buttons.termsAndConditionsTitle,
                                                        attributes: attributes)
        attributedTitle.applyStylesToMatchesWithPattern(Constants.Buttons.termsAndConditions,
                                                        styles: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        tacButton.setAttributedTitle(attributedTitle, for: .normal)
        tacButton.isHidden = installJetpackButton.isHidden

        faqButton.setTitle(Constants.Buttons.faqTitle, for: .normal)
        faqButton.isHidden = tacButton.isHidden
    }

    // MARK: - Browser

    fileprivate func openInstallJetpackURL() {
        trackStat(.selectedInstallJetpack)
        let controller = JetpackConnectionWebViewController(blog: blog)
        controller.delegate = self
        let navController = UINavigationController(rootViewController: controller)
        present(navController, animated: true)
    }

    fileprivate func signIn() {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let email = self.blog.jetpack?.connectedEmail
            let accountID = await WordPressDotComAuthenticator().signIn(from: self, context: .jetpackSite(accountEmail: email))
            if accountID != nil {
                self.completionBlock?()
            }
        }
    }

    fileprivate func trackStat(_ stat: WPAnalyticsStat, blog: Blog? = nil) {
        var properties = [String: String]()
        switch promptType {
        case .stats:
            properties["source"] = "stats"
        case .notifications:
            properties["source"] = "notifications"
        }

        if let blog {
            WPAppAnalytics.track(stat, properties: properties, blog: blog)
        } else {
            WPAnalytics.track(stat, withProperties: properties)
        }
    }

    private func openWebView(for webviewType: JetpackWebviewType) {
        guard let url = webviewType.url else {
            return
        }

        let webviewViewController = WebViewControllerFactory.controller(url: url, source: "jetpack_login")
        let navigationViewController = UINavigationController(rootViewController: webviewViewController)
        present(navigationViewController, animated: true, completion: nil)
    }

    private func jetpackIsCanceled() {
        trackStat(.installJetpackCanceled)
        dismiss(animated: true, completion: completionBlock)
    }

    private func jetpackIsCompleted() {
        trackStat(.installJetpackCompleted)
        trackStat(.signedInToJetpack, blog: blog)
        dismiss(animated: true, completion: completionBlock)
    }

    private func openJetpackRemoteInstall() {
        trackStat(.selectedInstallJetpack)
        let controller = JetpackRemoteInstallViewController(blog: blog, delegate: self)
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }

    // MARK: - Actions

    @IBAction func didTouchSignInButton(_ sender: Any) {
        signIn()
    }

    @IBAction func didTouchInstallJetpackButton(_ sender: Any) {
        openJetpackRemoteInstall()
    }

    @IBAction func didTouchConnectUserAccountButton(_ sender: Any) {
        openInstallJetpackURL()
    }

    @IBAction func didTouchTacButton(_ sender: Any) {
        openWebView(for: .tac)
    }

    @IBAction func didTouchFaqButton(_ sender: Any) {
        openWebView(for: .faq)
    }
}

extension JetpackLoginViewController: JetpackConnectionWebDelegate {
    func jetpackConnectionCompleted() {
        jetpackIsCompleted()
    }

    func jetpackConnectionCanceled() {
        jetpackIsCanceled()
    }
}

extension JetpackLoginViewController: JetpackRemoteInstallDelegate {
    func jetpackRemoteInstallCanceled() {
        jetpackIsCanceled()
    }

    func jetpackRemoteInstallCompleted() {
        jetpackIsCompleted()
    }

    func jetpackRemoteInstallWebviewFallback() {
        trackStat(.installJetpackRemoteStartManualFlow)
        dismiss(animated: true) { [weak self] in
            self?.openInstallJetpackURL()
        }
    }
}

public enum JetpackLoginPromptType {
    case stats
    case notifications

    var image: UIImage? {
        switch self {
        case .stats:
            return UIImage(named: "wp-illustration-stats")
        case .notifications:
            return UIImage(named: "wp-illustration-notifications")
        }
    }

    var imageName: String {
        switch self {
        case .stats:
            return "wp-illustration-stats"
        case .notifications:
            return "wp-illustration-notifications"
        }
    }

    var installMessage: String {
        switch self {
        case .stats:
            return NSLocalizedString("To use stats on your site, you'll need to install the Jetpack plugin.",
                                        comment: "Message asking the user if they want to set up Jetpack from stats")
        case .notifications:
            return NSLocalizedString("To get helpful notifications on your phone from your WordPress site, you'll need to install the Jetpack plugin.",
                                        comment: "Message asking the user if they want to set up Jetpack from notifications")
        }
    }

    var connectMessage: String {
        switch self {
        case .stats:
            return NSLocalizedString("jetpack.install.connectUser.stats.description",
                                     value: "To use stats on your site, you'll need to connect the Jetpack plugin to your user account.",
                                     comment: "Message asking the user if they want to set up Jetpack from stats by connecting their user account")
        case .notifications:
            return NSLocalizedString("jetpack.install.connectUser.notifications.description",
                                     value: "To get helpful notifications on your phone from your WordPress site, you'll need to connect to your user account.",
                                     comment: "Message asking the user if they want to set up Jetpack from notifications")
        }
    }
}

private enum JetpackWebviewType {
    case tac
    case faq

    var url: URL? {
        switch self {
        case .tac:
            return URL(string: "https://en.wordpress.com/tos/")
        case .faq:
            return URL(string: "https://wordpress.org/plugins/jetpack/#faq")
        }
    }
}

private enum Constants {
    enum Buttons {
        static let termsAndConditions = NSLocalizedString("Terms and Conditions", comment: "The underlined title sentence")
        static let termsAndConditionsTitle = String.localizedStringWithFormat(NSLocalizedString("By setting up Jetpack you agree to our\n%@",
                                                                                                comment: "Title of the button which opens the Jetpack terms and conditions page. The sentence is composed by 2 lines separated by a line break \n. Also there is a placeholder %@ which is: Terms and Conditions"), termsAndConditions)
        static let faqTitle = NSLocalizedString("Jetpack FAQ", comment: "Title of the button which opens the Jetpack FAQ page.")
        static let jetpackInstallTitle = NSLocalizedString("Install Jetpack", comment: "Title of a button for Jetpack Installation.")
        static let loginTitle = NSLocalizedString("Log in", comment: "Title of a button for signing in.")
        static let connectUserTitle = NSLocalizedString("jetpack.install.connectUser.button.title", value: "Connect your user account", comment: "Title of a button for connecting user account to Jetpack.")
    }

    enum Jetpack {
        static let isUpdated = NSLocalizedString("Looks like you have Jetpack set up on your site. Congrats! " +
            "Log in with your WordPress.com credentials to enable " +
            "Stats and Notifications.",
                                                      comment: "Message asking the user to sign into Jetpack with WordPress.com credentials")
        static let updateRequired = String.localizedStringWithFormat(NSLocalizedString("Jetpack %@ or later is required. " +
            "Do you want to update Jetpack?",
                                                                                              comment: "Message stating the minimum required " +
                                                                                                "version for Jetpack and asks the user " +
            "if they want to upgrade"), JetpackState.minimumVersionRequired)
        static func connectToDefaultAccount(connectedEmail: String) -> String {
            String.localizedStringWithFormat(
                NSLocalizedString("jetpackSite.connectToDefaultAccount", value: "You need to sign in with %@ to use Stats and Notifications.", comment: "Message stating that the user is unable to use Stats and Notifications because their site is connected to a different WordPress.com account"),
                connectedEmail
            )
        }
    }
}
