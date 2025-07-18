import Foundation
import WordPressData

extension PostService {
    @objc func updateMediaFor(post: AbstractPost,
                              success: @escaping () -> Void,
                              failure: @escaping (Error?) -> Void) {
        let mediaToUpdate = Array(post.media).filter { media in
            guard let postID = media.postID else { return false }
            return postID.intValue <= 0
        }

        mediaToUpdate.forEach { media in
            media.postID = post.postID
        }

        let mediaService = MediaService(managedObjectContext: self.managedObjectContext)
        mediaService.updateMedia(mediaToUpdate, fieldsToUpdate: ["postID"], overallSuccess: {
            ContextManager.shared.save(self.managedObjectContext)
            success()
        }) { error in
            failure(error)
        }
    }
}
