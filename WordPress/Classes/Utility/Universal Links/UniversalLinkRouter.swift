import Foundation
import BuildSettingsKit
import WordPressShared

protocol LinkRouter {
    init(routes: [Route])
    func canHandle(url: URL) -> Bool
    func handle(url: URL, shouldTrack track: Bool, source: DeepLinkSource?)
}

/// UniversalLinkRouter keeps a list of possible URL routes that are exposed
/// via universal links, and handles incoming links to trigger the appropriate route.
///
struct UniversalLinkRouter: LinkRouter {
    private let matcher: RouteMatcher

    private static let extraLoggingEnabled = BuildConfiguration.current == .debug

    init(routes: [Route]) {
        matcher = RouteMatcher(routes: routes)
    }

    // A singleton is less than ideal, but we're currently using this from the
    // app delegate, and because it's primarily written in objective-c we can't
    // add a struct property there.
    //
    static let shared = UniversalLinkRouter(
        routes: defaultRoutes)

    // A singleton that handles universal link routes without requiring authentication.
    //
    static let unauthenticated = UniversalLinkRouter(routes: jetpackRoutes)

    static let defaultRoutes: [Route] =
        redirects +
        meRoutes +
        newPostRoutes +
        newPageRoutes +
        jetpackRoutes +
        notificationsRoutes +
        readerRoutes +
        statsRoutes +
        mySitesRoutes +
        appBannerRoutes

    static let meRoutes: [Route] = [
        MeRoute(),
        MeAccountSettingsRoute(),
        MeAllDomainsRoute(),
        MeNotificationSettingsRoute()
    ]

    static let jetpackRoutes: [Route] = [
        JetpackRoute()
    ]

    static let newPostRoutes: [Route] = [
        NewPostRoute(),
        NewPostForSiteRoute()
    ]

    static let newPageRoutes: [Route] = [
        NewPageRoute(),
        NewPageForSiteRoute()
    ]

    static let notificationsRoutes: [Route] = [
        NotificationsRoute()
    ]

    static let readerRoutes: [Route] = [
        ReaderRoute.root,
        ReaderRoute.discover,
        ReaderRoute.search,
        ReaderRoute.a8c,
        ReaderRoute.p2,
        ReaderRoute.likes,
        ReaderRoute.manageFollowing,
        ReaderRoute.list,
        ReaderRoute.tag,
        ReaderRoute.feed,
        ReaderRoute.blog,
        ReaderRoute.feedsPost,
        ReaderRoute.blogsPost,
        ReaderRoute.wpcomPost
    ]

    static let statsRoutes: [Route] = [
        StatsRoute.root,
        StatsRoute.site,
        StatsRoute.daySite,
        StatsRoute.weekSite,
        StatsRoute.monthSite,
        StatsRoute.yearSite,
        StatsRoute.insights,
        StatsRoute.dayCategory,
        StatsRoute.annualStats,
        StatsRoute.activityLog,
        StatsRoute.subscribers,
        StatsRoute.daySubscribers
    ]

    static let mySitesRoutes: [Route] = MySitesRoute.allCases

    static let appBannerRoutes: [Route] = [
        AppBannerRoute()
    ]

    static let redirects: [Route] = [
        MbarRoute()
    ]

    /// - returns: True if the URL routing system can handle the given URL,
    ///            but does not perform any actions or tracking.
    ///
    func canHandle(url: URL) -> Bool {
        let matcherCanHandle = matcher.routesMatching(url).count > 0

        guard let host = url.host, let scheme = url.scheme else {
            return matcherCanHandle
        }

        // If there's a hostname, check if it's WordPress.com or jetpack.com/app.
        return scheme == "https"
        && (host == "wordpress.com" || host == "jetpack.com")
        && matcherCanHandle
    }

    /// Attempts to find a route that matches the url's path, and perform its
    /// associated action.
    ///
    /// - parameter url: The URL to match against.
    /// - parameter track: If false, don't post an analytics event for this URL.
    ///
    func handle(url: URL, shouldTrack track: Bool = true, source: DeepLinkSource? = nil) {
        let matches = matcher.routesMatching(url)

        // We don't want to track internal links
        if track, source?.isInternal != true {
            trackDeepLinks(with: matches, for: url, source: source)
        }

        if matches.isEmpty {
            // TODO: This is a workaround. Remove after the Universal Link routes for the WordPress app are removed.
            //
            // Don't fallback to Safari if the counterpart WordPress/Jetpack app is installed.
            // Read more: https://github.com/wordpress-mobile/WordPress-iOS/issues/19755
            if MigrationAppDetection.isCounterpartAppInstalled {
                return
            }

            UIApplication.shared.open(url,
                                      options: [:],
                                      completionHandler: nil)
        }

        // Extract the presenter if there is one
        var presentingViewController: UIViewController? = nil
        if case .inApp(let viewController) = source {
            presentingViewController = viewController
        }

        for matchedRoute in matches {
            if matchedRoute.jetpackPowered && !JetpackFeaturesRemovalCoordinator.shouldShowJetpackFeatures() {
                // Display overlay
                RootViewCoordinator.sharedPresenter.showJetpackOverlayForDisabledEntryPoint()

                // Track incorrect access
                let properties = ["calling_function": "deep_link", TracksPropertyKeys.url: url.absoluteString]
                WPAnalytics.track(.jetpackFeatureIncorrectlyAccessed, properties: properties)
                continue
            }
            matchedRoute.action.perform(matchedRoute.values, source: presentingViewController, router: self)
        }
    }

    private func trackDeepLinks(with matches: [MatchedRoute], for url: URL, source: DeepLinkSource? = nil) {
        if matches.isEmpty {
            WPAppAnalytics.track(.deepLinkFailed, withProperties: [TracksPropertyKeys.url: url.absoluteString])
            return
        }

        matches.forEach({ trackDeepLink(for: $0, source: source) })
    }

    private func trackDeepLink(for match: MatchedRoute, source: DeepLinkSource? = nil) {
        // Check if the route is overridding tracking
        if match.shouldTrack == false {
            return
        }

        // If we've been passed a source we'll use that to override the route's original source.
        // For example, if we've been handed a link from a banner.
        let properties: [String: String] = [
            TracksPropertyKeys.url: match.path,
            TracksPropertyKeys.source: source?.tracksValue ?? match.source.tracksValue,
            TracksPropertyKeys.sourceInfo: source?.trackingInfo ?? match.source.trackingInfo ?? "",
            TracksPropertyKeys.section: match.section?.rawValue ?? "",
        ]

        if UniversalLinkRouter.extraLoggingEnabled {
            logDeepLink(with: properties)
        }

        WPAppAnalytics.track(.deepLinked, withProperties: properties)
    }

    private func logDeepLink(with properties: [String: String]) {
        let path = properties[TracksPropertyKeys.url] ?? ""
        let section = properties[TracksPropertyKeys.section] ?? ""
        let source = properties[TracksPropertyKeys.source] ?? ""
        let sourceInfo = properties[TracksPropertyKeys.sourceInfo] ?? ""
        let info = sourceInfo.isEmpty ? "" : " – \(sourceInfo)"

        DDLogInfo("🔗 Deep link: \(path), source: \(source)\(info), section: \(section)")
    }

    private enum TracksPropertyKeys {
        static let url = "url"
        static let source = "source"
        static let sourceInfo = "source_info"
        static let section = "section"
    }
}

extension DeepLinkSource {
    var tracksValue: String {
        switch self {
        case .link:
            return "link"
        case .banner:
            return "banner"
        case .email:
            return "email"
        case .widget:
            return "widget"
        case .lockScreenWidget:
            return "lockscreen_widget"
        case .inApp:
            return "internal"
        }
    }
}
