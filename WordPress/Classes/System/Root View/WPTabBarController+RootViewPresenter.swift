import UIKit
import WordPressData
import WordPressShared

/// `WPTabBarController` is used as the root presenter when Jetpack features are enabled
/// and the app's UI is normal.
extension WPTabBarController: RootViewPresenter {

    // MARK: General

    var rootViewController: UIViewController {
        return self
    }

    func showBlogDetails(for blog: Blog, then subsection: BlogDetailsSubsection?, userInfo: [AnyHashable: Any]) {
        mySitesCoordinator.showBlogDetails(for: blog, then: subsection, userInfo: userInfo)
    }

    func currentlyVisibleBlog() -> Blog? {
        guard selectedIndex == WPTab.mySites.rawValue else {
            return nil
        }
        return mySitesCoordinator.currentBlog
    }

    func showNotificationsTab(completion: ((NotificationsViewController) -> Void)?) {
        // UITabBarController.selectedIndex must be used from main thread only.
        wpAssert(Thread.isMainThread)

        selectedIndex = WPTab.notifications.rawValue
        completion?(notificationsViewController!)
    }

    // MARK: Me

    func showMeScreen(completion: ((MeViewController) -> Void)?) {
        showMeTab()
        meNavigationController.popToRootViewController(animated: false)
        completion?(meViewController)
    }
}
