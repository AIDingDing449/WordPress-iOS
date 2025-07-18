import UIKit
import WordPressData

/// This class simply exists to coordinate the display of various sections of
/// the app in response to actions taken by the user from Media notifications.
///
class MediaNoticeNavigationCoordinator {
    static func presentEditor(with userInfo: NSDictionary) {
        if let blog = blog(from: userInfo) {
            presentEditor(for: blog, source: "media_upload_notification", media: successfulMedia(from: userInfo))
        }
    }

    static func presentEditor(for blog: Blog, source: String, media: [Media]) {
        WPAppAnalytics.track(.notificationsUploadMediaSuccessWritePost, blog: blog)

        let editor = EditPostViewController(blog: blog)
        editor.modalPresentationStyle = .fullScreen
        editor.insertedMedia = media
        RootViewCoordinator.sharedPresenter.rootViewController.present(editor, animated: false)
        WPAppAnalytics.track(.editorCreatedPost, properties: [WPAppAnalyticsKeyTapSource: source, WPAppAnalyticsKeyPostType: "post"], blog: blog)
    }

    static func navigateToMediaLibrary(with userInfo: NSDictionary) {
        if let blog = blog(from: userInfo) {
            RootViewCoordinator.sharedPresenter.showBlogDetails(for: blog, then: .media)
        }
    }

    static func retryMediaUploads(with userInfo: NSDictionary) {
        let media = failedMedia(from: userInfo)
        media.forEach({ MediaCoordinator.shared.retryMedia($0) })
    }

    private static func blog(from userInfo: NSDictionary) -> Blog? {
        let context = ContextManager.shared.mainContext

        guard let blogID = userInfo[MediaNoticeUserInfoKey.blogID] as? String,
            let URIRepresentation = URL(string: blogID),
            let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URIRepresentation),
            let managedObject = try? context.existingObject(with: objectID),
            let blog = managedObject as? Blog else {
                return nil
        }

        return blog
    }

    private static func successfulMedia(from userInfo: NSDictionary) -> [Media] {
        return media(from: userInfo, withKey: MediaNoticeUserInfoKey.mediaIDs)
    }

    private static func failedMedia(from userInfo: NSDictionary) -> [Media] {
        return media(from: userInfo, withKey: MediaNoticeUserInfoKey.failedMediaIDs)
    }

    private static func media(from userInfo: NSDictionary, withKey key: String) -> [Media] {
        let context = ContextManager.shared.mainContext

        if let mediaIDs = userInfo[key] as? [String] {
            let media = mediaIDs.compactMap({ mediaID -> Media? in
                if let URIRepresentation = URL(string: mediaID),
                    let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: URIRepresentation),
                    let managedObject = try? context.existingObject(with: objectID),
                    let media = managedObject as? Media {
                    return media
                }

                return nil
            })

            return media
        }

        return []
    }
}
