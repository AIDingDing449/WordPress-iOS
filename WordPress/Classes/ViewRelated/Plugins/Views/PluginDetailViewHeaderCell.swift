import UIKit
import Gridicons
import WordPressKit
import WordPressUI

class PluginDetailViewHeaderCell: UITableViewCell, NibLoadable {

    override func awakeFromNib() {
        super.awakeFromNib()
        nameLabel?.font = UIFontMetrics.default.scaledFont(for: nameLabel!.font)
    }

    open func configureCell(_ directoryEntry: PluginDirectoryEntry) {
        contentView.backgroundColor = .secondarySystemGroupedBackground

        if let banner = directoryEntry.banner {
            headerImageView?.isHidden = false
            headerImageView?.downloadImage(from: banner)
        } else {
            headerImageView?.isHidden = true
        }

        let iconPlaceholder = UIImage.gridicon(.plugins, size: CGSize(width: 40, height: 40))
        iconImageView?.downloadImage(from: directoryEntry.icon, placeholderImage: iconPlaceholder)
        iconImageView?.backgroundColor = .secondarySystemGroupedBackground
        iconImageView?.tintColor = UIAppColor.neutral(.shade50)

        nameLabel?.text = directoryEntry.name

        let author = directoryEntry.author

        let defaultAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.preferredFont(forTextStyle: .subheadline),
                                                               .foregroundColor: UIAppColor.neutral(.shade70)]

        let authorAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIAppColor.primary(.shade40)]

        let string = NSLocalizedString("by %@", comment: "Used when displaying author of a plugin.")
        let attrString = NSMutableAttributedString(string: String(format: string, author), attributes: defaultAttributes)

        attrString.addAttributes(authorAttributes, range: NSRange(attrString.string.range(of: author)!, in: attrString.string))

        authorButton?.setAttributedTitle(attrString, for: .normal)
    }

    @IBOutlet private var headerImageView: UIImageView?
    @IBOutlet private var iconImageView: UIImageView?
    @IBOutlet private var nameLabel: UILabel?
    @IBOutlet private var authorButton: UIButton?

    var onLinkTap: (() -> Void)?

    @IBAction func linkButtonTapped(_ sender: Any) {
        onLinkTap?()
    }

}

struct PluginHeaderRow: ImmuTableRow {
    typealias CellType = PluginDetailViewHeaderCell

    static let cell: ImmuTableCell = {
        return ImmuTableCell.nib(PluginDetailViewHeaderCell.defaultNib, CellType.self)
    }()

    let directoryEntry: PluginDirectoryEntry
    let action: ImmuTableAction? = nil
    let onLinkTap: () -> Void

    func configureCell(_ cell: UITableViewCell) {
        let cell = cell as! CellType

        cell.configureCell(directoryEntry)
        cell.onLinkTap = onLinkTap
        cell.selectionStyle = .none
    }
}
