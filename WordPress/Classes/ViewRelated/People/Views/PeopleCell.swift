import UIKit
import WordPressShared
import WordPressUI
import Gravatar
import DesignSystem

class PeopleCell: WPTableViewCell {
    @IBOutlet private weak var avatarImageView: CircularImageView!
    @IBOutlet private weak var displayNameLabel: UILabel!
    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var roleBadge: PeopleRoleBadgeLabel!
    @IBOutlet private weak var superAdminRoleBadge: PeopleRoleBadgeLabel!
    @IBOutlet private weak var badgeStackView: UIStackView!

    override func awakeFromNib() {
        super.awakeFromNib()

        displayNameLabel.textColor = .label
        displayNameLabel.font = WPStyleGuide.fontForTextStyle(.callout, fontWeight: .medium)

        usernameLabel.textColor = .secondaryLabel
        usernameLabel.font = WPStyleGuide.fontForTextStyle(.footnote)

        separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        avatarImageView.image = UIImage(named: "gravatar")
    }

    func bindViewModel(_ viewModel: PeopleCellViewModel) {
        setAvatarURL(viewModel.avatarURL as URL?)
        displayNameLabel.text = viewModel.displayName
        displayNameLabel.textColor = viewModel.usernameColor
        usernameLabel.text = viewModel.usernameText
        usernameLabel.isHidden = viewModel.usernameHidden
        roleBadge.backgroundColor = viewModel.roleBackgroundColor
        roleBadge.textColor = viewModel.roleTextColor
        roleBadge.text = viewModel.roleText
        roleBadge.isHidden = viewModel.roleHidden
        superAdminRoleBadge.text = viewModel.superAdminText
        superAdminRoleBadge.isHidden = viewModel.superAdminHidden
        superAdminRoleBadge.backgroundColor = viewModel.superAdminBackgroundColor
        badgeStackView.isHidden = viewModel.roleHidden && viewModel.superAdminHidden
    }

    @objc func setAvatarURL(_ avatarURL: URL?) {
        let gravatar = avatarURL.flatMap { AvatarURL(url: $0) }
        let placeholder = UIImage(named: "gravatar")!
        avatarImageView.downloadGravatar(gravatar, placeholder: placeholder, animate: false)
    }

    /*
    It seems UIKit clears the background of all the cells' subviews when
    highlighted/selected, so he have to set our wanted color again.

    Otherwise we get this: https://cldup.com/NT3pbaeIc1.png
    */
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let roleBackgroundColor = roleBadge.backgroundColor
        let superAdminBackgroundColor = superAdminRoleBadge.backgroundColor

        super.setHighlighted(highlighted, animated: animated)

        if highlighted {
            roleBadge.backgroundColor = roleBackgroundColor
            superAdminRoleBadge.backgroundColor = superAdminBackgroundColor
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        let roleBackgroundColor = roleBadge.backgroundColor
        let superAdminBackgroundColor = superAdminRoleBadge.backgroundColor

        super.setSelected(selected, animated: animated)

        if selected {
            roleBadge.backgroundColor = roleBackgroundColor
            superAdminRoleBadge.backgroundColor = superAdminBackgroundColor
        }
    }
}