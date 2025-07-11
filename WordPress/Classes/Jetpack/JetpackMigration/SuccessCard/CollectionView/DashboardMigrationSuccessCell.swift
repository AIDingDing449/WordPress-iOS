import UIKit
import WordPressData

class DashboardMigrationSuccessCell: UICollectionViewCell, Reusable {

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let view = MigrationSuccessCardView() {
            self.onTap?()
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)
        contentView.pinSubviewToAllEdges(view)
    }

    func configure(with viewController: UIViewController) {
        self.onTap = { [weak viewController] in
            guard let viewController else {
                return
            }
            let handler = MigrationSuccessActionHandler()
            handler.showDeleteWordPressOverlay(with: viewController)
        }
    }
}

extension DashboardMigrationSuccessCell: BlogDashboardCardConfigurable {
    func configure(blog: Blog, viewController: BlogDashboardViewController?, apiResponse: BlogDashboardRemoteEntity?) {

    }
}
