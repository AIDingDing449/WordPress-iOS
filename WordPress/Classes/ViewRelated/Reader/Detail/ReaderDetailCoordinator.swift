import Foundation
import WordPressData
import WordPressReader
import WordPressShared
import WordPressUI
import Combine
import WebKit

class ReaderDetailCoordinator {

    /// Key for restoring the VC post
    static let restorablePostObjectURLKey: String = "RestorablePostObjectURLKey"

    /// A post to be displayed
    var post: ReaderPost? {
        didSet {
            postInUse(true)
            indexReaderPostInSpotlight()
        }
    }

    /// Used to determine if block and report are shown in the options menu.
    var readerTopic: ReaderAbstractTopic?

    /// Used for analytics
    var remoteSimplePost: RemoteReaderSimplePost?

    /// A post URL to be loaded and be displayed
    var postURL: URL?

    /// A comment ID used to navigate to a comment
    var commentID: Int? {
        // Comment fragments have the form #comment-50484
        // If one is present, we'll extract the ID and return it.
        if let fragment = postURL?.fragment,
           fragment.hasPrefix("comment-"),
           let idString = fragment.components(separatedBy: "comment-").last {
            return Int(idString)
        }

        return nil
    }

    /// ID representing the notification the post details is triggered from
    /// If post details is not related to a notification, this property is `nil`
    var notificationID: String?

    /// Called if the view controller's post fails to load
    var postLoadFailureBlock: (() -> Void)? = nil

    private var likesAvatarURLs: [String]?

    /// An authenticator to ensure any request made to WP sites is properly authenticated
    lazy var authenticator: RequestAuthenticator? = {
        guard let account = try? WPAccount.lookupDefaultWordPressComAccount(in: coreDataStack.mainContext) else {
            DDLogInfo("Account not available for Reader authentication")
            return nil
        }

        return RequestAuthenticator(account: account)
    }()

    /// Core Data stack manager
    private let coreDataStack: CoreDataStack

    /// Reader Post Service
    private let readerPostService: ReaderPostService

    /// Reader Topic Service
    private let topicService: ReaderTopicService

    /// Post Service
    private let postService: PostService

    /// Comment Service
    private let commentService: CommentService
    private let commentsDisplayed: UInt = 1

    /// Post Sharing Controller
    private let sharingController: PostSharingController

    /// Reader Link Router
    private let readerLinkRouter: UniversalLinkRouter

    /// Reader View
    private weak var view: ReaderDetailView?

    /// Reader View Controller
    private var viewController: UIViewController? {
        return view as? UIViewController
    }

    /// A post ID to fetch
    private(set) var postID: NSNumber?

    /// A site ID to be used to fetch a post
    private(set) var siteID: NSNumber?

    /// If the site is an external feed (not hosted at WPcom and not using Jetpack)
    private(set) var isFeed: Bool?

    /// The perma link URL for the loaded post
    private var permaLinkURL: URL? {
        guard let postURLString = post?.permaLink else {
            return nil
        }

        return URL(string: postURLString)
    }

    private var followCommentsService: FollowCommentsService?
    private var likesObserver: AnyCancellable?

    /// Initialize the Reader Detail Coordinator
    ///
    /// - Parameter service: a Reader Post Service
    init(coreDataStack: CoreDataStack = ContextManager.shared,
         readerPostService: ReaderPostService = ReaderPostService(coreDataStack: ContextManager.shared),
         topicService: ReaderTopicService = ReaderTopicService(coreDataStack: ContextManager.shared),
         postService: PostService = PostService(managedObjectContext: ContextManager.shared.mainContext),
         commentService: CommentService = CommentService(coreDataStack: ContextManager.shared),
         sharingController: PostSharingController = PostSharingController(),
         readerLinkRouter: UniversalLinkRouter = UniversalLinkRouter(routes: UniversalLinkRouter.readerRoutes),
         view: ReaderDetailView) {
        self.coreDataStack = coreDataStack
        self.readerPostService = readerPostService
        self.topicService = topicService
        self.postService = postService
        self.commentService = commentService
        self.sharingController = sharingController
        self.readerLinkRouter = readerLinkRouter
        self.view = view
    }

    deinit {
        postInUse(false)
    }

    /// Start the coordinator
    ///
    func start() {
        view?.showLoading()

        if post != nil {
            renderPostAndBumpStats()
        } else if let siteID, let postID, let isFeed {
            fetch(postID: postID, siteID: siteID, isFeed: isFeed)
        } else if let postURL {
            fetch(postURL)
        }
    }

    /// Fetch related posts for the current post
    ///
    func fetchRelatedPosts(for post: ReaderPost) {
        readerPostService.fetchRelatedPosts(for: post) { [weak self] relatedPosts in
            self?.view?.renderRelatedPosts(relatedPosts)
        } failure: { error in
            DDLogError("Error fetching related posts for detail: \(String(describing: error?.localizedDescription))")
        }
    }

    func fetchLikes(for post: ReaderPost) {
        guard let postID = post.postID else { return }

        // Fetch a full page of Likes but only return the `maxAvatarsDisplayed` number.
        // That way the first page will already be cached if the user displays the full Likes list.
        postService.getLikesFor(postID: postID, siteID: post.siteID, success: { [weak self] users, totalLikes, _ in
            guard let self else { return }

            var filteredUsers = users
            if let account = try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext),
               let userID = account.userID?.int64Value,
               let userIndex = filteredUsers.firstIndex(where: { $0.userID == userID }) {
                filteredUsers.remove(at: userIndex)
            }

            self.likesAvatarURLs = filteredUsers.prefix(ReaderDetailLikesView.maxAvatarsDisplayed).map(\.avatarUrl)
            self.updateLikesView()
            self.startObservingLikes()
        }, failure: { error in
            DDLogError("Error fetching Likes for post detail: \(String(describing: error?.localizedDescription))")
        })
    }

    private func startObservingLikes() {
        guard let post else {
            return wpAssertionFailure("post missing")
        }

        likesObserver = Publishers.CombineLatest(
            post.publisher(for: \.likeCount, options: [.new]).removeDuplicates(),
            post.publisher(for: \.isLiked, options: [.new]).removeDuplicates()
        ).sink { [weak self] _, _ in
            self?.updateLikesView()
        }
    }

    private func updateLikesView() {
        guard let post, let likesAvatarURLs else { return }

        let viewModel = ReaderDetailLikesViewModel(
            likeCount: post.likeCount.intValue,
            avatarURLs: likesAvatarURLs,
            selfLikeAvatarURL: post.isLiked ? try? WPAccount.lookupDefaultWordPressComAccount(in: ContextManager.shared.mainContext)?.avatarURL : nil
        )
        view?.updateLikesView(with: viewModel)
    }

    /// Fetch Comments for the current post.
    ///
    func fetchComments(for post: ReaderPost) {
        commentService.syncHierarchicalComments(for: post,
                                   topLevelComments: commentsDisplayed,
                                            success: { [weak self] _, totalComments in
                                                self?.updateCommentsFor(post: post, totalComments: totalComments?.intValue ?? 0)
                                            }, failure: { error in
                                                DDLogError("Failed fetching post detail comments: \(String(describing: error))")
                                            })
    }

    func updateCommentsFor(post: ReaderPost, totalComments: Int) {
        guard let comments = commentService.topLevelComments(commentsDisplayed, for: post) as? [Comment] else {
            view?.updateComments([], totalComments: 0)
            return
        }

        view?.updateComments(comments, totalComments: totalComments)
    }

    /// Share the current post
    ///
    func share(fromView anchorView: UIView) {
        self.share(fromAnchor: anchorView)
    }

    /// Share the current post
    ///
    func share(fromAnchor anchor: UIPopoverPresentationControllerSourceItem) {
        guard let post, let view = viewController else {
            return
        }

        sharingController.shareReaderPost(post, fromAnchor: anchor, inViewController: view)

        WPAnalytics.trackReader(.readerSharedItem)
    }

    /// Set a postID, siteID and isFeed
    ///
    /// - Parameter postID: A post ID to fetch
    /// - Parameter siteID: A site ID to fetch
    /// - Parameter isFeed: If the site is an external feed (not hosted at WPcom and not using Jetpack)
    func set(postID: NSNumber, siteID: NSNumber, isFeed: Bool) {
        self.postID = postID
        self.siteID = siteID
        self.isFeed = isFeed
    }

    /// Show more about a specific site in Discovery
    ///
    func showMore() {
        guard let post, post.sourceAttribution != nil else {
            return
        }

        if let blogID = post.sourceAttribution.blogID {
            let controller = ReaderStreamViewController.controllerWithSiteID(blogID, isFeed: false)
            viewController?.navigationController?.pushViewController(controller, animated: true)
            return
        }

        var path: String?
        if post.sourceAttribution.attributionType == SourcePostAttributionTypePost {
            path = post.sourceAttribution.permalink
        } else {
            path = post.sourceAttribution.blogURL
        }

        if let path, let linkURL = URL(string: path) {
            presentWebViewController(linkURL)
        }
    }

    /// Loads an image (or GIF) from a URL and displays it in fullscreen
    ///
    /// - Parameter url: URL of the image or gif
    func presentImage(_ url: URL) {
        WPAnalytics.trackReader(.readerArticleImageTapped)

        let host = post.map(MediaHost.init)
        let lightboxVC = LightboxViewController(sourceURL: url, host: host)
        lightboxVC.configureZoomTransition()
        viewController?.present(lightboxVC, animated: true)
    }

    /// Open the postURL in a separated view controller
    ///
    func openInBrowser() {

        let url: URL? = {
            // For Reader posts, use post link.
            if let permaLink = post?.permaLink {
                return URL(string: permaLink)
            }
            // For Related posts, use postURL.
            return postURL
        }()

        guard let postURL = url else {
            return
        }

        WPAnalytics.trackReader(.readerArticleVisited)
        presentWebViewController(postURL)
    }

    /// Some posts have content from private sites that need special cookies
    ///
    /// Use this method to make sure these cookies are downloaded.
    /// - Parameter webView: the webView where the post will be rendered
    /// - Parameter completion: a completion block
    func storeAuthenticationCookies(in webView: WKWebView, completion: @escaping () -> Void) {
        guard let authenticator,
            let postURL = permaLinkURL else {
            completion()
            return
        }

        authenticator.request(url: postURL, cookieJar: webView.configuration.websiteDataStore.httpCookieStore) { _ in
            completion()
        }
    }

    /// Requests a ReaderPost from the service and updates the View.
    ///
    /// Use this method to fetch a ReaderPost.
    /// - Parameter postID: a post identification
    /// - Parameter siteID: a site identification
    /// - Parameter isFeed: a Boolean indicating if the site is an external feed (not hosted at WPcom and not using Jetpack)
    private func fetch(postID: NSNumber, siteID: NSNumber, isFeed: Bool) {
        readerPostService.fetchPost(postID.uintValue,
                                    forSite: siteID.uintValue,
                                    isFeed: isFeed,
                                    success: { [weak self] post in
                                        self?.post = post
                                        self?.renderPostAndBumpStats()
                                    }, failure: { [weak self] error in
                                        self?.postURL == nil ? self?.showError(error: error) : self?.view?.showErrorWithWebAction()
                                        self?.reportPostLoadFailure()
                                    })
    }

    /// Requests a ReaderPost from the service and updates the View.
    ///
    /// Use this method to fetch a ReaderPost from a URL.
    /// - Parameter url: a post URL
    private func fetch(_ url: URL) {
        readerPostService.fetchPost(at: url,
                                    success: { [weak self] post in
                                        self?.post = post
                                        self?.renderPostAndBumpStats()
                                    }, failure: { [weak self] error in
                                        DDLogError("Error fetching post for detail: \(String(describing: error?.localizedDescription))")
                                        self?.postURL == nil ? self?.showError(error: error) : self?.view?.showErrorWithWebAction()
                                        self?.reportPostLoadFailure()
                                    })
    }

    private func showError(error: Error?) {
        let errorMessage: String? = {
            guard let error = error as? NSError,
                  error.domain == WordPressComRestApiEndpointError.errorDomain,
                  error.code == WordPressComRestApiErrorCode.authorizationRequired.rawValue else {
                return nil
            }
            return Strings.fetchDetailFromPrivateBlogErrorMessage
        }()
        self.view?.showError(subtitle: errorMessage)
    }

    private func renderPostAndBumpStats() {
        guard let post else {
            return
        }

        view?.render(post)

        bumpStats()
        bumpPageViewsForPost()
        markPostAsSeen()
    }

    private func markPostAsSeen() {
        guard let post, !post.isSeen else {
            return
        }

        readerPostService.toggleSeen(for: post, success: {
            NotificationCenter.default.post(name: .ReaderPostSeenToggled,
                                            object: nil,
                                            userInfo: [ReaderNotificationKeys.post: post])
        }, failure: nil)
    }

    /// If the loaded URL contains a hash/anchor then jump to that spot in the post content
    /// once it loads
    ///
    private func scrollToHashIfNeeded() {
        guard
            let url = postURL,
            let hash = URLComponents(url: url, resolvingAgainstBaseURL: true)?.fragment
        else {
            return
        }

        view?.scroll(to: hash)
    }

    /// Shows the current post site posts in a new screen
    ///
    private func previewSite() {
        guard let post else {
            return
        }

        let controller = ReaderStreamViewController.controllerWithSiteID(post.siteID, isFeed: post.isExternal)
        viewController?.navigationController?.pushViewController(controller, animated: true)

        let properties = ReaderHelpers.statsPropertiesForPost(post, andValue: post.blogURL as AnyObject?, forKey: "URL")
        WPAppAnalytics.track(.readerSitePreviewed, withProperties: properties)
    }

    private func showTopic(_ topic: String) {
        let controller = ReaderStreamViewController.controllerWithTagSlug(topic)
        viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    /// Show a list with posts containing this tag
    ///
    private func showTag() {
        guard let post else {
            return
        }

        let controller = ReaderStreamViewController.controllerWithTagSlug(post.primaryTagSlug)
        viewController?.navigationController?.pushViewController(controller, animated: true)

        let properties = ReaderHelpers.statsPropertiesForPost(post, andValue: post.primaryTagSlug as AnyObject?, forKey: "tag")
        WPAppAnalytics.track(.readerTagPreviewed, withProperties: properties)
    }

    /// Given a URL presents it the best way possible.
    ///
    /// If it's an image, shows it fullscreen.
    /// If it's a fullscreen Story link, open it in the webview controller.
    /// If it's a post, open a new detail screen.
    /// If it's a link protocol (tel: / sms: / mailto:), take the correct action.
    /// If it's a regular URL, open it in the webview controller.
    ///
    /// - Parameter url: the URL to be handled
    func handle(_ url: URL) {
        // If the URL has an anchor (#)
        // and the URL is equal to the current post URL
        if let hash = URLComponents(url: url, resolvingAgainstBaseURL: true)?.fragment,
           let postURL = permaLinkURL,
           postURL.isHostAndPathEqual(to: url) {
            view?.scroll(to: hash)
        } else if url.pathExtension.contains("gif") ||
                    url.pathExtension.contains("jpg") ||
                    url.pathExtension.contains("jpeg") ||
                    url.pathExtension.contains("png") {
            presentImage(url)
        } else if url.query?.contains("wp-story") ?? false {
            presentWebViewController(url)
        } else if readerLinkRouter.canHandle(url: url) {
            readerLinkRouter.handle(url: url, shouldTrack: false, source: .inApp(presenter: viewController))
        } else if url.isWordPressDotComPost {
            presentReaderDetail(url)
        } else if url.isLinkProtocol {
            readerLinkRouter.handle(url: url, shouldTrack: false, source: .inApp(presenter: viewController))
        } else {
            WPAnalytics.trackReader(.readerArticleLinkTapped)

            presentWebViewController(url)
        }
    }

    /// Called after the webView fully loads
    func webViewDidLoad() {
        scrollToHashIfNeeded()
    }

    /// Show the featured image fullscreen
    ///
    private func showFeaturedImage(_ sender: AsyncImageView) {
        guard let post, let imageURL = post.featuredImage.flatMap(URL.init) else {
            return
        }
        let lightboxVC = LightboxViewController(sourceURL: imageURL, host: MediaHost(post))
        MainActor.assumeIsolated {
            lightboxVC.thumbnail = sender.image
        }
        lightboxVC.configureZoomTransition(sourceView: sender)
        viewController?.present(lightboxVC, animated: true)
    }

    private func followSite(completion: @escaping () -> Void) {
        guard let post else {
            return
        }

        ReaderFollowAction().execute(with: post,
                                     context: coreDataStack.mainContext,
                                     completion: { [weak self] follow in
                                        ReaderHelpers.dispatchToggleFollowSiteMessage(post: post, follow: follow, success: true)
                                        self?.view?.updateHeader()
                                        completion()
                                     },
                                     failure: { [weak self] follow, _ in
                                        ReaderHelpers.dispatchToggleFollowSiteMessage(post: post, follow: follow, success: false)
                                        self?.view?.updateHeader()
                                        completion()
                                     })
    }

    /// Given a URL presents it in a new Reader detail screen
    ///
    private func presentReaderDetail(_ url: URL) {

        // In cross post Notifications, if the user tapped the link to the original post in the Notification body,
        // use the original post's info to display reader detail.
        // The API endpoint used by controllerWithPostID returns subscription flags for the post.
        // The API endpoint used by controllerWithPostURL does not return this information.
        // These flags are needed to display the `Follow conversation by email` option.
        // So if we can call controllerWithPostID, do so. Otherwise, fallback to controllerWithPostURL.
        // Ref: https://github.com/wordpress-mobile/WordPress-iOS/issues/17158

        let readerDetail: ReaderDetailViewController = {
            if let post,
               selectedUrlIsCrossPost(url) {
                return ReaderDetailViewController.controllerWithPostID(post.crossPostMeta.postID, siteID: post.crossPostMeta.siteID)
            }

            return ReaderDetailViewController.controllerWithPostURL(url)
        }()

        viewController?.navigationController?.pushViewController(readerDetail, animated: true)
    }

    private func selectedUrlIsCrossPost(_ url: URL) -> Bool {
        // Trim trailing slashes to facilitate URL comparison.
        let characterSet = CharacterSet(charactersIn: "/")

        guard let post,
              post.isCross(),
              let crossPostMeta = post.crossPostMeta,
              let crossPostURL = URL(string: crossPostMeta.postURL.trimmingCharacters(in: characterSet)),
              let selectedURL = URL(string: url.absoluteString.trimmingCharacters(in: characterSet)) else {
            return false
        }

        return crossPostURL.isHostAndPathEqual(to: selectedURL)
    }

    /// Given a URL presents it in a web view controller screen
    ///
    /// - Parameter url: the URL to be loaded
    private func presentWebViewController(_ url: URL) {
        var url = url
        if url.host == nil {
            if let postURL = permaLinkURL {
                url = URL(string: url.absoluteString, relativeTo: postURL)!
            }
        }
        let configuration = WebViewControllerConfiguration(url: url)
        configuration.authenticateWithDefaultAccount()
        configuration.addsWPComReferrer = true
        let controller = WebViewControllerFactory.controller(configuration: configuration, source: "reader_detail")
        let navController = UINavigationController(rootViewController: controller)
        viewController?.present(navController, animated: true)
    }

    /// Report to the callback that the post failed to load
    private func reportPostLoadFailure() {
        postLoadFailureBlock?()

        // We'll nil out the failure block so we don't perform multiple callbacks
        postLoadFailureBlock = nil
    }

    /// Change post's inUse property and saves the context
    private func postInUse(_ inUse: Bool) {
        guard let context = post?.managedObjectContext else {
            return
        }

        post?.inUse = inUse
        coreDataStack.save(context)
    }

    private func showLikesList() {
        guard let post else {
            return
        }
        let controller = ReaderDetailLikesListController(post: post, totalLikes: post.likeCount.intValue)
        viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    /// Index the post in Spotlight
    private func indexReaderPostInSpotlight() {
        guard let post else {
            return
        }

        SearchManager.shared.indexItem(post)
    }

    // MARK: - Analytics

    /// Bump WP App Analytics
    ///
    private func bumpStats() {
        guard let readerPost = post else {
            return
        }

        let isOfflineView = ReachabilityUtils.isInternetReachable() ? "no" : "yes"
        let detailType = readerPost.topic?.type == ReaderSiteTopic.TopicType ? DetailAnalyticsConstants.TypePreviewSite : DetailAnalyticsConstants.TypeNormal

        var properties = ReaderHelpers.statsPropertiesForPost(readerPost, andValue: nil, forKey: nil)
        properties[DetailAnalyticsConstants.TypeKey] = detailType
        properties[DetailAnalyticsConstants.OfflineKey] = isOfflineView

        // Track related post tapped
        if let simplePost = remoteSimplePost {
            switch simplePost.postType {
                case .local:
                    WPAnalytics.track(.readerRelatedPostFromSameSiteClicked, properties: properties)
                case .global:
                    WPAnalytics.track(.readerRelatedPostFromOtherSiteClicked, properties: properties)
                default:
                    DDLogError("Unknown related post type: \(String(describing: simplePost.postType))")
            }
        }

        // Additional properties for Reading Preferences
        if ReaderDisplaySettings.customizationEnabled {
            let setting = ReaderDisplaySettingStore().setting
            properties[DetailAnalyticsConstants.ReadingPreferences.isDefaultKey] = setting.isDefaultSetting
            properties[DetailAnalyticsConstants.ReadingPreferences.colorSchemeKey] = setting.color.valueForTracks
            properties[DetailAnalyticsConstants.ReadingPreferences.fontTypeKey] = setting.font.valueForTracks
            properties[DetailAnalyticsConstants.ReadingPreferences.fontSizeKey] = setting.size.valueForTracks
        }

        // Track open
        WPAppAnalytics.track(.readerArticleOpened, withProperties: properties)

        // Track as significant event for App Rating calculations
        AppRatingUtility.shared.incrementSignificantEvent()
    }

    /// Bump post page view
    ///
    private func bumpPageViewsForPost() {
        guard let readerPost = post else {
            return
        }

        ReaderHelpers.bumpPageViewForPost(readerPost)
    }

    private struct DetailAnalyticsConstants {
        static let TypeKey = "post_detail_type"
        static let TypeNormal = "normal"
        static let TypePreviewSite = "preview_site"
        static let OfflineKey = "offline_view"
        static let PixelStatReferrer = "https://wordpress.com/"

        struct ReadingPreferences {
            static let isDefaultKey = "reading_preferences_is_default"
            static let colorSchemeKey = "reading_preferences_color_scheme"
            static let fontTypeKey = "reading_preferences_font"
            static let fontSizeKey = "reading_preferences_font_size"
        }
    }
}

// MARK: - ReaderDetailHeaderViewDelegate
extension ReaderDetailCoordinator: ReaderDetailHeaderViewDelegate {
    func didTapBlogName() {
        previewSite()
    }

    func didTapTagButton() {
        showTag()
    }

    func didTapHeaderAvatar() {
        previewSite()
    }

    func didTapFollowButton(completion: @escaping () -> Void) {
        followSite(completion: completion)
    }

    func didSelectTopic(_ topic: String) {
        showTopic(topic)
    }

    func didTapLikes() {
        showLikesList()
    }

    func didTapComments() {
        guard let post, let viewController else {
            return
        }
        ReaderCommentAction().execute(post: post, origin: viewController, source: .postDetails)
    }
}

extension ReaderDetailCoordinator: ReaderDetailFeaturedImageViewDelegate {
    func didTapFeaturedImage(_ sender: AsyncImageView) {
        showFeaturedImage(sender)
    }
}

extension ReaderDetailCoordinator: ReaderDetailLikesViewDelegate {
    func didTapLikesView() {
        showLikesList()
    }
}

extension ReaderDetailCoordinator: ReaderDetailToolbarDelegate {}

// MARK: - Private Definitions

private extension ReaderDetailCoordinator {

    struct Strings {
        static let fetchDetailFromPrivateBlogErrorMessage = NSLocalizedString(
            "readerDetailCoordinator.readerDetail.privateBlogErrorMessage",
            value: "You don't have permission to view this private blog.",
            comment: "Error message that informs reader detail from a private blog cannot be fetched."
        )
    }

}

private extension URL {
    /// Handle the common link protocols.
    /// - tel: open a prompt to call the phone number
    /// - sms: compose new message in iMessage app
    /// - mailto: compose new email in Mail app
    ///
    var isLinkProtocol: Bool {
        guard let urlScheme = scheme else {
            return false
        }

        let linkProtocols = ["tel", "sms", "mailto"]
        if linkProtocols.contains(urlScheme) && UIApplication.shared.canOpenURL(self) {
            return true
        }

        return false
    }
}
