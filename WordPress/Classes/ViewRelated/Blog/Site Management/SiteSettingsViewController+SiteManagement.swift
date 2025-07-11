import UIKit
import SVProgressHUD
import WordPressData
import WordPressShared

/// Implements site management services triggered from SiteSettingsViewController
///
public extension SiteSettingsViewController {

    /// Presents confirmation alert for Export Content
    ///
    @objc func confirmExportContent() {
        tableView.deselectSelectedRowWithAnimation(true)

        WPAppAnalytics.track(.siteSettingsExportSiteAccessed, blog: self.blog)
        present(confirmExportController(), animated: true)
    }

    /// Creates confirmation alert for Export Content
    ///
    /// - Returns: UIAlertController
    ///
    fileprivate func confirmExportController() -> UIAlertController {
        let confirmTitle = NSLocalizedString("Export Your Content", comment: "Title of Export Content confirmation alert")
        let message: String
        if let email = blog.account?.email {
            let messageFormat = NSLocalizedString("Your posts, pages, and settings will be mailed to you at %@.", comment: "Message of Export Content confirmation alert; substitution is user's email address")
            message = String(format: messageFormat, email)
        } else {
            message = NSLocalizedString("Your posts, pages, and settings will be mailed to the account's email address.", comment: "Message of Export Content confirmation alert")
        }
        let alertController = UIAlertController(title: confirmTitle, message: message, preferredStyle: .alert)

        let cancelTitle = NSLocalizedString("Cancel", comment: "Alert dismissal title")
        alertController.addCancelActionWithTitle(cancelTitle, handler: nil)

        let exportTitle = NSLocalizedString("Export Content", comment: "Export Content confirmation action title")
        alertController.addDefaultActionWithTitle(exportTitle, handler: { _ in
            self.exportContent()
        })

        return alertController
    }

    /// Handles triggering content export to XML file via API
    ///
    /// - Note: Email is sent on completion
    ///
    fileprivate func exportContent() {
        let status = NSLocalizedString("Exporting content…", comment: "Overlay message displayed while starting content export")
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.show(withStatus: status)

        let trackedBlog = blog
        WPAppAnalytics.track(.siteSettingsExportSiteRequested, blog: trackedBlog)

        let service = SiteManagementService(coreDataStack: ContextManager.shared)
        service.exportContentForBlog(blog, success: {
            WPAppAnalytics.track(.siteSettingsExportSiteResponseOK, blog: trackedBlog)

            let status = NSLocalizedString("Email sent!", comment: "Overlay message displayed when export content started")
            SVProgressHUD.showDismissibleSuccess(status: status)
        }, failure: { error in
            DDLogError("Error exporting content: \(error.localizedDescription)")
            WPAppAnalytics.track(.siteSettingsExportSiteResponseError, blog: trackedBlog)

            SVProgressHUD.dismiss()

            let errorTitle = NSLocalizedString("Export Content Error", comment: "Title of alert when export content fails")
            let alertController = UIAlertController(title: errorTitle, message: error.localizedDescription, preferredStyle: .alert)

            let okTitle = SharedStrings.Button.ok
            _ = alertController.addDefaultActionWithTitle(okTitle, handler: nil)

            alertController.presentFromRootViewController()
        })
    }

    /// Requests site purchases to determine whether site is deletable
    ///
    @objc func checkSiteDeletable() {
        tableView.deselectSelectedRowWithAnimation(true)

        let status = NSLocalizedString("Checking purchases…", comment: "Overlay message displayed while checking if site has premium purchases")
        SVProgressHUD.show(withStatus: status)

        WPAppAnalytics.track(.siteSettingsDeleteSitePurchasesRequested, blog: blog)
        let service = SiteManagementService(coreDataStack: ContextManager.shared)
        service.getActivePurchasesForBlog(blog,
            success: { [weak self] purchases in
                SVProgressHUD.dismiss()
                guard let strongSelf = self else {
                    return
                }

                if purchases.isEmpty {
                    WPAppAnalytics.track(.siteSettingsDeleteSiteAccessed, blog: strongSelf.blog)
                    strongSelf.navigationController?.pushViewController(DeleteSiteViewController.controller(strongSelf.blog), animated: true)
                } else {
                    WPAppAnalytics.track(.siteSettingsDeleteSitePurchasesShown, blog: strongSelf.blog)
                    strongSelf.present(strongSelf.warnPurchasesController(), animated: true)
                }
            },
            failure: { error in
                DDLogError("Error getting purchases: \(error.localizedDescription)")
                SVProgressHUD.dismiss()

                let errorTitle = NSLocalizedString("Check Purchases Error", comment: "Title of alert when getting purchases fails")
                let alertController = UIAlertController(title: errorTitle, message: error.localizedDescription, preferredStyle: .alert)

                let okTitle = SharedStrings.Button.ok
                alertController.addDefaultActionWithTitle(okTitle, handler: nil)

                alertController.presentFromRootViewController()
            })
    }

    /// Creates purchase warning alert for Delete Site
    ///
    /// - Returns: UIAlertController
    ///
    fileprivate func warnPurchasesController() -> UIAlertController {
        let warnTitle = NSLocalizedString("Premium Upgrades", comment: "Title of alert when attempting to delete site with purchases")
        let message = NSLocalizedString("You have active premium upgrades on your site. Please cancel your upgrades prior to deleting your site.", comment: "Message alert when attempting to delete site with purchases")
        let alertController = UIAlertController(title: warnTitle, message: message, preferredStyle: .alert)

        let cancelTitle = NSLocalizedString("Cancel", comment: "Alert dismissal title")
        alertController.addCancelActionWithTitle(cancelTitle, handler: nil)

        let showTitle = NSLocalizedString("Show Purchases", comment: "Show site purchases action title")
        alertController.addDefaultActionWithTitle(showTitle, handler: { _ in
            WPAppAnalytics.track(.siteSettingsDeleteSitePurchasesShowClicked, blog: self.blog)
            self.showPurchases()
        })

        return alertController
    }

    /// Brings up web interface showing site purchases for cancellation
    ///
    fileprivate func showPurchases() {
        let url = URL(string: "https://wordpress.com/purchases")!

        let configuration = WebViewControllerConfiguration(url: url)
        configuration.secureInteraction = true
        configuration.authenticate(blog: blog)
        let controller = WebViewControllerFactory.controller(configuration: configuration, source: "site_settings_show_purchases")
        controller.loadViewIfNeeded()
        controller.navigationItem.titleView = nil
        controller.title = NSLocalizedString("Purchases", comment: "Title of screen showing site purchases")

        navigationController?.pushViewController(controller, animated: true)
    }
}
