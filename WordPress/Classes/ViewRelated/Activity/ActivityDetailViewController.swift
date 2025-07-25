import UIKit
import Gridicons
import WordPressData
import WordPressKit
import WordPressUI

class ActivityDetailViewController: UIViewController, StoryboardLoadable {

    // MARK: - StoryboardLoadable Protocol

    static var defaultStoryboardName = defaultControllerID

    // MARK: - Properties

    var formattableActivity: FormattableActivity? {
        didSet {
            setupActivity()
            setupRouter()
        }
    }
    var site: JetpackSiteRef?

    var rewindStatus: RewindStatus?

    weak var presenter: ActivityPresenter?

    @IBOutlet private var imageView: CircularImageView!

    @IBOutlet private var roleLabel: UILabel!
    @IBOutlet private var nameLabel: UILabel!

    @IBOutlet private var timeLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!

    @IBOutlet weak var textView: UITextView! {
        didSet {
            textView.delegate = self
        }
    }

    @IBOutlet weak var jetpackBadgeView: UIView!

    //TODO: remove!
    @IBOutlet private var textLabel: UILabel!
    @IBOutlet private var summaryLabel: UILabel!

    @IBOutlet private var headerStackView: UIStackView!
    @IBOutlet private var rewindStackView: UIStackView!
    @IBOutlet private var backupStackView: UIStackView!
    @IBOutlet private var contentStackView: UIStackView!
    @IBOutlet private var containerView: UIView!

    @IBOutlet weak var warningButton: MultilineButton!

    @IBOutlet private var bottomConstaint: NSLayoutConstraint!

    @IBOutlet private var rewindButton: UIButton!
    @IBOutlet private var backupButton: UIButton!

    private var activity: Activity?

    var router: ActivityContentRouter?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLabelStyles()
        setupViews()
        setupText()
        setupAccesibility()
        hideRestoreIfNeeded()
        showWarningIfNeeded()
        WPAnalytics.track(.activityLogDetailViewed, withProperties: ["source": presentedFrom()])
    }

    @IBAction func rewindButtonTapped(sender: UIButton) {
        guard let activity else {
            return
        }
        presenter?.presentRestoreFor(activity: activity, from: "\(presentedFrom())/detail")
    }

    @IBAction func backupButtonTapped(sender: UIButton) {
        guard let activity else {
            return
        }
        presenter?.presentBackupFor(activity: activity, from: "\(presentedFrom())/detail")
    }

    @IBAction func warningTapped(_ sender: Any) {
        guard let url = URL(string: Constants.supportUrl) else {
            return
        }

        let navController = UINavigationController(rootViewController: WebViewControllerFactory.controller(url: url, source: "activity_detail_warning"))

        present(navController, animated: true)
    }

    private func setupLabelStyles() {
        nameLabel.textColor = .label
        nameLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote).pointSize,
                                           weight: .semibold)
        textLabel.textColor = .label
        summaryLabel.textColor = .secondaryLabel

        roleLabel.textColor = .secondaryLabel
        dateLabel.textColor = .secondaryLabel
        timeLabel.textColor = .secondaryLabel

        rewindButton.setTitleColor(UIAppColor.primary, for: .normal)
        rewindButton.setTitleColor(UIAppColor.primaryDark, for: .highlighted)

        backupButton.setTitleColor(UIAppColor.primary, for: .normal)
        backupButton.setTitleColor(UIAppColor.primaryDark, for: .highlighted)
    }

    private func setupViews() {
        guard let activity else {
            return
        }

        view.backgroundColor = .systemBackground
        containerView.backgroundColor = .systemBackground

        textLabel.isHidden = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        if activity.isRewindable {
            bottomConstaint.constant = 0
            rewindStackView.isHidden = false
            backupStackView.isHidden = false
        }

        if let avatar = activity.actor?.avatarURL, let avatarURL = URL(string: avatar) {
            imageView.backgroundColor = UIAppColor.neutral(.shade20)
            imageView.downloadImage(from: avatarURL, placeholderImage: .gridicon(.user, size: Constants.gridiconSize))
        } else if let iconType = WPStyleGuide.ActivityStyleGuide.getGridiconTypeForActivity(activity) {
            imageView.contentMode = .center
            imageView.backgroundColor = WPStyleGuide.ActivityStyleGuide.getColorByActivityStatus(activity)
            imageView.image = .gridicon(iconType, size: Constants.gridiconSize)
        } else {
            imageView.isHidden = true
        }

        rewindButton.naturalContentHorizontalAlignment = .leading
        rewindButton.setImage(.gridicon(.history, size: Constants.gridiconSize), for: .normal)

        backupButton.naturalContentHorizontalAlignment = .leading
        backupButton.setImage(.gridicon(.cloudDownload, size: Constants.gridiconSize), for: .normal)

        let attributedTitle = StringHighlighter.highlightString(RewindStatus.Strings.multisiteNotAvailableSubstring,
                                                                   inString: RewindStatus.Strings.multisiteNotAvailable)

        warningButton.setAttributedTitle(attributedTitle, for: .normal)
        warningButton.setTitleColor(.systemGray, for: .normal)
        warningButton.titleLabel?.numberOfLines = 0
        warningButton.titleLabel?.lineBreakMode = .byWordWrapping
        warningButton.naturalContentHorizontalAlignment = .leading
        warningButton.backgroundColor = view.backgroundColor
        setupJetpackBadge()
    }

    private func setupJetpackBadge() {
        guard JetpackBrandingVisibility.all.enabled else {
            return
        }
        jetpackBadgeView.isHidden = false
        let textProvider = JetpackBrandingTextProvider(screen: JetpackBadgeScreen.activityDetail)
        let jetpackBadgeButton = JetpackButton(style: .badge, title: textProvider.brandingText())
        jetpackBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        jetpackBadgeButton.addTarget(self, action: #selector(jetpackButtonTapped), for: .touchUpInside)
        jetpackBadgeView.addSubview(jetpackBadgeButton)
        NSLayoutConstraint.activate([
            jetpackBadgeButton.centerXAnchor.constraint(equalTo: jetpackBadgeView.centerXAnchor),
            jetpackBadgeButton.topAnchor.constraint(equalTo: jetpackBadgeView.topAnchor, constant: Constants.jetpackBadgeTopInset),
            jetpackBadgeButton.bottomAnchor.constraint(equalTo: jetpackBadgeView.bottomAnchor)
        ])
        jetpackBadgeView.backgroundColor = .systemGroupedBackground
    }

    @objc private func jetpackButtonTapped() {
        JetpackBrandingCoordinator.presentOverlay(from: self)
        JetpackBrandingAnalyticsHelper.trackJetpackPoweredBadgeTapped(screen: .activityDetail)
    }

    private func setupText() {
        guard let activity, let site else {
            return
        }

        title = NSLocalizedString("Event", comment: "Title for the activity detail view")
        nameLabel.text = activity.actor?.displayName
        roleLabel.text = activity.actor?.role.localizedCapitalized

        textView.attributedText = formattableActivity?.formattedContent(using: ActivityContentStyles())
        summaryLabel.text = activity.summary

        rewindButton.setTitle(NSLocalizedString("Restore", comment: "Title for button allowing user to restore their Jetpack site"),
                                                for: .normal)
        backupButton.setTitle(NSLocalizedString("Download backup", comment: "Title for button allowing user to backup their Jetpack site"),
                                                for: .normal)

        let dateFormatter = ActivityDateFormatting.longDateFormatter(for: site, withTime: false)
        dateLabel.text = dateFormatter.string(from: activity.published)

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        timeFormatter.timeZone = dateFormatter.timeZone

        timeLabel.text = timeFormatter.string(from: activity.published)
    }

    private func setupAccesibility() {
        guard let activity else {
            return
        }

        contentStackView.isAccessibilityElement = true
        contentStackView.accessibilityTraits = UIAccessibilityTraits.staticText
        contentStackView.accessibilityLabel = "\(activity.text), \(activity.summary)"
        textLabel.isAccessibilityElement = false
        summaryLabel.isAccessibilityElement = false

        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            headerStackView.axis = .vertical

            dateLabel.textAlignment = .center
            timeLabel.textAlignment = .center
        } else {
            headerStackView.axis = .horizontal

            if view.effectiveUserInterfaceLayoutDirection == .leftToRight {
                // swiftlint:disable:next inverse_text_alignment
                dateLabel.textAlignment = .right
                // swiftlint:disable:next inverse_text_alignment
                timeLabel.textAlignment = .right
            } else {
                // swiftlint:disable:next natural_text_alignment
                dateLabel.textAlignment = .left
                // swiftlint:disable:next natural_text_alignment
                timeLabel.textAlignment = .left
            }
        }
    }

    private func hideRestoreIfNeeded() {
        guard let isRestoreActive = rewindStatus?.isActive() else {
            return
        }

        rewindStackView.isHidden = !isRestoreActive
    }

    private func showWarningIfNeeded() {
        guard let isMultiSite = rewindStatus?.isMultisite() else {
            return
        }

        warningButton.isHidden = !isMultiSite
    }

    func setupRouter() {
        guard let activity = formattableActivity else {
            router = nil
            return
        }
        let coordinator = DefaultContentCoordinator(controller: self, context: ContextManager.shared.mainContext)
        router = ActivityContentRouter(
            activity: activity,
            coordinator: coordinator)
    }

    func setupActivity() {
        activity = formattableActivity?.activity
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            setupLabelStyles()
            setupAccesibility()
        }
    }

    private func presentedFrom() -> String {
        if presenter is JetpackActivityLogViewController {
            return "activity_log"
        } else if presenter is BackupListViewController {
            return "backup"
        } else if presenter is DashboardActivityLogCardCell {
            return "dashboard"
        } else {
            return "unknown"
        }
    }

    private enum Constants {
        static let gridiconSize: CGSize = CGSize(width: 24, height: 24)
        static let supportUrl = "https://jetpack.com/support/backup/"
        // the distance ought to be 30, and the stackView spacing is 16, thus the top inset is 14.
        static let jetpackBadgeTopInset: CGFloat = 14
    }
}

// MARK: - UITextViewDelegate

extension ActivityDetailViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        router?.routeTo(URL)
        return false
    }
}
