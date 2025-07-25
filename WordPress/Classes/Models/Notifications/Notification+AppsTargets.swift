import FormattableContentKit
import WordPressData

extension WordPressData.Notification {

    func renderSubject() -> NSAttributedString? {
        guard let subjectContent = subjectContentGroup?.blocks.first else {
            return nil
        }
        return formatter.render(content: subjectContent, with: SubjectContentStyles())
    }

    func renderSnippet() -> NSAttributedString? {
        guard let snippetContent else {
            return nil
        }
        return formatter.render(content: snippetContent, with: SnippetsContentStyles())
    }

    /// Returns the first BlockGroup of the specified type, if any.
    ///
    func contentGroup(ofKind kind: FormattableContentGroup.Kind) -> FormattableContentGroup? {
        for contentGroup in bodyContentGroups where contentGroup.kind == kind {
            return contentGroup
        }

        return nil
    }

    /// Attempts to find the Notification Range associated with a given URL.
    ///
    func contentRange(with url: URL) -> FormattableContentRange? {
        var groups = bodyContentGroups
        if let headerBlockGroup = headerContentGroup {
            groups.append(headerBlockGroup)
        }

        let blocks = groups.flatMap { $0.blocks }
        for block in blocks {
            if let range = block.range(with: url) {
                return range
            }
        }

        return nil
    }

    private func indexOfBody(type: BodyType) -> Int? {
        guard let body else {
            return nil
        }
        return body.firstIndex { item in
            guard let item = item as? [String: Any], let itemType = item[BodyKeys.type] as? String, itemType == type.rawValue else {
                return false
            }
            return true
        }
    }

    func body(ofType type: BodyType) -> [String: Any]? {
        guard let body, let index = indexOfBody(type: type) else {
            return nil
        }
        return body[index] as? [String: Any]
    }

    func updateBody(ofType type: BodyType, newValue: AnyObject) {
        guard let index = indexOfBody(type: type) else {
            return
        }
        self.body?[index] = newValue
    }

    func updateBody(ofType type: BodyType, newValue: [String: Any]) {
        self.updateBody(ofType: type, newValue: newValue as AnyObject)
    }

    enum BodyType: String {
        case post
        case comment
    }
}

// MARK: - Notification Computed Properties
//
extension WordPressData.Notification {

    /// Verifies if the current notification is a Pingback.
    ///
    var isPingback: Bool {
        guard subjectContentGroup?.blocks.count == 1 else {
            return false
        }
        guard let ranges = subjectContentGroup?.blocks.first?.ranges, ranges.count == 2 else {
            return false
        }
        return ranges.first?.kind == .site && ranges.last?.kind == .post
    }

    /// Verifies if the current notification is actually a Badge one.
    /// Note: Sorry about the following snippet. I'm (and will always be) against Duck Typing.
    ///
    @objc var isBadge: Bool {
        let blocks = bodyContentGroups.flatMap { $0.blocks }
        for block in blocks where block is FormattableMediaContent {
            guard let mediaBlock = block as? FormattableMediaContent else {
                continue
            }
            for media in mediaBlock.media where media.kind == .badge {
                return true
            }
        }
        return false
    }

    /// Verifies if the current notification is a Comment-Y note, and if it has been replied to.
    ///
    @objc var isRepliedComment: Bool {
        return kind == .comment && metaReplyID != nil
    }

    //// Check if this note is a comment and in 'Unapproved' status
    ///
    @objc var isUnapprovedComment: Bool {
        guard let block: FormattableCommentContent = contentGroup(ofKind: .comment)?.blockOfKind(.comment) else {
            return false
        }
        let commandId = ApproveCommentAction.actionIdentifier()
        return block.isActionEnabled(id: commandId) && !block.isActionOn(id: commandId)
    }

    var isViewMilestone: Bool {
        return type == "view_milestone"
    }

    /// Returns the Meta ID's collection, if any.
    ///
    fileprivate var metaIds: [String: AnyObject]? {
        return meta?[MetaKeys.Ids] as? [String: AnyObject]
    }

    /// Comment ID, if any.
    ///
    @objc var metaCommentID: NSNumber? {
        return metaIds?[MetaKeys.Comment] as? NSNumber
    }

    /// Comment Author ID, if any.
    ///
    @objc var metaCommentAuthorID: NSNumber? {
        return metaIds?[MetaKeys.User] as? NSNumber
    }

    /// Comment Parent ID, if any.
    ///
    @objc var metaParentID: NSNumber? {
        return metaIds?[MetaKeys.Parent] as? NSNumber
    }

    /// Post ID, if any.
    ///
    @objc var metaPostID: NSNumber? {
        return metaIds?[MetaKeys.Post] as? NSNumber
    }

    /// Comment Reply ID, if any.
    ///
    @objc var metaReplyID: NSNumber? {
        return metaIds?[MetaKeys.Reply] as? NSNumber
    }

    /// Site ID, if any.
    ///
    @objc var metaSiteID: NSNumber? {
        return metaIds?[MetaKeys.Site] as? NSNumber
    }

    /// Icon URL
    ///
    @objc var iconURL: URL? {
        guard let rawIconURL = icon, let iconURL = URL(string: rawIconURL) else {
            return nil
        }

        return iconURL
    }

    /// Associated Resource URL
    ///
    @objc var resourceURL: URL? {
        guard let rawURL = url, let resourceURL = URL(string: rawURL) else {
            return nil
        }

        return resourceURL
    }

    var subjectContentGroup: FormattableContentGroup? {
        if let group = cachedSubjectContentGroup {
            return group
        }

        guard let subject = subject as? [[String: AnyObject]], subject.isEmpty == false else {
            return nil
        }

        cachedSubjectContentGroup = SubjectContentGroup.createGroup(from: subject, parent: self)
        return cachedSubjectContentGroup
    }

    var headerContentGroup: FormattableContentGroup? {
        if let group = cachedHeaderContentGroup {
            return group
        }

        guard let header = header as? [[String: AnyObject]], header.isEmpty == false else {
            return nil
        }

        cachedHeaderContentGroup = HeaderContentGroup.createGroup(from: header, parent: self)
        return cachedHeaderContentGroup
    }

    var bodyContentGroups: [FormattableContentGroup] {
        if let group = cachedBodyContentGroups {
            return group
        }

        guard let body = body as? [[String: AnyObject]], body.isEmpty == false else {
            return []
        }

        cachedBodyContentGroups = BodyContentGroup.create(from: body, parent: self)
        return cachedBodyContentGroups ?? []
    }

    var headerAndBodyContentGroups: [FormattableContentGroup] {
        if let groups = cachedHeaderAndBodyContentGroups {
            return groups
        }

        var mergedGroups = [FormattableContentGroup]()
        if let header = headerContentGroup {
            mergedGroups.append(header)
        }

        mergedGroups.append(contentsOf: bodyContentGroups)
        cachedHeaderAndBodyContentGroups = mergedGroups

        return mergedGroups
    }

    var snippetContent: FormattableContent? {
        guard let content = subjectContentGroup?.blocks, content.count > 1 else {
            return nil
        }
        return content.last
    }

    var allAvatarURLs: [URL] {
        let users = body?.filter({ element in
            let type = element["type"] as? String
            return type == "user"
        }) ?? []

        let avatars: [URL] = users.compactMap {
            guard let allMedia = $0["media"] as? [AnyObject],
                  let firstMedia = allMedia.first,
                  let urlString = firstMedia["url"] as? String else {
                return nil
            }
            return URL(string: urlString)
        }

        return avatars
    }
}

// MARK: - Notification Subtypes

extension WordPressData.Notification {

    /// Parses the meta data of the notification to extract key information like postID
    /// Parsing logic and wrapper used depends on the notification kind
    /// - Returns: An enum with it's associated value being a wrapper around the notification
    func parsed() -> ParsedNotification {
        switch kind {
        case .newPost:
            if let note = NewPostNotification(note: self) {
                return .newPost(note)
            }
        case .comment:
            if let note = CommentNotification(note: self) {
                return .comment(note)
            }
        default:
            break
        }
        return .other(self)
    }

    enum ParsedNotification {
        case newPost(NewPostNotification)
        case comment(CommentNotification)
        case other(WordPressData.Notification)
    }
}

// MARK: - Update Helpers
//
extension WordPressData.Notification {
    /// Updates the local fields with the new values stored in a given Remote Notification
    ///
    func update(with remote: RemoteNotification) {
        notificationId = remote.notificationId
        notificationHash = remote.notificationHash
        read = remote.read
        icon = remote.icon
        noticon = remote.noticon
        timestamp = remote.timestamp
        type = remote.type
        url = remote.url
        title = remote.title
        subject = remote.subject
        header = remote.header
        body = remote.body
        meta = remote.meta
    }
}

// MARK: - Notification Types
//
extension WordPressData.Notification {
    /// Meta Parsing Keys
    ///
    fileprivate enum MetaKeys {
        static let Ids = "ids"
        static let Links = "links"
        static let Titles = "titles"
        static let Site = "site"
        static let Post = "post"
        static let Comment = "comment"
        static let User = "user"
        static let Parent = "parent_comment"
        static let Reply = "reply_comment"
        static let Home = "home"
    }

    /// Body Parsing Keys
    ///
    enum BodyKeys {
        static let type = "type"
        static let actions = "actions"
    }

    /// Actions Parsing Keys
    ///
    enum ActionsKeys {
        static let likePost = "like-post"
        static let likeComment = "like-comment"
    }
}

// MARK: - Notifiable

extension WordPressData.Notification: @retroactive Notifiable {
    public var notificationIdentifier: String {
        return notificationId
    }
}
