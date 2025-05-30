import UIKit
import WordPressUI

final class TitleBadgeDisclosureCell: UITableViewCell, NibLoadable {
    @IBOutlet weak var cellTitle: UILabel!
    @IBOutlet weak var cellBadge: BadgeLabel!

    private struct BadgeConstants {
        static let padding: CGFloat = 6.0
        static let radius: CGFloat = 9.0
        static let border: CGFloat = 1.0
    }

    var name: String? {
        didSet {
            cellTitle.text = name
        }
    }

    var count: Int = 0 {
        didSet {
            if count > 0 {
                cellBadge.text = String(count)
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        accessoryType = .disclosureIndicator
        accessoryView = nil

        customizeTagName()
        customizeTagCount()
    }

    private func customizeTagName() {
        cellTitle.font = .preferredFont(forTextStyle: .callout)
    }

    private func customizeTagCount() {
        cellBadge.font = .preferredFont(forTextStyle: .callout)
        cellBadge.textColor = UIAppColor.primary
        cellBadge.textAlignment = .center
        cellBadge.text = ""
        cellBadge.horizontalPadding = BadgeConstants.padding
        cellBadge.borderColor = UIAppColor.primary
        cellBadge.borderWidth = BadgeConstants.border
        cellBadge.cornerRadius = BadgeConstants.radius
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        cellTitle.text = ""
        cellBadge.text = ""
    }
}
