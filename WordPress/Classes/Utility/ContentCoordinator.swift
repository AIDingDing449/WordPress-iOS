import UIKit
import WordPressShared
import WordPressData

protocol ContentCoordinator {
    func displayReaderWithPostId(_ postID: NSNumber?, siteID: NSNumber?) throws
    func displayCommentsWithPostId(_ postID: NSNumber?, siteID: NSNumber?, commentID: NSNumber?, source: ReaderCommentsSource) throws
    func displayStatsWithSiteID(_ siteID: NSNumber?, url: URL?) throws
    func displayFollowersWithSiteID(_ siteID: NSNumber?, expirationTime: TimeInterval) throws
    func displayStreamWithSiteID(_ siteID: NSNumber?) throws
    func displayWebViewWithURL(_ url: URL, source: String)
    func displayFullscreenImage(_ image: UIImage)
    func displayPlugin(withSlug pluginSlug: String, on siteSlug: String) throws
    func displayBackupWithSiteID(_ siteID: NSNumber?) throws
    func displayScanWithSiteID(_ siteID: NSNumber?) throws
}

/// `ContentCoordinator` is intended to be used to easily navigate and display common elements natively
/// like Posts, Site streams, Comments, etc...
///
struct DefaultContentCoordinator: ContentCoordinator {
    enum DisplayError: Error {
        case missingParameter
        case unsupportedType
    }

    private let mainContext: NSManagedObjectContext
    private weak var controller: UIViewController?

    init(controller: UIViewController, context: NSManagedObjectContext) {
        self.controller = controller
        mainContext = context
    }

    func displayReaderWithPostId(_ postID: NSNumber?, siteID: NSNumber?) throws {
        guard let postID, let siteID else {
            throw DisplayError.missingParameter
        }

        let readerViewController = ReaderDetailViewController.controllerWithPostID(postID, siteID: siteID)
        controller?.navigationController?.pushViewController(readerViewController, animated: true)
    }

    func displayCommentsWithPostId(_ postID: NSNumber?, siteID: NSNumber?, commentID: NSNumber?, source: ReaderCommentsSource) throws {
        guard let postID, let siteID else {
            throw DisplayError.missingParameter
        }
        let commentVC = ReaderCommentsViewController(postID: postID, siteID: siteID)
        commentVC.source = source
        commentVC.navigateToCommentID = commentID
        commentVC.allowsPushingPostDetails = true
        controller?.navigationController?.pushViewController(commentVC, animated: true)
    }

    func displayStatsWithSiteID(_ siteID: NSNumber?, url: URL? = nil) throws {
        guard let siteID,
              let blog = Blog.lookup(withID: siteID, in: mainContext),
              blog.supports(.stats)
        else {
            throw DisplayError.missingParameter
        }

        // Stats URLs should be of the form /stats/:time_period/:domain
        if let url {
            setTimePeriodForStatsURLIfPossible(url)
        }

        let statsViewController = StatsViewController()
        statsViewController.blog = blog
        controller?.navigationController?.pushViewController(statsViewController, animated: true)
    }

    private func setTimePeriodForStatsURLIfPossible(_ url: URL) {
        guard let siteID = SiteStatsInformation.sharedInstance.siteID?.intValue else {
            return
        }

        let matcher = RouteMatcher(routes: UniversalLinkRouter.statsRoutes)
        let matches = matcher.routesMatching(url)
        if let match = matches.first,
           let action = match.action as? StatsRoute,
           let tab = action.tab {
            SiteStatsDashboardPreferences.setSelected(tabType: tab, siteID: siteID)
        }
    }

    func displayBackupWithSiteID(_ siteID: NSNumber?) throws {
        guard let siteID,
              let blog = Blog.lookup(withID: siteID, in: mainContext)
        else {
            throw DisplayError.missingParameter
        }

        let backupViewController = BackupsViewController(blog: blog)
        backupViewController.navigationItem.largeTitleDisplayMode = .never
        controller?.navigationController?.pushViewController(backupViewController, animated: true)

        WPAnalytics.track(.backupListOpened)
    }

    func displayScanWithSiteID(_ siteID: NSNumber?) throws {
        guard let siteID,
              let blog = Blog.lookup(withID: siteID, in: mainContext),
              blog.isScanAllowed()
        else {
            throw DisplayError.missingParameter
        }

        let scanViewController = JetpackScanViewController.withJPBannerForBlog(blog)
        controller?.navigationController?.pushViewController(scanViewController, animated: true)
    }

    func displayFollowersWithSiteID(_ siteID: NSNumber?, expirationTime: TimeInterval) throws {
        guard let siteID,
              let blog = Blog.lookup(withID: siteID, in: mainContext)
        else {
            throw DisplayError.missingParameter
        }

        SiteStatsInformation.sharedInstance.siteTimeZone = blog.timeZone
        SiteStatsInformation.sharedInstance.oauth2Token = blog.authToken
        SiteStatsInformation.sharedInstance.siteID = blog.dotComID

        let detailTableViewController = SiteStatsDetailTableViewController.loadFromStoryboard()
        detailTableViewController.configure(statSection: StatSection.insightsFollowersWordPress)
        controller?.navigationController?.pushViewController(detailTableViewController, animated: true)
    }

    func displayStreamWithSiteID(_ siteID: NSNumber?) throws {
        guard let siteID else {
            throw DisplayError.missingParameter
        }

        let browseViewController = ReaderStreamViewController.controllerWithSiteID(siteID, isFeed: false)
        controller?.navigationController?.pushViewController(browseViewController, animated: true)
    }

    func displayWebViewWithURL(_ url: URL, source: String) {
        if UniversalLinkRouter(routes: UniversalLinkRouter.readerRoutes).canHandle(url: url) {
            UniversalLinkRouter(routes: UniversalLinkRouter.readerRoutes).handle(url: url, source: .inApp(presenter: controller))
            return
        }

        let webViewController = WebViewControllerFactory.controllerAuthenticatedWithDefaultAccount(url: url, source: source)
        let navController = UINavigationController(rootViewController: webViewController)
        controller?.present(navController, animated: true)
    }

    func displayFullscreenImage(_ image: UIImage) {
        let lightboxVC = LightboxViewController(.image(image))
        lightboxVC.configureZoomTransition()
        controller?.present(lightboxVC, animated: true)
    }

    func displayPlugin(withSlug pluginSlug: String, on siteSlug: String) throws {
        guard let jetpack = jetpackSiteReff(with: siteSlug) else {
            throw DisplayError.missingParameter
        }
        let pluginVC = PluginViewController(slug: pluginSlug, site: jetpack)
        controller?.navigationController?.pushViewController(pluginVC, animated: true)
    }

    private func jetpackSiteReff(with slug: String) -> JetpackSiteRef? {
        guard let blog = Blog.lookup(hostname: slug, in: mainContext), let jetpack = JetpackSiteRef(blog: blog) else {
            return nil
        }
        return jetpack
    }
}
