import Foundation
import CoreData

public extension Post {

    @NSManaged var commentCount: NSNumber?
    @NSManaged var disabledPublicizeConnections: [NSNumber: [String: String]]?
    @NSManaged var likeCount: NSNumber?
    @NSManaged var postFormat: String?
    @NSManaged var postType: String?
    @NSManaged var publicID: String?
    @NSManaged var publicizeMessage: String?
    @NSManaged var publicizeMessageID: String?
    @NSManaged var tags: String?
    @NSManaged var categories: Set<PostCategory>?
    @NSManaged var isStickyPost: Bool

    // If the post is created as an answer to a Blogging Prompt, the promptID is stored here.
    @NSManaged var bloggingPromptID: String?

    // These were added manually, since the code generator for Swift is not generating them.
    //
    @NSManaged func addCategoriesObject(_ value: PostCategory)
    @NSManaged func removeCategoriesObject(_ value: PostCategory)
    @NSManaged func addCategories(_ values: Set<PostCategory>)
    @NSManaged func removeCategories(_ values: Set<PostCategory>)
}
