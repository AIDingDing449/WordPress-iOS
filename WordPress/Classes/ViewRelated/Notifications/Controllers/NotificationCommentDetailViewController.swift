import UIKit
import WordPressData
import WordPressUI

class NotificationCommentDetailViewController: UIViewController, NoResultsViewHost {

    // MARK: - Properties

    private var notification: WordPressData.Notification {
        didSet {
            title = notification.title
        }
    }

    private var comment: Comment? {
        didSet {
            updateDisplayedComment()
        }
    }

    private var commentID: NSNumber? {
        notification.metaCommentID
    }

    private var detailsVC: CommentDetailViewController?

    private var blog: Blog? {
        guard let siteID = notification.metaSiteID else {
            return nil
        }
        return Blog.lookup(withID: siteID, in: managedObjectContext)
    }

    // If the user does not have permission to the Blog, it will be nil.
    // In this case, use the Post to obtain Comment information.
    private var post: ReaderPost?

    private weak var notificationDelegate: CommentDetailsNotificationDelegate?
    private let managedObjectContext = ContextManager.shared.mainContext

    private lazy var commentService = CommentService(coreDataStack: ContextManager.shared)
    private lazy var postService = ReaderPostService(coreDataStack: ContextManager.shared)

    // MARK: - Notification Navigation Buttons

    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(.gridicon(.arrowUp), for: .normal)
        button.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        button.accessibilityLabel = NSLocalizedString("Next notification", comment: "Accessibility label for the next notification button")
        return button
    }()

    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(.gridicon(.arrowDown), for: .normal)
        button.addTarget(self, action: #selector(previousButtonTapped), for: .touchUpInside)
        button.accessibilityLabel = NSLocalizedString("Previous notification", comment: "Accessibility label for the previous notification button")
        return button
    }()

    var previousButtonEnabled = false {
        didSet {
            previousButton.isEnabled = previousButtonEnabled
        }
    }

    var nextButtonEnabled = false {
        didSet {
            nextButton.isEnabled = nextButtonEnabled
        }
    }

    private let errorTitle = NSLocalizedString("Error loading the comment",
                                               comment: "Text displayed when there is a failure loading notification comments.")

    // MARK: - Init

    init(notification: WordPressData.Notification,
         notificationDelegate: CommentDetailsNotificationDelegate) {
        self.notification = notification
        self.notificationDelegate = notificationDelegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavBar()
        view.backgroundColor = .systemBackground
        loadComment()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureNavBarButtons()
    }

    func refreshViewController(notification: WordPressData.Notification) {
        self.notification = notification
        loadComment()
    }
}

private extension NotificationCommentDetailViewController {

    func configureNavBar() {
        title = notification.title
        // Empty Back Button
        navigationItem.backBarButtonItem = UIBarButtonItem(title: String(), style: .plain, target: nil, action: nil)
    }

    func configureNavBarButtons() {
        var barButtonItems: [UIBarButtonItem] = []

        if splitViewControllerIsHorizontallyCompact {
            barButtonItems.append(makeNavigationButtons())
        }

        if let comment, comment.allowsModeration(), let detailsVC {
            barButtonItems.append(detailsVC.editBarButtonItem)
        }

        navigationItem.setRightBarButtonItems(barButtonItems, animated: false)
    }

    func makeNavigationButtons() -> UIBarButtonItem {
        // Create custom view to match that in NotificationDetailsViewController.
        let buttonStackView = UIStackView(arrangedSubviews: [nextButton, previousButton])
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = Constants.arrowButtonSpacing

        let width = (Constants.arrowButtonSize * 2) + Constants.arrowButtonSpacing
        buttonStackView.frame = CGRect(x: 0, y: 0, width: width, height: Constants.arrowButtonSize)

        return UIBarButtonItem(customView: buttonStackView)
    }

    @objc func previousButtonTapped() {
        notificationDelegate?.previousNotificationTapped(current: notification)
    }

    @objc func nextButtonTapped() {
        notificationDelegate?.nextNotificationTapped(current: notification)
    }

    func updateDisplayedComment() {
        guard let comment else {
            return
        }

        if let detailsVC {
            detailsVC.refreshView(comment: comment, notification: notification)
        } else {
            let detailsVC = CommentDetailViewController(
                comment: comment,
                notification: notification,
                notificationDelegate: notificationDelegate,
                managedObjectContext: managedObjectContext
            )
            detailsVC.willMove(toParent: self)
            addChild(detailsVC)
            view.addSubview(detailsVC.view)
            detailsVC.view.pinEdges()
            detailsVC.didMove(toParent: self)
            setContentScrollView(detailsVC.tableView)
            self.detailsVC = detailsVC
        }

        self.configureNavBarButtons()
    }

    func loadComment() {
        showLoadingView()

        loadPostIfNeeded(completion: { [weak self] in
            guard let self else {
                return
            }

            self.fetchParentCommentIfNeeded(completion: {
                if let comment = self.loadCommentFromCache(self.commentID) {
                    self.comment = comment
                    return
                }
                self.fetchComment(self.commentID, completion: { comment in
                    guard let comment else {
                        self.showErrorView(title: NoResults.errorTitle, subtitle: NoResults.errorSubtitle)
                        return
                    }
                    self.comment = comment
                }, failure: { error in
                    self.showErrorView(error: error)
                })
            }, failure: { error in
                self.showErrorView(error: error)
            })
        })
    }

    private func showErrorView(error: Error?) {
        let errorMessage: String? = {
            guard let error = error as? NSError,
                  error.domain == WordPressComRestApiEndpointError.errorDomain,
                  error.code == WordPressComRestApiErrorCode.authorizationRequired.rawValue else {
                return nil
            }
            return Strings.fetchCommentDetailsFromPrivateBlogErrorMessage
        }()
        self.showErrorView(title: self.errorTitle, subtitle: errorMessage)
    }

    func loadPostIfNeeded(completion: @escaping () -> Void) {

        // The post is only needed if there is no Blog.
        guard blog == nil,
              let postID = notification.metaPostID,
              let siteID = notification.metaSiteID else {
                  completion()
                  return
              }

        if let post = try? ReaderPost.lookup(withID: postID, forSiteWithID: siteID, in: managedObjectContext) {
            self.post = post
            completion()
            return
        }

        postService.fetchPost(postID.uintValue,
                              forSite: siteID.uintValue,
                              isFeed: false,
                              success: { [weak self] post in
            self?.post = post
            completion()
        }, failure: { [weak self] _ in
            self?.post = nil
            completion()
        })
    }

    func loadCommentFromCache(_ commentID: NSNumber?) -> Comment? {
        guard let commentID else {
            DDLogError("Notification Comment: unable to load comment due to missing commentID.")
            return nil
        }

        if let blog {
            return blog.comment(withID: commentID)
        }

        if let post {
            return post.comment(withID: commentID)
        }

        return nil
    }

    func fetchComment(_ commentID: NSNumber?, completion: @escaping (Comment?) -> Void, failure: @escaping (Error?) -> Void) {
        guard let commentID else {
            DDLogError("Notification Comment: unable to fetch comment due to missing commentID.")
            failure(nil)
            return
        }

        if let blog {
            commentService.loadComment(withID: commentID, for: blog, success: { comment in
                completion(comment)
            }, failure: { error in
                failure(error)
            })
            return
        }

        if let post {
            commentService.loadComment(withID: commentID, for: post, success: { comment in
                completion(comment)
            }, failure: { error in
                failure(error)
            })
            return
        }

        completion(nil)
    }

    func fetchParentCommentIfNeeded(completion: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        // If the comment has a parent and it is not cached, fetch it so the details header is correct.
        guard let parentID = notification.metaParentID,
              loadCommentFromCache(parentID) == nil else {
                  completion()
                  return
              }

        fetchComment(parentID, completion: { _ in completion() }, failure: { failure($0) })
    }

    struct Constants {
        static let arrowButtonSize: CGFloat = 24
        static let arrowButtonSpacing: CGFloat = 12
    }

    // MARK: - No Results Views

    func showLoadingView() {
        if let detailsVC {
            detailsVC.showNoResultsView(title: NoResults.loadingTitle, accessoryView: NoResultsViewController.loadingAccessoryView())
        } else {
            hideNoResults()
            configureAndDisplayNoResults(on: view, title: NoResults.loadingTitle, accessoryView: NoResultsViewController.loadingAccessoryView())
        }
    }

    func showErrorView(title: String, subtitle: String?) {
        if let detailsVC {
            detailsVC.showNoResultsView(title: title, subtitle: subtitle, imageName: NoResults.imageName)
        } else {
            hideNoResults()
            configureAndDisplayNoResults(on: view, title: title, subtitle: subtitle, image: NoResults.imageName)
        }
    }

    struct NoResults {
        static let loadingTitle = NSLocalizedString("Loading comment...", comment: "Displayed while a comment is being loaded.")
        static let errorTitle = NSLocalizedString("Oops", comment: "Title for the view when there's an error loading a comment.")
        static let errorSubtitle = NSLocalizedString("There was an error loading the comment.", comment: "Text displayed when there is a failure loading a comment.")
        static let imageName = "wp-illustration-notifications"
    }

    struct Strings {
        static let fetchCommentDetailsFromPrivateBlogErrorMessage = NSLocalizedString(
            "notificationCommentDetailViewController.commentDetails.privateBlogErrorMessage",
            value: "You don't have permission to view this private blog.",
            comment: "Error message that informs comment details from a private blog cannot be fetched."
        )
    }

}
