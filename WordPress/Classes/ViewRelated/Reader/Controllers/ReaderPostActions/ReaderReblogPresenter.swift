import UIKit
import WordPressData
import WordPressUI

/// Presents the appropriate reblog scene, depending on the number of available sites
class ReaderReblogPresenter {
    private let postService: PostService

    private struct NoSitesConfiguration {
        static let noSitesTitle = NSLocalizedString(
            "reader.reblog.no.blogs.title",
            value: "No available WordPress.com blogs",
            comment: "A short message that informs the user no WordPress.com blogs could be found."
        )
        static let noSitesSubtitle = NSLocalizedString(
            "reader.reblog.no.blogs.subtitle",
            value: "Once you create a WordPress.com blog, you can reblog content that you like to your own blog.",
            comment: "A subtitle with more detailed info for the user when no WordPress.com blogs could be found."
        )
        static let manageSitesLabel = NSLocalizedString(
            "reader.reblog.manage.blogs",
            value: "Manage Blogs",
            comment: "Button title. Tapping lets the user manage the blogs they follow."
        )
        static let backButtonTitle = NSLocalizedString("Back",
                                                       comment: "Back button title.")
    }

    init(postService: PostService? = nil) {

        // fallback for self.postService
        func makePostService() -> PostService {
            let context = ContextManager.shared.mainContext
            return PostService(managedObjectContext: context)
        }
        self.postService = postService ?? makePostService()
    }

    /// Presents the reblog screen(s)
    func presentReblog(coreDataStack: CoreDataStack,
                       readerPost: ReaderPost,
                       origin: UIViewController) {
        let context = coreDataStack.mainContext
        let blogCount = BlogQuery().hostedByWPCom(true).count(in: context)

        switch blogCount {
        case 0:
            presentNoSitesScene(origin: origin)
        case 1:
            guard let blog = try? BlogQuery().hostedByWPCom(true).blog(in: context) else {
                return
            }
            presentEditor(with: readerPost, blog: blog, origin: origin)
        default:
            presentBlogPicker(from: origin,
                              coreDataStack: coreDataStack,
                              readerPost: readerPost)
        }
    }
}

// MARK: - Blog Picker
private extension ReaderReblogPresenter {
    /// presents the blog picker before the editor, for users with multiple sites
    func presentBlogPicker(from origin: UIViewController,
                           coreDataStack: CoreDataStack,
                           readerPost: ReaderPost) {

        let configuration = BlogListConfiguration(shouldHideSelfHostedSites: true)
        let sitePickerViewController = SitePickerHostingController(configuration: configuration) { seletedBlog in
            origin.dismiss(animated: true) {
                self.presentEditor(with: readerPost, blog: seletedBlog, origin: origin)
            }
        }
        origin.present(sitePickerViewController, animated: true)
    }

    /// returns an AdaptiveNavigationController with preconfigured modal presentation style
    func getNavigationController(_ controller: UIViewController) -> AdaptiveNavigationController {
        let navigationController = AdaptiveNavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .automatic
        return navigationController
    }
}

// MARK: - Post Editor
private extension ReaderReblogPresenter {
    /// presents the post editor when users have at least one blog site.
    func presentEditor(with readerPost: ReaderPost,
                               blog: Blog,
                               origin: UIViewController) {

        // get post and put content in it
        let post = blog.createDraftPost()
        // size used for photon url. Set height to 0 will preserve aspect ratio
        let photonSize = CGSize(width: min(origin.view.frame.width,
                                           origin.view.frame.height),
                                height: 0)

        post.prepareForReblog(with: readerPost, imageSize: photonSize)
        // instantiate & configure editor
        let editor = EditPostViewController(post: post)
        editor.modalPresentationStyle = .fullScreen
        editor.postIsReblogged = true
        // present
        origin.present(editor, animated: false)
    }
}

// MARK: - No Sites
private extension ReaderReblogPresenter {
    /// presents the no sites screen, with related actions
    func presentNoSitesScene(origin: UIViewController) {
        let controller = NoResultsViewController.controllerWith(title: NoSitesConfiguration.noSitesTitle,
                                                                buttonTitle: NoSitesConfiguration.manageSitesLabel,
                                                                subtitle: NoSitesConfiguration.noSitesSubtitle)
        controller.showDismissButton(title: NoSitesConfiguration.backButtonTitle)

        controller.actionButtonHandler = { [weak origin] in
            guard let tabBarController = origin?.tabBarController as? WPTabBarController else {
                return
            }
            controller.dismiss(animated: true) {
                tabBarController.showMySitesTab()
            }
        }

        controller.dismissButtonHandler = {
            controller.dismiss(animated: true)
        }

        let navigationController = getNavigationController(controller)
        origin.present(navigationController, animated: true)
    }
}

// MARK: - Post updates
private extension Post {
    /// Formats the new Post content for reblogging, using an existing ReaderPost
    /// Uses the passed imageSize to obtain a Photon URL for the featured image
    func prepareForReblog(with readerPost: ReaderPost, imageSize: CGSize) {
        // update the post
        update(with: readerPost)
        // initialize the content
        var content = String()
        // add the quoted summary to the content, if it exists
        if let summary = readerPost.summary {
            var citation: String?
            // add the optional citation
            if let permaLink = readerPost.permaLink, let title = readerPost.titleForDisplay() {
                citation = ReaderReblogFormatter.hyperLink(url: permaLink, text: title)
            }
            content = self.blog.isGutenbergEnabled ? ReaderReblogFormatter.gutenbergQuote(text: summary, citation: citation) :
                ReaderReblogFormatter.aztecQuote(text: summary, citation: citation)
        }
        // insert the image on top of the content
        if let image = readerPost.featuredImage,
            image.isValidURL(),
            let cdnImage = PhotonImageURLHelper.photonURL(with: imageSize,
                                                          forImageURL: URL(string: image)) {

            content = self.blog.isGutenbergEnabled ? ReaderReblogFormatter.gutenbergImage(image: cdnImage.absoluteString) + content :
                ReaderReblogFormatter.aztecImage(image: cdnImage.absoluteString) + content
        }
        self.content = content
    }

    func update(with readerPost: ReaderPost) {
        self.postTitle = readerPost.titleForDisplay()
        self.pathForDisplayImage = readerPost.featuredImage
        self.permaLink = readerPost.permaLink
    }
}
