import WordPressData

protocol RevisionsView: AnyObject {
    func stopLoading(success: Bool, error: Error?)
}

final class ShowRevisionsListManger {
    let context = ContextManager.shared.mainContext

    private var isLoading = false
    private weak var revisionsView: RevisionsView?
    private let post: AbstractPost?
    private lazy var postService: PostService = {
        return PostService(managedObjectContext: context)
    }()

    init(post: AbstractPost?, attach revisionsView: RevisionsView?) {
        self.post = post
        self.revisionsView = revisionsView
    }

    func getRevisions() {
        guard let post else {
            return
        }

        if isLoading {
            return
        }

        isLoading = true

        postService.getPostRevisions(for: post, success: { [weak self] in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.revisionsView?.stopLoading(success: true, error: nil)
            }
        }) { [weak self] error in
            self?.isLoading = false
            self?.revisionsView?.stopLoading(success: false, error: error)
        }
    }
}
