import WordPressData

/// Encapsulates a command to toggle a post's seen status
final class ReaderSeenAction {
    func execute(with post: ReaderPost, context: NSManagedObjectContext, completion: (() -> Void)? = nil, failure: ((Error?) -> Void)? = nil) {
        let postService = ReaderPostService(coreDataStack: ContextManager.shared)
        postService.toggleSeen(for: post, success: completion, failure: failure)
    }
}
