import Foundation
import WordPressData

@testable import WordPress

/// Builds a Post
///
/// Defaults to creating a post in a self-hosted site.
class PostBuilder {
    private let post: Post

    init(_ context: NSManagedObjectContext, blog: Blog? = nil, canBlaze: Bool = false) {
        post = NSEntityDescription.insertNewObject(forEntityName: Post.entityName(), into: context) as! Post

        // Non-null Core Data properties
        if let blog {
            post.blog = blog
        } else {
            post.blog = canBlaze ? BlogBuilder(context).canBlaze().build() : BlogBuilder(context).build()
        }
    }

    private static func buildPost(context: NSManagedObjectContext) -> Post {
        let blog = NSEntityDescription.insertNewObject(forEntityName: Blog.entityName(), into: context) as! Blog
        blog.xmlrpc = "http://example.com/xmlrpc.php"
        blog.url = "http://example.com"
        blog.username = "test"
        blog.password = "test"

        let post = NSEntityDescription.insertNewObject(forEntityName: Post.entityName(), into: context) as! Post
        post.blog = blog

        return post
    }

    func published() -> PostBuilder {
        post.status = .publish
        return self
    }

    func drafted() -> PostBuilder {
        post.status = .draft
        return self
    }

    func scheduled() -> PostBuilder {
        post.status = .scheduled
        return self
    }

    func trashed() -> PostBuilder {
        post.status = .trash
        return self
    }

    func `private`() -> PostBuilder {
        post.status = .publishPrivate
        return self
    }

    func pending() -> PostBuilder {
        post.status = .pending
        return self
    }

    func autosaved() -> PostBuilder {
        post.autosaveTitle = "a"
        post.autosaveExcerpt = "b"
        post.autosaveContent = "c"
        post.autosaveModifiedDate = Date()
        post.autosaveIdentifier = 1
        return self
    }

    func withImage() -> PostBuilder {
        post.pathForDisplayImage = "https://localhost/image.png"
        return self
    }

    func with(status: BasePost.Status) -> PostBuilder {
        post.status = status
        return self
    }

    func with(pathForDisplayImage: String) -> PostBuilder {
        post.pathForDisplayImage = pathForDisplayImage
        return self
    }

    func with(title: String) -> PostBuilder {
        post.postTitle = title
        return self
    }

    func with(snippet: String) -> PostBuilder {
        post.content = snippet
        return self
    }

    func with(dateCreated: Date) -> PostBuilder {
        post.dateCreated = dateCreated
        return self
    }

    func with(dateModified: Date) -> PostBuilder {
        post.dateModified = dateModified
        return self
    }

    func with(author: String) -> PostBuilder {
        post.author = author
        return self
    }

    func with(userName: String) -> PostBuilder {
        post.blog.username = userName
        return self
    }

    func with(password: String) -> PostBuilder {
        post.blog.password = password
        return self
    }

    func with(remoteStatus: AbstractPostRemoteStatus) -> PostBuilder {
        post.remoteStatus = remoteStatus
        return self
    }

    func with(image: String, status: MediaRemoteStatus? = nil, autoUploadFailureCount: Int = 0) -> PostBuilder {
        guard let context = post.managedObjectContext else {
            return self
        }

        guard let media = NSEntityDescription.insertNewObject(forEntityName: Media.entityName(), into: context) as? Media else {
            return self
        }
        media.localURL = image
        media.localThumbnailURL = "thumb-\(image)"
        media.blog = post.blog
        media.autoUploadFailureCount = NSNumber(value: autoUploadFailureCount)

        if let status {
            media.remoteStatus = status
        }

        media.addPostsObject(post)
        post.addMediaObject(media)

        return self
    }

    func with(media: [Media]) -> PostBuilder {
        for item in media {
             item.blog = post.blog
        }
        post.media = Set(media)

        return self
    }

    func with(disabledConnections: [NSNumber: [String: String]]) -> PostBuilder {
        post.disabledPublicizeConnections = disabledConnections
        return self
    }

    func `is`(sticked: Bool) -> PostBuilder {
        post.isStickyPost = sticked
        return self
    }

    func supportsWPComAPI() -> PostBuilder {
        post.blog.supportsWPComAPI()
        return self
    }

    /// Sets a random postID to emulate that self exists in the server.
    func withRemote() -> PostBuilder {
        post.postID = NSNumber(value: arc4random_uniform(UINT32_MAX))
        return self
    }

    func build() -> Post {
        // TODO: Enable this assertion once we can ensure that the post's MOC isn't being deallocated after the `PostBuilder` is
        // assert(post.managedObjectContext != nil)
        return post
    }
}
