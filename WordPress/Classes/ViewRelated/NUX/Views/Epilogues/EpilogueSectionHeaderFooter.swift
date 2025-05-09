import UIKit

class EpilogueSectionHeaderFooter: UITableViewHeaderFooterView, NibLoadable {
    static let identifier = "EpilogueSectionHeaderFooter"

    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet var titleLabel: UILabel?

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel?.textColor = .secondaryLabel
    }
}
