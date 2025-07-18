import Foundation
import SwiftUI
import WordPressData
import WordPressFlux
import WordPressShared

extension SiteSettingsViewController {
    // MARK: - General

    @objc public func showPrivacySelector() {
        struct SiteSettingsPrivacyPicker: View {
            let blog: Blog
            @State var selection: SiteVisibility
            let onChange: (SiteVisibility) -> Void

            var body: some View {
                SettingsPickerListView(selection: $selection, values: SiteVisibility.eligiblePickerValues(for: blog))
                    .onChange(of: selection, perform: onChange)
            }
        }
        let view = SiteSettingsPrivacyPicker(blog: blog, selection: blog.siteVisibility) { [weak self] in
            guard let self, self.blog.siteVisibility != $0 else { return }
            self.blog.siteVisibility = $0
            self.saveSettings()
            self.trackSettingsChange(fieldName: "site_settings", value: $0.rawValue)
        }
        let viewController = UIHostingController(rootView: view)
        viewController.title = Strings.privacyTitle
        navigationController?.pushViewController(viewController, animated: true)
    }

    @objc(showStartOverForBlog:)
    public func showStartOver(for blog: Blog) {
       wpAssert(blog.supportsSiteManagementServices())

       WPAppAnalytics.track(.siteSettingsStartOverAccessed, blog: blog)

       if SupportConfiguration.isStartOverSupportEnabled && blog.hasPaidPlan {
           let startOverVC = StartOverViewController(blog: blog)
           navigationController?.pushViewController(startOverVC, animated: true)
       } else {
           guard let targetURL = Constants.emptySiteSupportURL else { return }

           let webVC = WebViewControllerFactory.controller(url: targetURL, source: "site_settings_start_over")
           let navigationVC = UINavigationController(rootViewController: webVC)
           present(navigationVC, animated: true, completion: nil)
       }
    }

    @objc public func showTagList() {
        let tagsVC = SiteTagsViewController(blog: blog)
        navigationController?.pushViewController(tagsVC, animated: true)
    }

    // MARK: - Timezone

    func formattedTimezoneValue() -> String? {
        guard let settings = blog.settings else {
            return nil
        }
        if let timezoneString = settings.timezoneString?.nonEmptyString() {
            // Try to get a localized name from the system
            if let timeZone = TimeZone(identifier: timezoneString),
               let name = timeZone.localizedName(for: .generic, locale: .current) {

                let formatter = DateFormatter()
                formatter.timeZone = timeZone
                formatter.dateFormat = "ZZZZ"  // "GMT-05:00"
                let offsetString = formatter.string(from: Date())

                return "\(name) (\(offsetString))"
            }
            return timezoneString
        }
        return timezoneValue
    }

    var timezoneValue: String? {
        if let timezoneString = blog.settings?.timezoneString?.nonEmptyString() {
            return timezoneString
        } else if let gmtOffset = blog.settings?.gmtOffset {
            return OffsetTimeZone(offset: gmtOffset.floatValue).label
        } else {
            return nil
        }
    }

    // MARK: - Homepage Settings

    @objc public var homepageSettingsCell: SettingTableViewCell? {
        let cell = SettingTableViewCell(label: NSLocalizedString("Homepage Settings", comment: "Label for Homepage Settings site settings section"), editable: true, reuseIdentifier: nil)
        cell?.textValue = blog.homepageType?.title
        return cell
    }

    // MARK: - Navigation

    @objc(showHomepageSettingsForBlog:)
    public func showHomepageSettings(for blog: Blog) {
        let settingsViewController = HomepageSettingsViewController(blog: blog)
        navigationController?.pushViewController(settingsViewController, animated: true)
    }

    @objc public func showTimezoneSelector() {
        let view = TimeZoneSelectorView(selectedValue: timezoneValue) { [weak self] newValue in
            self?.blog.settings?.gmtOffset = newValue.gmtOffset as NSNumber?
            self?.blog.settings?.timezoneString = newValue.timezoneString
            self?.saveSettings()
            self?.trackSettingsChange(fieldName: "timezone",
                                      value: newValue.value as Any)
        }
        let controller = UIHostingController(rootView: view)
        navigationController?.pushViewController(controller, animated: true)
    }

    @objc public func showDateAndTimeFormatSettings() {
        let dateAndTimeFormatViewController = DateAndTimeFormatSettingsViewController(blog: blog)
        navigationController?.pushViewController(dateAndTimeFormatViewController, animated: true)
    }

    @objc public func showPostPerPageSetting() {
        let pickerViewController = SettingsPickerViewController(style: .insetGrouped)
        pickerViewController.title = NSLocalizedString("Posts per Page", comment: "Posts per Page Title")
        pickerViewController.switchVisible = false
        pickerViewController.selectionText = NSLocalizedString("The number of posts to show per page.",
                                                               comment: "Text above the selection of the number of posts to show per blog page")
        pickerViewController.pickerFormat = NSLocalizedString("%d posts", comment: "Number of posts")
        pickerViewController.pickerMinimumValue = minNumberOfPostPerPage
        if let currentValue = blog.settings?.postsPerPage as? Int {
            pickerViewController.pickerSelectedValue = currentValue
            pickerViewController.pickerMaximumValue = max(currentValue, maxNumberOfPostPerPage)
        } else {
            pickerViewController.pickerMaximumValue = maxNumberOfPostPerPage
        }
        pickerViewController.onChange = { [weak self] (enabled: Bool, newValue: Int) in
            self?.blog.settings?.postsPerPage = newValue as NSNumber?
            self?.saveSettings()
            self?.trackSettingsChange(fieldName: "posts_per_page", value: newValue as Any)
        }

        navigationController?.pushViewController(pickerViewController, animated: true)
    }

    @objc public func showSpeedUpYourSiteSettings() {
        let speedUpSiteSettingsViewController = JetpackSpeedUpSiteSettingsViewController(blog: blog)
        navigationController?.pushViewController(speedUpSiteSettingsViewController, animated: true)
    }

    @objc public func showRelatedPostsSettings() {
        let view = RelatedPostsSettingsView(blog: blog)
        let host = UIHostingController(rootView: view)
        host.title = view.title // Make sure title is available before push
        navigationController?.pushViewController(host, animated: true)
    }

    // MARK: Footers

    @objc(getTrafficSettingsSectionFooterView)
    public func trafficSettingsSectionFooterView() -> UIView {
        let footer = makeFooterView()
        footer.textLabel?.text = NSLocalizedString("Your WordPress.com site supports the use of Accelerated Mobile Pages, a Google-led initiative that dramatically speeds up loading times on mobile devices.",
                                                   comment: "Footer for AMP Traffic Site Setting, should match Calypso.")
        footer.textLabel?.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleAMPFooterTap(_:)))
        footer.addGestureRecognizer(tap)
        return footer
    }

    @objc(getEditorSettingsSectionFooterView)
    public func editorSettingsSectionFooterView() -> UIView {
        let footer = makeFooterView()
        footer.textLabel?.text = NSLocalizedString("Edit new posts and pages with the block editor.", comment: "Explanation for the option to enable the block editor")
        return footer
    }

    private func makeFooterView() -> UITableViewHeaderFooterView {
        let footer = UITableViewHeaderFooterView()
        footer.textLabel?.numberOfLines = 0
        footer.textLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        return footer
    }

    @objc fileprivate func handleAMPFooterTap(_ sender: UITapGestureRecognizer) {
        guard let url = URL(string: self.ampSupportURL) else {
            return
        }
        let webViewController = WebViewControllerFactory.controller(url: url, source: "site_settings_amp_footer")

        if presentingViewController != nil {
            navigationController?.pushViewController(webViewController, animated: true)
        } else {
            let navController = UINavigationController(rootViewController: webViewController)
            present(navController, animated: true)
        }
    }

    override open func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        WPStyleGuide.configureTableViewSectionFooter(view)
    }

    // MARK: Private Properties

    fileprivate var minNumberOfPostPerPage: Int { return 1 }
    fileprivate var maxNumberOfPostPerPage: Int { return 1000 }
    fileprivate var ampSupportURL: String { return "https://support.wordpress.com/amp-accelerated-mobile-pages/" }

}

// MARK: - General Settings Table Section Management

extension SiteSettingsViewController {

    enum GeneralSettingsRow {
        case title
        case tagline
        case url
        case privacy
        case language
        case timezone
    }

    var generalSettingsRows: [GeneralSettingsRow] {
        var rows: [GeneralSettingsRow] = [.title, .tagline, .url]

        if blog.supportsSiteManagementServices() {
            rows.append(contentsOf: [.privacy, .language])
        }

        if blog.supports(.wpComRESTAPI) {
            rows.append(.timezone)
        }

        return rows
    }

    @objc
    public var generalSettingsRowCount: Int {
        generalSettingsRows.count
    }

    @objc
    public func tableView(_ tableView: UITableView, cellForGeneralSettingsInRow row: Int) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCellReuseIdentifier) as! SettingTableViewCell

        switch generalSettingsRows[row] {
        case .title:
            configureCellForTitle(cell)
        case .tagline:
            configureCellForTagline(cell)
        case .url:
            configureCellForURL(cell)
        case .privacy:
            configureCellForPrivacy(cell)
        case .language:
            configureCellForLanguage(cell)
        case .timezone:
            configureCellForTimezone(cell)
        }

        return cell
    }

    @objc
    public func tableView(_ tableView: UITableView, didSelectInGeneralSettingsAt indexPath: IndexPath) {
        switch generalSettingsRows[indexPath.row] {
        case .title where blog.isAdmin:
            showEditSiteTitleController(indexPath: indexPath)
        case .tagline where blog.isAdmin:
            showEditSiteTaglineController(indexPath: indexPath)
        case .privacy where blog.isAdmin:
            showPrivacySelector()
        case .language where blog.isAdmin:
            showLanguageSelector(for: blog)
        case .timezone where blog.isAdmin:
            showTimezoneSelector()
        default:
            break
        }
    }

    // MARK: - Cell Configuration

    private func configureCellForTitle(_ cell: SettingTableViewCell) {
        let name = blog.settings?.name ?? NSLocalizedString("A title for the site", comment: "Placeholder text for the title of a site")

        cell.editable = blog.isAdmin
        cell.textLabel?.text = NSLocalizedString("Site Title", comment: "Label for site title blog setting")
        cell.textValue = name
    }

    private func configureCellForTagline(_ cell: SettingTableViewCell) {
        let tagline = blog.settings?.tagline ?? NSLocalizedString("Explain what this site is about.", comment: "Placeholder text for the tagline of a site")

        cell.editable = blog.isAdmin
        cell.textLabel?.text = NSLocalizedString("Tagline", comment: "Label for tagline blog setting")
        cell.textValue = tagline
    }

    private func configureCellForURL(_ cell: SettingTableViewCell) {
        let url: String = {
            guard let url = blog.url else {
                return NSLocalizedString("http://my-site-address (URL)", comment: "(placeholder) Help the user enter a URL into the field")
            }

            return url
        }()

        cell.editable = false
        cell.textLabel?.text = NSLocalizedString("Address", comment: "Label for url blog setting")
        cell.textValue = url
    }

    private func configureCellForPrivacy(_ cell: SettingTableViewCell) {
        cell.editable = blog.isAdmin
        cell.textLabel?.text = NSLocalizedString("Privacy", comment: "Label for the privacy setting")
        cell.textValue = blog.siteVisibility.localizedTitle
    }

    private func configureCellForLanguage(_ cell: SettingTableViewCell) {
        let name: String

        if let languageId = blog.settings?.languageID.intValue {
            name = WordPressComLanguageDatabase().nameForLanguageWithId(languageId)
        } else {
            // Since the settings can be nil, we need to handle the scenario... but it
            // really should not be possible to reach this line.
            name = NSLocalizedString("Undefined", comment: "When the App can't figure out what language a blog is configured to use.")
        }

        cell.editable = blog.isAdmin
        cell.textLabel?.text = NSLocalizedString("Language", comment: "Label for the privacy setting")
        cell.textValue = name
    }

    private func configureCellForTimezone(_ cell: SettingTableViewCell) {
        cell.editable = blog.isAdmin
        cell.textLabel?.text = NSLocalizedString("Time Zone", comment: "Label for the timezone setting")
        cell.textValue = formattedTimezoneValue()
    }

    // MARK: - Handling General Setting Cell Taps

    private func showEditSiteTitleController(indexPath: IndexPath) {
        guard blog.isAdmin else {
            return
        }

        let siteTitleViewController = SettingsTextViewController(
            text: blog.settings?.name ?? "",
            placeholder: NSLocalizedString("A title for the site", comment: "Placeholder text for the title of a site"),
            hint: "")

        siteTitleViewController.title = NSLocalizedString("Site Title", comment: "Title for screen that show site title editor")
        siteTitleViewController.onValueChanged = { [weak self] value in
            guard let self,
                  let cell = self.tableView.cellForRow(at: indexPath) else {
                // No need to update anything if the cell doesn't exist.
                return
            }

            cell.detailTextLabel?.text = value

            if value != self.blog.settings?.name {
                self.blog.settings?.name = value
                self.saveSettings()

                self.trackSettingsChange(fieldName: "site_title")
            }
        }

        self.navigationController?.pushViewController(siteTitleViewController, animated: true)
    }

    private func showEditSiteTaglineController(indexPath: IndexPath) {
        guard blog.isAdmin else {
            return
        }

        let siteTaglineViewController = SettingsTextViewController(
            text: blog.settings?.tagline ?? "",
            placeholder: NSLocalizedString("Explain what this site is about.", comment: "Placeholder text for the tagline of a site"),
            hint: NSLocalizedString("In a few words, explain what this site is about.", comment: "Explain what is the purpose of the tagline"))

        siteTaglineViewController.title = NSLocalizedString("Tagline", comment: "Title for screen that show tagline editor")
        siteTaglineViewController.onValueChanged = { [weak self] value in
            guard let self,
                  let cell = self.tableView.cellForRow(at: indexPath) else {
                // No need to update anything if the cell doesn't exist.
                return
            }

            let normalizedTagline = value.trimmingCharacters(in: .whitespacesAndNewlines)
            cell.detailTextLabel?.text = normalizedTagline

            if normalizedTagline != self.blog.settings?.tagline {
                self.blog.settings?.tagline = normalizedTagline
                self.saveSettings()

                self.trackSettingsChange(fieldName: "tagline")
            }
        }

        self.navigationController?.pushViewController(siteTaglineViewController, animated: true)
    }

    func trackSettingsChange(fieldName: String, value: Any? = nil) {
        WPAnalytics.trackSettingsChange("site_settings",
                                        fieldName: fieldName,
                                        value: value)
    }

}

private extension SiteSettingsViewController {
    enum Strings {
        static let privacyTitle = NSLocalizedString("siteSettings.privacy.title", value: "Privacy", comment: "Title for screen to select the privacy options for a blog")
    }
}

private enum Constants {
    static let emptySiteSupportURL = URL(string: "https://en.support.wordpress.com/empty-site")
}
