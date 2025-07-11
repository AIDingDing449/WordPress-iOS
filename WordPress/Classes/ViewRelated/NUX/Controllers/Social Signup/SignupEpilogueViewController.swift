import UIKit
import SVProgressHUD
import WordPressAuthenticator
import WordPressData
import WordPressShared

class SignupEpilogueViewController: UIViewController {

    // MARK: - Analytics Tracking

    let tracker = AuthenticatorAnalyticsTracker.shared

    // MARK: - Public Properties

    var credentials: AuthenticatorCredentials?
    var socialUser: SocialUser?

    /// Closure to be executed upon tapping the continue button.
    ///
    var onContinue: (() -> Void)?

    // MARK: - Outlets

    @IBOutlet var doneButton: UIButton!

    // MARK: - Private Properties

    private var updatedDisplayName: String?
    private var updatedPassword: String?
    private var updatedUsername: String?
    private var epilogueUserInfo: LoginEpilogueUserInfo?
    private var displayNameAutoGenerated: Bool = false
    private var changesMade = false

    /// Constraints on the table view container.
    /// Used to adjust the width on iPad.
    @IBOutlet var tableViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet var tableViewTrailingConstraint: NSLayoutConstraint!
    private var defaultTableViewMargin: CGFloat = 0

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        defaultTableViewMargin = tableViewLeadingConstraint.constant
        configureDoneButton()
        setTableViewMargins()

        WordPressAuthenticator.track(.signupEpilogueViewed, properties: tracksProperties())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setTableViewMargins()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setTableViewMargins()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.isPad() ? .all : .portrait
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? SignupEpilogueTableViewController {
            vc.credentials = credentials
            vc.socialUser = socialUser
            vc.dataSource = self
            vc.delegate = self
        }

        if let vc = segue.destination as? SignupUsernameViewController {
            vc.currentUsername = updatedUsername ?? epilogueUserInfo?.username
            vc.displayName = updatedDisplayName ?? epilogueUserInfo?.fullName
            vc.delegate = self

            // Empty Back Button
            navigationItem.backBarButtonItem = UIBarButtonItem(title: String(), style: .plain, target: nil, action: nil)
        }
    }

}

// MARK: - SignupEpilogueTableViewControllerDataSource

extension SignupEpilogueViewController: SignupEpilogueTableViewControllerDataSource {
    var customDisplayName: String? {
        return updatedDisplayName
    }

    var password: String? {
        return updatedPassword
    }

    var username: String? {
        return updatedUsername
    }
}

// MARK: - SignupEpilogueTableViewControllerDelegate

extension SignupEpilogueViewController: SignupEpilogueTableViewControllerDelegate {

    func displayNameUpdated(newDisplayName: String) {
        updatedDisplayName = newDisplayName
        displayNameAutoGenerated = false
    }

    func displayNameAutoGenerated(newDisplayName: String) {
        updatedDisplayName = newDisplayName
        displayNameAutoGenerated = true
    }

    func passwordUpdated(newPassword: String) {
        updatedPassword = newPassword.isEmpty ? nil : newPassword
    }

    func usernameTapped(userInfo: LoginEpilogueUserInfo?) {
        epilogueUserInfo = userInfo
        performSegue(withIdentifier: SignupUsernameViewController.classNameWithoutNamespaces(), sender: self)

        tracker.track(click: .editUsername, ifTrackingNotEnabled: {
            WordPressAuthenticator.track(.signupEpilogueUsernameTapped, properties: self.tracksProperties())
        })
    }
}

// MARK: - Private Extension

private extension SignupEpilogueViewController {

    func configureDoneButton() {
        doneButton.setTitle(ButtonTitle.title, for: .normal)
        doneButton.accessibilityIdentifier = ButtonTitle.accessibilityId
    }

    func setTableViewMargins() {
        tableViewLeadingConstraint.constant = view.getHorizontalMargin(compactMargin: defaultTableViewMargin)
        tableViewTrailingConstraint.constant = view.getHorizontalMargin(compactMargin: defaultTableViewMargin)
    }

    @IBAction func doneButtonPressed() {
        saveChanges()
    }

    func saveChanges() {
        if let newUsername = updatedUsername {
            SVProgressHUD.show(withStatus: HUDMessages.changingUsername)
            changeUsername(to: newUsername) {
                self.updatedUsername = nil
                self.saveChanges()
            }
        } else if let newDisplayName = updatedDisplayName {
            // If the display name is not auto generated, then the user changed it.
            // So we need to show the HUD to the user.
            if !displayNameAutoGenerated {
                SVProgressHUD.show(withStatus: HUDMessages.changingDisplayName)
            }
            changeDisplayName(to: newDisplayName) {
                self.updatedDisplayName = nil
                self.saveChanges()
            }
        } else if let newPassword = updatedPassword, !newPassword.isEmpty {
            SVProgressHUD.show(withStatus: HUDMessages.changingPassword)
            changePassword(to: newPassword) { success, error in
                if success {
                    self.updatedPassword = nil
                    self.saveChanges()
                } else {
                    self.showPasswordError(error)
                }
            }
        } else {
            if !changesMade {
                WordPressAuthenticator.track(.signupEpilogueUnchanged, properties: tracksProperties())
            }
            self.refreshAccountDetails() {
                SVProgressHUD.dismiss()
                self.dismissEpilogue()
            }
        }
        changesMade = true
    }

    func changeUsername(to newUsername: String, finished: @escaping (() -> Void)) {
        guard newUsername != "" else {
            finished()
            return
        }

        let context = ContextManager.shared.mainContext

        guard
            let account = try? WPAccount.lookupDefaultWordPressComAccount(in: context),
            let userID = account.userID,
            let api = account.wordPressComRestApi
        else {
            navigationController?.popViewController(animated: true)
            return
        }

        let settingsService = AccountSettingsService(userID: userID.intValue, api: api)
        settingsService.changeUsername(to: newUsername, success: {
            WordPressAuthenticator.track(.signupEpilogueUsernameUpdateSucceeded, properties: self.tracksProperties())

            finished()
        }) {
            WordPressAuthenticator.track(.signupEpilogueUsernameUpdateFailed, properties: self.tracksProperties())

            finished()
        }
    }

    func changeDisplayName(to newDisplayName: String, finished: @escaping (() -> Void)) {
        let context = ContextManager.shared.mainContext
        guard let defaultAccount = try? WPAccount.lookupDefaultWordPressComAccount(in: context),
              let userID = defaultAccount.userID,
              let restApi = defaultAccount.wordPressComRestApi
        else {
            finished()
            return
        }

        let accountSettingService = AccountSettingsService(userID: userID.intValue, api: restApi)

        accountSettingService.updateDisplayName(newDisplayName) { (success, _) in
            let event: WPAnalyticsStat = success ? .signupEpilogueDisplayNameUpdateSucceeded : .signupEpilogueDisplayNameUpdateFailed
            WordPressAuthenticator.track(event, properties: self.tracksProperties())

            finished()
        }
    }

    func changePassword(to newPassword: String, finished: @escaping (_ success: Bool, _ error: Error?) -> Void) {

        let context = ContextManager.shared.mainContext

        do {
            let defaultAccount = try WPAccount.lookupDefaultWordPressComAccount(in: context)

            guard
                let account = defaultAccount,
                let userID = account.userID,
                let restApi = account.wordPressComRestApi
            else {
                finished(false, nil)
                return
            }

            let accountSettingService = AccountSettingsService(userID: userID.intValue, api: restApi)

            accountSettingService.updatePassword(newPassword) { success, error in
                if success {
                    WordPressAuthenticator.track(.signupEpiloguePasswordUpdateSucceeded, properties: self.tracksProperties())
                } else {
                    WordPressAuthenticator.track(.signupEpiloguePasswordUpdateFailed, properties: self.tracksProperties())
                }

                finished(success, error)
            }

        } catch let err {
            finished(false, err)
            return
        }
    }

    func dismissEpilogue() {
        tracker.track(click: .continue)

        guard let onContinue = self.onContinue else {
            self.navigationController?.dismiss(animated: true)
            return
        }

        onContinue()
    }

    func refreshAccountDetails(finished: @escaping () -> Void) {
        let context = ContextManager.shared.mainContext

        guard let account = try? WPAccount.lookupDefaultWordPressComAccount(in: context) else {
            self.dismissEpilogue()
            return
        }
        AccountService(coreDataStack: ContextManager.shared).updateUserDetails(for: account, success: { () in
            finished()
        }, failure: { _ in
            finished()
        })
    }

    func showPasswordError(_ error: Error? = nil) {
        let errorMessage = error?.localizedDescription ?? HUDMessages.changePasswordGenericError
        SVProgressHUD.showError(withStatus: errorMessage)
    }

    func tracksProperties() -> [AnyHashable: Any] {
        let source: String = {
            guard let socialUser else {
                return "email"
            }

            switch socialUser.service {
            case .google:
                return "google"
            case .apple:
                return "apple"
            }
        }()

        return ["source": source]
    }

    enum ButtonTitle {
        static let title = NSLocalizedString("Done", comment: "Button text on site creation epilogue page to proceed to My Sites.")
        // TODO: change UI Test when change this
        static let accessibilityId = "Done Button"
    }

    enum HUDMessages {
        static let changingDisplayName = NSLocalizedString("Changing display name", comment: "Shown while the app waits for the display name changing web service to return.")
        static let changingUsername = NSLocalizedString("Changing username", comment: "Shown while the app waits for the username changing web service to return.")
        static let changingPassword = NSLocalizedString("Changing password", comment: "Shown while the app waits for the password changing web service to return.")
        static let changePasswordGenericError = NSLocalizedString("There was an error changing the password", comment: "Text displayed when there is a failure changing the password.")
    }

}

extension SignupEpilogueViewController: SignupUsernameViewControllerDelegate {
    func usernameSelected(_ username: String) {
        if username.isEmpty || username == epilogueUserInfo?.username {
            updatedUsername = nil
        } else {
            updatedUsername = username
        }
    }
}
