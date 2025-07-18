import UIKit
import CoreData
import Combine
import WordPressData
import WordPressKit
import WordPressShared
import WordPressUI
import SwiftUI

final class PostSettingsViewController: UIHostingController<AnyView> {
    private let viewModel: PostSettingsViewModel

    init(viewModel: PostSettingsViewModel) {
        self.viewModel = viewModel
        let postSettingsView = PostSettingsView(viewModel: viewModel)
        super.init(rootView: AnyView(postSettingsView))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.navigationTitle

        viewModel.onDismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true)
        }

        // Set the view controller reference for navigation
        // This is temporary until we can fully migrate to SwiftUI navigation
        viewModel.viewController = self
    }

    @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func showStandaloneEditor(for post: AbstractPost, from presentingVC: UIViewController) {
        let viewModel = PostSettingsViewModel(post: post, isStandalone: true)
        let postSettingsVC = PostSettingsViewController(viewModel: viewModel)
        let navigation = UINavigationController(rootViewController: postSettingsVC)
        presentingVC.present(navigation, animated: true)
    }
}

@MainActor
private struct PostSettingsView: View {
    @ObservedObject var viewModel: PostSettingsViewModel

    @State private var isShowingDiscardChangesAlert = false

    var body: some View {
        Form {
            featuredImageSection
            generalSection
            if viewModel.isPost {
                organizationSection
            }
            excerptSection
            moreOptionsSection
            infoSection
        }
        .accessibilityIdentifier("post_settings_form")
        .disabled(viewModel.isSaving)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                buttonCancel
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                buttonSave
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving || viewModel.hasChanges)
        .alert(viewModel.deletedAlertTitle, isPresented: $viewModel.isShowingDeletedAlert) {
            Button(SharedStrings.Button.ok) {
                viewModel.onDismiss?()
            }
        } message: {
            Text(viewModel.deletedAlertMessage)
        }
        .confirmationDialog(Strings.discardChangesTitle, isPresented: $isShowingDiscardChangesAlert) {
            Button(Strings.discardChangesButton, role: .destructive) {
                viewModel.buttonCancelTapped()
            }
            Button(SharedStrings.Button.cancel, role: .cancel) {
                // Do nothing - continue editing
            }
        } message: {
            Text(Strings.discardChangesMessage)
        }
    }

    private var buttonCancel: some View {
        Button(SharedStrings.Button.cancel) {
            if viewModel.hasChanges {
                isShowingDiscardChangesAlert = true
            } else {
                viewModel.buttonCancelTapped()
            }
        }
        .tint(AppColor.tint)
        .accessibilityIdentifier("post_settings_cancel_button")
    }

    @ViewBuilder
    private var buttonSave: some View {
        if viewModel.isSaving {
            ProgressView()
        } else {
            Group {
                if viewModel.isStandalone {
                    Button(SharedStrings.Button.save) {
                        viewModel.buttonSaveTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                } else {
                    Button(SharedStrings.Button.done) {
                        viewModel.buttonSaveTapped()
                    }
                    .fontWeight(.medium)
                }
            }
            .accessibilityIdentifier("post_settings_save_button")
            .disabled(!viewModel.hasChanges)
            .tint(AppColor.tint)
        }
    }

    // MARK: - "Featured Image" Section

    @ViewBuilder
    private var featuredImageSection: some View {
        Section {
            PostSettingsFeaturedImageRow(viewModel: viewModel.featuredImageViewModel)
                .accessibilityIdentifier("post_settings_featured_image_cell")
        } header: {
            SectionHeader(Strings.featuredImageHeader)
        }
    }

    // MARK: - "Organization" Section

    @ViewBuilder
    private var organizationSection: some View {
        Section {
            categoriesRow
            tagsRow
        } header: {
            SectionHeader(Strings.taxonomyHeader)
        }
    }

    private var categoriesRow: some View {
        Button(action: viewModel.showCategoriesPicker) {
            HStack {
                PostSettingsCategoriesRow(categories: viewModel.displayedCategories)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("post_settings_categories")
    }

    private var tagsRow: some View {
        Button(action: viewModel.showTagsPicker) {
            HStack {
                PostSettingsTagsRow(tags: viewModel.displayedTags)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("post_settings_tags")
    }

    // MARK: - "Excerpt" Section

    @ViewBuilder
    private var excerptSection: some View {
        Section {
            NavigationLink {
                PostSettingsExcerptEditor(text: $viewModel.settings.excerpt)
                    .navigationTitle(Strings.excerptHeader)
            } label: {
                PostSettingExcerptRow(text: viewModel.settings.excerpt)
            }
        } header: {
            SectionHeader(Strings.excerptHeader)
        }
    }

    // MARK: - "General" Section

    @ViewBuilder
    private var generalSection: some View {
        Section {
            authorRow
            if !viewModel.isDraftOrPending {
                publishDateRow
                visibilityRow
            }
            slugRow
        } header: {
            SectionHeader(Strings.generalHeader)
        }
    }

    private var authorRow: some View {
        NavigationLink {
            PostAuthorPicker(
                blog: viewModel.post.blog,
                currentAuthorID: viewModel.settings.author?.id
            ) { selection in
                viewModel.settings.updateAuthor(with: selection)
            }
        } label: {
            PostSettingsAuthorRow(author: viewModel.settings.author)
        }
    }

    private var pendingReviewRow: some View {
        Toggle(isOn: $viewModel.settings.isPendingReview) {
            Text(Strings.pendingReviewLabel)
        }
    }

    private var publishDateRow: some View {
        NavigationLink {
            PublishDatePickerView(configuration: PublishDatePickerConfiguration(
                date: viewModel.settings.publishDate,
                isRequired: true,
                timeZone: viewModel.timeZone,
                updated: { date in
                    viewModel.settings.publishDate = date
                }
            ))
        } label: {
            SettingsRow(Strings.publishDateLabel, value: viewModel.publishDateText ?? "–")
        }
    }

    private var visibilityRow: some View {
        NavigationLink {
            PostVisibilityPicker(
                selection: PostVisibilityPicker.Selection(post: viewModel.post),
                dismissOnSelection: true,
                onSubmit: { selection in
                    viewModel.updateVisibility(selection)
                }
            )
        } label: {
            SettingsRow(Strings.visibilityLabel, value: viewModel.visibilityText)
        }
    }

    // MARK: - "More Options" Section

    /// The least-used options.
    @ViewBuilder
    private var moreOptionsSection: some View {
        Section {
            if viewModel.shouldShowStickyOption {
                stickyPostRow
            }
            if viewModel.isDraftOrPending {
                pendingReviewRow
            }
            if viewModel.isPost {
                postFormatRow
            }
            if !viewModel.isPost {
                parentPageRow
            }
        } header: {
            SectionHeader(Strings.moreOptionsHeader)
        }
    }

    private var postFormatRow: some View {
        NavigationLink {
            PostFormatPicker(post: viewModel.post as! Post) { format in
                viewModel.settings.postFormat = format
                viewModel.viewController?.navigationController?.popViewController(animated: true)
            }
        } label: {
            SettingsRow(Strings.postFormatLabel, value: viewModel.postFormatText)
        }
    }

    private var parentPageRow: some View {
        NavigationLink {
            if let page = viewModel.post as? Page {
                ParentPagePicker(
                    blog: viewModel.post.blog,
                    currentPage: page,
                    onSelection: { selectedParentPage in
                        viewModel.settings.parentPageID = selectedParentPage?.postID?.intValue
                        viewModel.viewController?.navigationController?.popViewController(animated: true)
                    }
                )
            }
        } label: {
            SettingsRow(Strings.parentPageLabel, value: viewModel.parentPageText ?? Strings.topLevelPage)
        }
    }

    private var slugRow: some View {
        NavigationLink {
            SettingsTextFieldView(
                title: Strings.slugLabel,
                text: $viewModel.settings.slug,
                placeholder: Strings.slugPlaceholder,
                hint: Strings.slugHint
            )
            .autocapitalization(.none)
            .autocorrectionDisabled()
        } label: {
            SettingsRow(Strings.slugLabel, value: viewModel.slugText)
        }
    }

    private var stickyPostRow: some View {
        Toggle(isOn: $viewModel.settings.isStickyPost) {
            Text(Strings.stickyPostLabel)
        }
    }

    // MARK: - "Info" Section

    @ViewBuilder
    private var infoSection: some View {
        if viewModel.lastEditedText != nil || viewModel.postID != nil {
            Section {
                if let postID = viewModel.postID {
                    SettingsRow(Strings.postIDLabel, value: String(postID))
                }
                if let lastEditedText = viewModel.lastEditedText {
                    SettingsRow(Strings.lastEditedLabel, value: lastEditedText)
                }
            } header: {
                SectionHeader(Strings.infoLabel)
            }
        }
    }
}

@MainActor
private struct PostSettingsAuthorRow: View {
    let author: PostSettings.Author?

    var body: some View {
        HStack(spacing: 6) {
            Text(Strings.authorLabel)
            Spacer()
            if let author {
                if let avatarURL = author.avatarURL {
                    AvatarView(style: .single(avatarURL), diameter: 22)
                }
                Text(author.displayName)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            } else {
                Text("—")
                    .foregroundColor(.secondary)
            }
        }
    }
}

@MainActor
private struct SettingsRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
                .layoutPriority(1)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .lineLimit(1)
    }
}

@MainActor
private struct SettingsTextFieldView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let hint: String

    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
            } footer: {
                Text(hint)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFocused = true
        }
    }
}

private enum Strings {
    static let generalHeader = NSLocalizedString(
        "postSettings.section.general",
        value: "General",
        comment: "Section header for General settings in Post Settings"
    )

    static let authorLabel = NSLocalizedString(
        "postSettings.author.label",
        value: "Author",
        comment: "Label for the author field in Post Settings"
    )

    static let publishDateLabel = NSLocalizedString(
        "postSettings.publishDate.label",
        value: "Date",
        comment: "Label for the publish date field in Post Settings"
    )

    static let visibilityLabel = NSLocalizedString(
        "postSettings.visibility.label",
        value: "Visibility",
        comment: "Label for the visibility field in Post Settings"
    )

    static let pendingReviewLabel = NSLocalizedString(
        "postSettings.pendingReview.label",
        value: "Pending Review",
        comment: "Label for the pending review toggle in Post Settings"
    )

    static let discardChangesTitle = NSLocalizedString(
        "postSettings.discardChanges.title",
        value: "Discard Changes?",
        comment: "Title for the discard changes confirmation dialog"
    )

    static let discardChangesMessage = NSLocalizedString(
        "postSettings.discardChanges.message",
        value: "You have unsaved changes. Are you sure you want to discard them?",
        comment: "Message for the discard changes confirmation dialog"
    )

    static let discardChangesButton = NSLocalizedString(
        "postSettings.discardChanges.button",
        value: "Discard Changes",
        comment: "Button to confirm discarding changes"
    )

    static let featuredImageHeader = NSLocalizedString(
        "postSettings.featuredImage.header",
        value: "Featured Image",
        comment: "Section header for Featured Image in Post Settings"
    )

    static let taxonomyHeader = NSLocalizedString(
        "postSettings.organization.header",
        value: "Organization",
        comment: "Label for the Organization area (categories, keywords, ...) in post settings."
    )

    static let categoriesLabel = NSLocalizedString(
        "postSettings.categories.label",
        value: "Categories",
        comment: "Label for the categories field. Should be the same as WP core."
    )

    static let excerptHeader = NSLocalizedString(
        "postSettings.excerpt.header",
        value: "Excerpt",
        comment: "Section header for Excerpt in Post Settings"
    )

    static let moreOptionsHeader = NSLocalizedString(
        "postSettings.moreOptions.header",
        value: "More Options",
        comment: "Section header for More Options in Post Settings. Should use the same translation as core WP."
    )

    static let postFormatLabel = NSLocalizedString(
        "postSettings.postFormat.label",
        value: "Post Format",
        comment: "Label for the post format field. Should be the same as WP core."
    )

    static let parentPageLabel = NSLocalizedString(
        "postSettings.parentPage.label",
        value: "Parent Page",
        comment: "Label for the parent page field"
    )

    static let topLevelPage = NSLocalizedString(
        "postSettings.parentPage.topLevel",
        value: "Top level",
        comment: "Cell title for the Top Level option case"
    )

    static let slugLabel = NSLocalizedString(
        "postSettings.slug.label",
        value: "Slug",
        comment: "Label for the slug field. Should be the same as WP core."
    )

    static let slugPlaceholder = NSLocalizedString(
        "postSettings.slug.placeholder",
        value: "Enter slug",
        comment: "Placeholder for the slug field"
    )

    static let slugHint = NSLocalizedString(
        "postSettings.slug.hint",
        value: "The slug is the URL-friendly version of the post title.",
        comment: "Hint text for the slug field. Should be the same as the text displayed if the user clicks the (i) in Slug in Calypso."
    )

    static let stickyPostLabel = NSLocalizedString(
        "postSettings.stickyPost.label",
        value: "Sticky",
        comment: "Label for the sticky post toggle. Sticky posts are displayed at the top of the blog."
    )

    static let infoLabel = NSLocalizedString(
        "postSettings.metadata.header",
        value: "Info",
        comment: "Section header for Info in Post Settings"
    )

    static let permalinkLabel = NSLocalizedString(
        "postSettings.permalink.label",
        value: "Permalink",
        comment: "Label for the permalink field in Post Settings"
    )

    static let lastEditedLabel = NSLocalizedString(
        "postSettings.lastEdited.label",
        value: "Last Edited",
        comment: "Label for the last edited field in Post Settings"
    )

    static let postIDLabel = NSLocalizedString(
        "postSettings.postID.label",
        value: "ID",
        comment: "Label for the post ID field in Post Settings"
    )
}
