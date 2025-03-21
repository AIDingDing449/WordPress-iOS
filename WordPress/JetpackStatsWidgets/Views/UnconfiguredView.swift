import SwiftUI

struct UnconfiguredView: View {

    var timelineEntry: StatsWidgetEntry
    @Environment(\.showsWidgetContainerBackground) var showsWidgetContainerBackground: Bool

    var body: some View {
        Text(unconfiguredMessage)
            .font(.footnote)
            .foregroundColor(showsWidgetContainerBackground ? Color(.secondaryLabel) : Color(.label))
            .multilineTextAlignment(.center)
            .padding()
            .removableWidgetBackground()
    }

    var unconfiguredMessage: String {
        switch timelineEntry {
        case .loggedOut(let widgetKind):
            switch widgetKind {
            case .today:
                return LocalizableStrings.unconfiguredViewJetpackTodayTitle
            case .allTime:
                return LocalizableStrings.unconfiguredViewJetpackAllTimeTitle
            case .thisWeek:
                return LocalizableStrings.unconfiguredViewJetpackThisWeekTitle
            }
        case .noSite(let widgetKind):
            switch widgetKind {
            case .today:
                return LocalizableStrings.noSiteViewTodayTitle
            case .allTime:
                return LocalizableStrings.noSiteViewAllTimeTitle
            case .thisWeek:
                return LocalizableStrings.noSiteViewThisWeekTitle
            }
        case .noData(let widgetKind):
            switch widgetKind {
            case .today:
                return LocalizableStrings.noDataViewTodayTitle
            case .allTime:
                return LocalizableStrings.noDataViewAllTimeTitle
            case .thisWeek:
                return LocalizableStrings.noDataViewThisWeekTitle
            }
        case .disabled:
            return LocalizableStrings.statsDisabledViewTitle
        default:
            return LocalizableStrings.noDataViewTitle
        }
    }
}

struct PlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        UnconfiguredView(timelineEntry: .loggedOut(.today))
    }
}
