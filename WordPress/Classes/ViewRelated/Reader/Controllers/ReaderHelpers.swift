import Foundation
import WordPressData
import WordPressShared
import WordPressFlux
import AutomatticTracks

// MARK: - Reader Notifications

extension NSNotification.Name {
    // Sent when a site or a tag is unfollowed via Reader Manage screen.
    static let ReaderTopicUnfollowed = NSNotification.Name(rawValue: "ReaderTopicUnfollowed")
    // Sent when a post's seen state has been toggled.
    static let ReaderPostSeenToggled = NSNotification.Name(rawValue: "ReaderPostSeenToggled")
    // Sent when a site is blocked.
    static let ReaderSiteBlocked = NSNotification.Name(rawValue: "ReaderSiteBlocked")
    // Sent when site blocking will begin.
    static let ReaderSiteBlockingWillBegin = NSNotification.Name(rawValue: "ReaderSiteBlockingWillBegin")
    // Sent when site blocking failed.
    static let ReaderSiteBlockingFailed = NSNotification.Name(rawValue: "ReaderSiteBlockingFailed")
    // Sent when the user blocking request is sent
    static let ReaderUserBlockingWillBegin = NSNotification.Name(rawValue: "ReaderUserBlockingWillBegin")
    // Sent when the user blocking request is complete
    static let ReaderUserBlockingDidEnd = NSNotification.Name(rawValue: "ReaderUserBlockingDidEnd")
}

struct ReaderNotificationKeys {
    static let error = "error"
    static let result = "result"
    static let post = "post"
    static let topic = "topic"
}

/// A collection of helper methods used by the Reader.
///
@objc open class ReaderHelpers: NSObject {

    // MARK: - Topic Helpers

    public static let discoverSiteID = NSNumber(value: 53424024)

    /// Check if the specified topic is a default topic
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is a default topic
    ///
    @objc open class func isTopicDefault(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.isKind(of: ReaderDefaultTopic.self)
    }

    /// Check if the specified topic is a list
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is a list topic
    ///
    @objc open class func isTopicList(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.isKind(of: ReaderListTopic.self)
    }

    /// Check if the specified topic is a site topic
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is a site topic
    ///
    @objc open class func isTopicSite(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.isKind(of: ReaderSiteTopic.self)
    }

    /// Check if the specified topic is an RSS feed
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is an RSS feed
    ///
    @objc open class func isRSSFeed(_ topic: ReaderAbstractTopic) -> Bool {
        guard let site = topic as? ReaderSiteTopic else {
            return false
        }
        return site.siteID == 0
    }

    /// Check if the specified topic is a tag topic
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is a tag topic
    ///
    @objc open class func isTopicTag(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.isKind(of: ReaderTagTopic.self)
    }

    /// Check if the specified topic is a search topic
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is a search topic
    ///
    @objc open class func isTopicSearchTopic(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.isKind(of: ReaderSearchTopic.self)
    }

    /// Check if the specified topic is for Freshly Pressed
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is for Freshly Pressed
    ///
    @objc open class func topicIsFreshlyPressed(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.path.hasSuffix("/freshly-pressed")
    }

    /// Check if the specified topic is for Discover
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is for Discover
    ///
    @objc open class func topicIsDiscover(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.path.contains("/read/sites/53424024/posts")
    }

    /// Check if the specified topic is for Following
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is for Following
    ///
    @objc open class func topicIsFollowing(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.path.hasSuffix("/read/following")
    }

    /// Check if the specified topic is for Posts I Like
    ///
    /// - Parameters:
    ///     - topic: A ReaderAbstractTopic
    ///
    /// - Returns: True if the topic is for Posts I Like
    ///
    @objc open class func topicIsLiked(_ topic: ReaderAbstractTopic) -> Bool {
        return topic.path.hasSuffix("/read/liked")
    }

    // MARK: Analytics Helpers

    class func trackLoadedTopic(_ topic: ReaderAbstractTopic, withProperties properties: [AnyHashable: Any]) {
        var stat: WPAnalyticsStat?

        if topicIsFreshlyPressed(topic) {
            stat = .readerFreshlyPressedLoaded

        } else if topicIsFollowing(topic) {
            WPAnalytics.trackReader(.readerFollowingShown, properties: properties)

        } else if topicIsLiked(topic) {
            WPAnalytics.trackReader(.readerLikedShown, properties: properties)

        } else if isTopicSite(topic) {
            WPAnalytics.trackReader(.readerBlogPreviewed, properties: properties)

        } else if isTopicDefault(topic) && topicIsDiscover(topic) {
            // Tracks Discover only if it was one of the default menu items.
            WPAnalytics.trackReaderEvent(.readerDiscoverShown, properties: properties)

        } else if isTopicList(topic) {
            stat = .readerListLoaded

        } else if isTopicTag(topic) {
            stat = .readerTagLoaded

        } else if let teamTopic = topic as? ReaderTeamTopic {
            WPAnalytics.trackReader(teamTopic.slug == ReaderTeamTopic.a8cSlug ? .readerA8CShown : .readerP2Shown, properties: properties)
        }

        if stat != nil {
            WPAnalytics.track(stat!, withProperties: properties)
        }
    }

    @objc open class func statsPropertiesForPost(_ post: ReaderPost, andValue value: AnyObject?, forKey key: String?) -> [AnyHashable: Any] {
        var properties = [AnyHashable: Any]()
        properties[WPAppAnalyticsKeyBlogID] = post.siteID
        properties[WPAppAnalyticsKeyPostID] = post.postID
        properties[WPAppAnalyticsKeyIsJetpack] = post.isJetpack
        if let feedID = post.feedID, let feedItemID = post.feedItemID {
            properties[WPAppAnalyticsKeyFeedID] = feedID
            properties[WPAppAnalyticsKeyFeedItemID] = feedItemID
        }

        if let value, let key {
            properties[key] = value
        }

        return properties
    }

    @objc open class func statsPropertiesForPostAuthor(_ post: ReaderPost, andValue value: AnyObject? = nil, forKey key: String? = nil) -> [AnyHashable: Any] {
        var properties = Self.statsPropertiesForPost(post, andValue: value, forKey: key)
        properties[WPAppAnalyticsKeyPostAuthorID] = post.authorID
        return properties
    }

    @objc open class func bumpPageViewForPost(_ post: ReaderPost) {
        // Don't bump page views for feeds else the wrong blog/post get's bumped
        if post.isExternal && !post.isJetpack {
            return
        }

        guard
            let siteID = post.siteID,
            let postID = post.postID,
            let host = NSURL(string: post.blogURL)?.host else {
            return
        }

        // If the user is an admin on the post's site do not bump the page view unless
        // the the post is private.
        if !post.isBlogPrivate && isUserAdminOnSiteWithID(siteID) {
            return
        }

        let pixelStatReferrer = "https://wordpress.com/"
        let pixel = "https://pixel.wp.com/g.gif"
        let params: NSArray = [
            "v=wpcom",
            "reader=1",
            "ref=\(pixelStatReferrer)",
            "host=\(host)",
            "blog=\(siteID)",
            "post=\(postID)",
            NSString(format: "t=%d", arc4random())
        ]

        let userAgent = WPUserAgent.wordPress()
        let path = NSString(format: "%@?%@", pixel, params.componentsJoined(by: "&")) as String

        guard let url = URL(string: path) else {
            return
        }

        let request = NSMutableURLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.addValue(pixelStatReferrer, forHTTPHeaderField: "Referer")

        let session = URLSession.shared
        let task = session.dataTask(with: request as URLRequest)
        task.resume()
    }

    @objc open class func isUserAdminOnSiteWithID(_ siteID: NSNumber) -> Bool {
        Blog.lookup(withID: siteID, in: ContextManager.shared.mainContext)?.isAdmin ?? false
    }

    // convenience method that returns the topic type
    class func topicType(_ topic: ReaderAbstractTopic?) -> ReaderTopicType {
        guard let topic else {
            return .noTopic
        }
        if topicIsDiscover(topic) {
            return .discover
        }
        if topicIsFollowing(topic) {
            return .following
        }
        if topicIsLiked(topic) {
            return .likes
        }
        if isTopicList(topic) {
            return .list
        }
        if isTopicSearchTopic(topic) {
            return .search
        }
        if isTopicSite(topic) {
            return .site
        }
        if isTopicTag(topic) {
            return .tag
        }
        if topic is ReaderTeamTopic {
            return .organization
        }
        return .noTopic
    }

    // MARK: Logged in helper

    @objc open class func isLoggedIn() -> Bool {
        return AccountHelper.isDotcomAvailable()
    }

    // MARK: ActionDispatcher Notification helper

    class func dispatchToggleFollowSiteMessage(post: ReaderPost, follow: Bool, success: Bool) {
        guard let siteID = post.siteID else {
            /// This is a workaround to prevent a crash from occurring when trying to pass a `nil` site ID to dispatchToggleFollowSiteMessage.
            /// The root issue is that post.siteID should never be nil when this method is called.
            CrashLogging.main.logMessage("Expected siteID to exist", level: .error)
            return
        }

        let blogName = {
            guard let blogNameForDisplay = post.blogNameForDisplay() else {
                CrashLogging.main.logMessage("Expected blogNameForDisplay() to exist",
                                                 properties: ["siteID": siteID, "postID": post.postID ?? "nil"],
                                                 level: .error)
                return NoticeMessages.unknownSiteText
            }
            return blogNameForDisplay
        }()
        dispatchToggleFollowSiteMessage(siteTitle: blogName, siteID: siteID, follow: follow, success: success)
    }

    class func dispatchToggleFollowSiteMessage(site: ReaderSiteTopic, follow: Bool, success: Bool) {
        dispatchToggleFollowSiteMessage(siteTitle: site.title, siteID: site.siteID, follow: follow, success: success)
    }

    class func dispatchToggleSubscribeCommentMessage(subscribing: Bool, success: Bool, actionHandler: ((Bool) -> Void)?) {
        let title: String
        let message: String?
        let actionTitle: String?
        if success {
            title = subscribing ? NoticeMessages.commentFollowSuccess : NoticeMessages.commentUnfollowSuccess
            message = subscribing ? NoticeMessages.commentFollowSuccessMessage : nil
            actionTitle = subscribing ? NoticeMessages.commentFollowActionTitle : nil
        } else {
            title = subscribing ? NoticeMessages.commentFollowFail : NoticeMessages.commentUnfollowFail
            message = nil
            actionTitle = nil
        }
        dispatchNotice(
            Notice(
                title: title,
                message: message,
                actionTitle: actionTitle,
                actionHandler: actionHandler
            )
        )
    }

    class func dispatchToggleCommentNotificationMessage(subscribing: Bool, success: Bool) {
        let action: ReaderHelpers.PostSubscriptionAction = subscribing ? .enableNotification : .disableNotification
        dispatchNotice(Notice(title: noticeTitle(forAction: action, success: success)))
    }

    class func dispatchToggleSubscribeCommentErrorMessage(subscribing: Bool) {
        let title = subscribing ? NoticeMessages.commentFollowError : NoticeMessages.commentUnfollowError
        dispatchNotice(Notice(title: title))
    }

    class func dispatchToggleFollowSiteMessage(siteTitle: String, siteID: NSNumber, follow: Bool, success: Bool) {
        var notice: Notice

        if success {
            notice = follow
                ? followedSiteNotice(siteTitle: siteTitle, siteID: siteID)
                : Notice(title: NoticeMessages.unfollowSuccess, message: siteTitle)
        } else {
            notice = Notice(title: follow ? NoticeMessages.followFail : NoticeMessages.unfollowFail)
        }

        dispatchNotice(notice)
    }

    class func dispatchToggleNotificationMessage(topic: ReaderSiteTopic, success: Bool) {
        var notice: Notice {
            if success {
                return Notice(title: topic.isSubscribedForPostNotifications ? NoticeMessages.notificationOnSuccess : NoticeMessages.notificationOffSuccess)
            }
            return Notice(title: topic.isSubscribedForPostNotifications ? NoticeMessages.notificationOffFail : NoticeMessages.notificationOnFail)
        }

        dispatchNotice(notice)
    }

    class func dispatchSiteBlockedMessage(post: ReaderPost, success: Bool) {
        var notice: Notice {
            if success {
                return Notice(title: NoticeMessages.blockSiteSuccess, message: post.blogNameForDisplay())
            }
            return Notice(title: NoticeMessages.blockSiteFail, message: post.blogNameForDisplay())
        }

        dispatchNotice(notice)
    }

    class func dispatchUserBlockedMessage(post: ReaderPost, success: Bool) {
        var notice: Notice {
            if success {
                return Notice(title: NoticeMessages.blockUserSuccess, message: post.authorDisplayName ?? "")
            }
            return Notice(title: NoticeMessages.blockUserFail, message: post.authorDisplayName ?? "")
        }

        dispatchNotice(notice)
    }

    /// Enumerates the kind of actions available in relation to post subscriptions.
    /// TODO: Add `followConversation` and `unfollowConversation` once the "Follow Conversation" feature flag is removed.
    enum PostSubscriptionAction: Int {
        case enableNotification
        case disableNotification
    }

    class func noticeTitle(forAction action: PostSubscriptionAction, success: Bool) -> String {
        switch (action, success) {
        case (.enableNotification, true):
            return NSLocalizedString("In-app notifications enabled", comment: "The app successfully enabled notifications for the subscription")
        case (.enableNotification, false):
            return NSLocalizedString("Could not enable notifications", comment: "The app failed to enable notifications for the subscription")
        case (.disableNotification, true):
            return NSLocalizedString("In-app notifications disabled", comment: "The app successfully disabled notifications for the subscription")
        case (.disableNotification, false):
            return NSLocalizedString("Could not disable notifications", comment: "The app failed to disable notifications for the subscription")
        }
    }

    private class func dispatchNotice(_ notice: Notice) {
        ActionDispatcher.dispatch(NoticeAction.post(notice))
    }

    private class func followedSiteNotice(siteTitle: String, siteID: NSNumber) -> Notice {
        let notice = Notice(title: String(format: NoticeMessages.followSuccess, siteTitle),
                            message: NoticeMessages.enableNotifications,
                            actionTitle: NoticeMessages.enableButtonLabel) { _ in
            let service = ReaderTopicService(coreDataStack: ContextManager.shared)
            service.toggleSubscribingNotifications(for: siteID.intValue, subscribe: true, {
                WPAnalytics.track(.readerListNotificationEnabled)
            })
        }

        return notice
    }

    private struct NoticeMessages {
        static let followSuccess = NSLocalizedString(
            "reader.notice.subscribe.success",
            value: "Subscribed to %1$@",
            comment: "Notice title when following a blog succeeds. %1$@ is a placeholder for the site name."
        )
        static let unfollowSuccess = NSLocalizedString(
            "reader.notice.unsubscribe.success",
            value: "Unsubscribed from blog",
            comment: "Notice title when unfollowing a blog succeeds."
        )
        static let followFail = NSLocalizedString(
            "reader.notice.subscribe.failure",
            value: "Unable to subscribe to blog",
            comment: "Notice title when subscribing to a blog fails."
        )
        static let unfollowFail = NSLocalizedString(
            "reader.notice.unsubscribe.failure",
            value: "Unable to unsubscribe from blog",
            comment: "Notice title when unsubscribing to a blog fails."
        )
        static let notificationOnFail = NSLocalizedString(
            "reader.notice.enable.notification.failure",
            value: "Unable to turn on blog notifications",
            comment: "Notice title when turning blog notifications on fails."
        )
        static let notificationOffFail = NSLocalizedString(
            "reader.notice.disable.notification.failure",
            value: "Unable to turn off blog notifications",
            comment: "Notice title when turning blog notifications off fails."
        )
        static let notificationOnSuccess = NSLocalizedString(
            "reader.notice.enable.notification.success",
            value: "Turned on blog notifications",
            comment: "Notice title when turning blog notifications on succeeds."
        )
        static let notificationOffSuccess = NSLocalizedString(
            "reader.notice.disable.notification.success",
            value: "Turned off blog notifications",
            comment: "Notice title when turning blog notifications off succeeds."
        )
        static let enableNotifications = NSLocalizedString(
            "reader.notice.enable.notification.prompt",
            value: "Enable blog notifications?",
            comment: "Message prompting user to enable blog notifications."
        )
        static let enableButtonLabel = NSLocalizedString("Enable", comment: "Button title for the enable site notifications action.")
        static let blockSiteSuccess = NSLocalizedString(
            "reader.notice.blog.blocked.success",
            value: "Blocked blog",
            comment: "Notice title when blocking a site succeeds."
        )
        static let blockSiteFail = NSLocalizedString(
            "reader.notice.blog.blocked.failure",
            value: "Unable to block blog",
            comment: "Notice title when blocking a blog fails."
        )
        static let blockUserSuccess = NSLocalizedString(
            "Blocked user",
            value: "Blocked user",
            comment: "Notice title when blocking a user succeeds."
        )
        static let blockUserFail = NSLocalizedString(
            "reader.notice.user.blocked",
            value: "reader.notice.user.block.failed",
            comment: "Notice title when blocking a user fails."
        )
        static let commentFollowSuccess = NSLocalizedString("Following this conversation", comment: "The app successfully subscribed to the comments for the post")
        static let commentFollowSuccessMessage = NSLocalizedString("You'll get notifications in the app", comment: "The app successfully subscribed to the comments for the post")
        static let commentFollowActionTitle = NSLocalizedString("Undo", comment: "Revert enabling notification after successfully subcribing to the comments for the post.")
        static let commentUnfollowSuccess = NSLocalizedString("Successfully unfollowed conversation", comment: "The app successfully unsubscribed from the comments for the post")
        static let commentFollowFail = NSLocalizedString("Unable to follow conversation", comment: "The app failed to subscribe to the comments for the post")
        static let commentUnfollowFail = NSLocalizedString("Failed to unfollow conversation", comment: "The app failed to unsubscribe from the comments for the post")
        static let commentFollowError = NSLocalizedString("Could not subscribe to comments", comment: "The app failed to subscribe to the comments for the post")
        static let commentUnfollowError = NSLocalizedString("Could not unsubscribe from comments", comment: "The app failed to unsubscribe from the comments for the post")
        static let unknownSiteText = NSLocalizedString(
            "reader.notice.subscribe.blog.unknown",
            value: "this blog",
            comment: """
                A default value used to fill in the site name when the followed site somehow has missing site name or URL.
                Example: given a notice format "Following %@" and empty site name, this will be "Following this blog".
                """
        )
    }
}

/// Typed topic type
enum ReaderTopicType {
    case discover
    case following
    case likes
    case list
    case search
    case site
    case tag
    case organization
    case noTopic
}
