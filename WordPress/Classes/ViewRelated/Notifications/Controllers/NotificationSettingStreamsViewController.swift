import UIKit
import WordPressShared
import WordPressUI

/// This class will simply render the collection of Streams available for a given NotificationSettings
/// collection.
/// A Stream represents a possible way in which notifications are communicated.
/// For instance: Push Notifications / WordPress.com Timeline / Email
///
class NotificationSettingStreamsViewController: UITableViewController {

    // MARK: - Private Properties

    /// NotificationSettings being rendered
    ///
    private var settings: NotificationSettings?

    /// Notification Streams
    ///
    private var sortedStreams: [NotificationSettings.Stream]?

    /// Indicates whether push notifications have been disabled, in the device, or not.
    ///
    private var pushNotificationsAuthorized = true {
        didSet {
            tableView.reloadData()
        }
    }

    /// TableViewCell's Reuse Identifier
    ///
    private let reuseIdentifier = WPTableViewCell.classNameWithoutNamespaces()

    /// Number of Sections
    ///
    private let emptySectionCount = 0

    /// Number of Rows
    ///
    private let rowsCount = 1

    convenience init(settings: NotificationSettings) {
        self.init(style: .insetGrouped)
        setupWithSettings(settings)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        startListeningToNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.deselectSelectedRowWithAnimation(true)
        refreshPushAuthorizationStatus()

        WPAnalytics.track(.openedNotificationSettingStreams)
    }

    // MARK: - Setup Helpers
    private func startListeningToNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(refreshPushAuthorizationStatus), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    private func setupTableView() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: String(), style: .plain, target: nil, action: nil)
    }

    // MARK: - Public Helpers
    func setupWithSettings(_ streamSettings: NotificationSettings) {
        // Title
        switch streamSettings.channel {
        case let .blog(blogId):
            _ = blogId
            title = streamSettings.blog?.settings?.name ?? streamSettings.channel.description()
        case .other:
            title = NSLocalizedString("Other Sites", comment: "Other Notifications Streams Title")
        default:
            // Note: WordPress.com is not expected here!
            break
        }

        // Structures
        settings = streamSettings
        sortedStreams = streamSettings.streams.sorted {  $0.kind.description() > $1.kind.description() }

        tableView.reloadData()
    }

    // MARK: - UITableView Delegate Methods
    override func numberOfSections(in tableView: UITableView) -> Int {
        sortedStreams?.count ?? emptySectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowsCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? WPTableViewCell
        if cell == nil {
            cell = WPTableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
        }

        configureCell(cell!, indexPath: indexPath)

        return cell!
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return footerForStream(streamAtSection(section))
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        WPStyleGuide.configureTableViewSectionFooter(view)
    }

    // MARK: - UITableView Delegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stream = streamAtSection(indexPath.section)
        let detailsViewController = NotificationSettingDetailsViewController(settings: settings!, stream: stream)
        navigationController?.pushViewController(detailsViewController, animated: true)
    }

    // MARK: - Helpers
    private func configureCell(_ cell: UITableViewCell, indexPath: IndexPath) {
        let stream = streamAtSection(indexPath.section)
        let disabled = stream.kind == .device && pushNotificationsAuthorized == false

        cell.imageView?.image = imageForStreamKind(stream.kind)
        cell.imageView?.tintColor = UIAppColor.neutral(.shade20)
        cell.textLabel?.text = stream.kind.description()
        cell.detailTextLabel?.text = disabled ? NSLocalizedString("Off", comment: "Disabled") : String()
        cell.accessoryType = .disclosureIndicator

        WPStyleGuide.configureTableViewCell(cell)
    }

    private func streamAtSection(_ section: Int) -> NotificationSettings.Stream {
        return sortedStreams![section]
    }

    private func imageForStreamKind(_ streamKind: NotificationSettings.Stream.Kind) -> UIImage? {
        let imageName: String
        switch streamKind {
        case .email:
            imageName = "wpl-mail"
        case .timeline:
            imageName = "wpl-bell"
        case .device:
            imageName = "wpl-phone"
        }

        return UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Disabled Push Notifications Helpers
    @objc func refreshPushAuthorizationStatus() {
        PushNotificationsManager.shared.loadAuthorizationStatus { authorized in
            self.pushNotificationsAuthorized = authorized == .authorized
        }
    }

    // MARK: - Footers
    private func footerForStream(_ stream: NotificationSettings.Stream) -> String {
        switch stream.kind {
        case .device:
            return NSLocalizedString("Settings for push notifications that appear on your mobile device.",
                comment: "Descriptive text for the Push Notifications Settings")
        case .email:
            return NSLocalizedString("Settings for notifications that are sent to the email tied to your account.",
                comment: "Descriptive text for the Email Notifications Settings")
        case .timeline:
            return NSLocalizedString("Settings for notifications that appear in the Notifications tab.",
                comment: "Descriptive text for the Notifications Tab Settings")
        }
    }
}
