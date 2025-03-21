import WordPressShared

// MARK: - Push Notification Primer
//
extension NotificationsViewController {
    private struct Analytics {
        static let locationKey = "location"
        static let inlineKey = "inline"
    }

    var shouldShowPrimeForPush: Bool {
        get {
            return !UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged
        }
    }

    func setupNotificationPrompt() {
        PushNotificationsManager.shared.loadAuthorizationStatus { [weak self] (status) in
            switch status {
            case .notDetermined:
                self?.setupPrimeForPush()
            case .denied:
                self?.setupWinback()
            default:
                // The user has already allowed notifications so we set the inline prompt to acknowledged so it isn't called anymore
                UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
                break
            }
        }
    }

    private func setupPrimeForPush() {
        defer {
            WPAnalytics.track(.pushNotificationPrimerSeen, withProperties: [Analytics.locationKey: Analytics.inlineKey])
        }

        inlinePromptView.setupHeading(NSLocalizedString("We'll notify you when you get followers, comments, and likes.",
                                                        comment: "This is the string we display when asking the user to approve push notifications"))
        let yesTitle = NSLocalizedString("Allow notifications",
                                         comment: "Button label for approving our request to allow push notifications")
        let noTitle = NSLocalizedString("Not now",
                                        comment: "Button label for denying our request to allow push notifications")

        inlinePromptView.setupYesButton(title: yesTitle) { [weak self] button in
            defer {
                WPAnalytics.track(.pushNotificationPrimerAllowTapped, withProperties: [Analytics.locationKey: Analytics.inlineKey])
            }
            InteractiveNotificationsManager.shared.requestAuthorization { _ in
                DispatchQueue.main.async {
                    self?.hideInlinePrompt(delay: 0.0)
                    UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
                }
            }
        }

        inlinePromptView.setupNoButton(title: noTitle) { [weak self] button in
            defer {
                WPAnalytics.track(.pushNotificationPrimerNoTapped, withProperties: [Analytics.locationKey: Analytics.inlineKey])
            }
            self?.hideInlinePrompt(delay: 0.0)
            UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
        }

        // We _seriously_ need to call the following method at last.
        // Why I: Because you must first set the Heading (at least), so that the InlinePrompt's height can be properly calculated.
        // Why II: UITableView's Header inability to deal with Autolayout was never, ever addressed by AAPL.
        showInlinePrompt()
    }

    private func setupWinback() {
        // only show the winback for folks that denied without seeing the post-login primer: aka users of a previous version
        guard !UserPersistentStoreFactory.instance().notificationPrimerAlertWasDisplayed else {
            // they saw the primer, and denied us. they aren't coming back, we aren't bothering them anymore.
            UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
            return
        }

        defer {
            WPAnalytics.track(.pushNotificationWinbackShown, withProperties: [Analytics.locationKey: Analytics.inlineKey])
        }

        showInlinePrompt()

        inlinePromptView.setupHeading(NSLocalizedString("Push notifications have been turned off in iOS settings. Toggle “Allow Notifications” to turn them back on.",
                                                        comment: "This is the string we display when asking the user to approve push notifications in the settings app after previously having denied them."))
        let yesTitle = NSLocalizedString("Go to iOS Settings",
                                         comment: "Button label for going to settings to approve push notifications")
        let noTitle = NSLocalizedString("No thanks",
                                        comment: "Button label for denying our request to re-allow push notifications")

        inlinePromptView.setupYesButton(title: yesTitle) { [weak self] button in
            defer {
                WPAnalytics.track(.pushNotificationWinbackSettingsTapped, withProperties: [Analytics.locationKey: Analytics.inlineKey])
            }
            self?.hideInlinePrompt(delay: 0.0)
            let targetURL = URL(string: UIApplication.openSettingsURLString)
            UIApplication.shared.open(targetURL!)
            UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
        }

        inlinePromptView.setupNoButton(title: noTitle) { [weak self] button in
            defer {
                WPAnalytics.track(.pushNotificationWinbackNoTapped, withProperties: [Analytics.locationKey: Analytics.inlineKey])
            }
            self?.hideInlinePrompt(delay: 0.0)
            UserPersistentStoreFactory.instance().notificationPrimerInlineWasAcknowledged = true
        }
    }
}
