import SwiftUI
import WordPressData
import WordPressUI

struct ReaderSubscriptionCell: View {
    let site: ReaderSiteTopic

    @State private var isShowingSettings = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var onDelete: (ReaderSiteTopic) -> Void

    private var details: String {
        let components = [
            horizontalSizeClass == .compact ? nil : URL(string: site.siteURL)?.host,
            Strings.numberOfSubscriptions(with: site.subscriberCount.intValue)
        ]
        return components.compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                ReaderSiteIconView(site: site, size: .regular)
                    .padding(.leading, horizontalSizeClass == .compact ? 0 : 4)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(site.title)
                            .font(.body.weight(.medium))
                    }
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 0) {
                if site.canManageNotifications {
                    ReaderSubscriptionNotificationSettingsButton(site: site)
                }
                buttonMore
            }
            .padding(.trailing, -16)
        }
        .contextMenu(menuItems: {
            ReaderSubscriptionContextMenu(site: site, isShowingSettings: $isShowingSettings)
        }, preview: {
            ReaderTopicPreviewView(topic: site)
        })
    }

    private var buttonMore: some View {
        Menu {
            ReaderSubscriptionContextMenu(site: site, isShowingSettings: $isShowingSettings)
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum Strings {
    static let settings = NSLocalizedString("reader.subscriptions.settings", value: "Settings", comment: "Button title for managing subscription settings")

    static func numberOfSubscriptions(with count: Int) -> String {
        let singular = NSLocalizedString("reader.subscriptions.subscriptionsSingular", value: "%@ subscriber", comment: "Number of subscriptions on a site (singular)")
        let plural = NSLocalizedString("reader.subscriptions.subscriptionsPlural", value: "%@ subscribers", comment: "Number of subscriptions on a site (plural)")
        return String(format: count == 1 ? singular : plural, kFormatted(count))
    }

    private static func kFormatted(_ count: Int) -> String {
        count.formatted(.number.notation(.compactName))
    }
}
