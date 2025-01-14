import UIKit

class RevisionsNavigationController: UINavigationController {
    var revisionState: RevisionBrowserState? {
        didSet {
            setupForBrowserState()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground // important as the content view go below it
    }

    private func setupForBrowserState() {
        guard let revisionView = viewControllers.first as? RevisionDiffsBrowserViewController else {
            return
        }

        revisionView.revisionState = revisionState
    }
}
