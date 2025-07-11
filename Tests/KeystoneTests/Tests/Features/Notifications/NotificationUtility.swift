import CoreData
import Foundation
import XCTest
import WordPressData
@testable import WordPress
@testable import FormattableContentKit

class NotificationUtility {
    private let coreDataStack: CoreDataStack
    private var context: NSManagedObjectContext {
        coreDataStack.mainContext
    }

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    private var entityName: String {
        return Notification.classNameWithoutNamespaces()
    }

    func loadBadgeNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-badge.json", insertInto: context)
    }

    func loadLikeNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-like.json", insertInto: context)
    }

    func loadLikeMultipleAvatarNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-like-multiple-avatar.json", insertInto: context)
    }

    func loadFollowerNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-new-follower.json", insertInto: context)
    }

    func loadCommentNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-replied-comment.json", insertInto: context)
    }

    func loadUnapprovedCommentNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-unapproved-comment.json", insertInto: context)
    }

    func loadPingbackNotification() throws -> WordPressData.Notification {
        return try .fixture(fromFile: "notifications-pingback.json", insertInto: context)
    }

    func mockCommentContent() throws -> FormattableCommentContent {
        let dictionary = try JSONObject(fromFileNamed: "notifications-replied-comment.json")
        let body = dictionary["body"]
        let blocks = NotificationContentFactory.content(from: body as! [[String: AnyObject]], actionsParser: NotificationActionParser(), parent: WordPressData.Notification(context: context))
        return blocks.filter { $0.kind == .comment }.first! as! FormattableCommentContent
    }

    func mockCommentContext() throws -> ActionContext<FormattableCommentContent> {
        return try ActionContext(block: mockCommentContent())
    }
}
