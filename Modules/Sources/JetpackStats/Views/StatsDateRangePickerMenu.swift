import SwiftUI

struct StatsDateRangePickerMenu: View {
    @Binding var selection: StatsDateRange
    @Binding var isShowingCustomRangePicker: Bool

    @Environment(\.context) var context

    var body: some View {
        Section {
            Button {
                isShowingCustomRangePicker = true
            } label: {
                Label(Strings.DatePicker.customRangeMenu, systemImage: "calendar")
            }
            comparisonPeriodPicker
        }
        Section {
            makePresetButtons(for: [
                .last7Days,
                .last30Days,
                .last12Months,
            ])
            Menu {
                Section {
                    makePresetButtons(for: [
                        .last28Days,
                        .last12Weeks,
                        .last6Months,
                        .last3Years,
                        .last10Years
                    ])
                }
            } label: {
                Text(Strings.DatePicker.morePeriods)
            }
        }
        Section {
            makePresetButtons(for: [
                .today,
                .thisWeek,
                .thisMonth,
                .thisYear
            ])
        }
    }

    private func makePresetButtons(for presents: [DateIntervalPreset]) -> some View {
        ForEach(presents) { preset in
            Button(preset.localizedString) {
                selection.update(preset: preset)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                // Track preset selection
                context.tracker?.send(.dateRangePresetSelected, properties: [
                    "selected_preset": preset.analyticsName
                ])
            }
        }
    }

    private var comparisonPeriodPicker: some View {
        Menu {
            ForEach(DateRangeComparisonPeriod.allCases) { period in
                Button(action: {
                    selection.update(comparisonPeriod: period)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Text(period.localizedTitle)
                    Text(formattedComparisonRange(for: period))
                    if selection.comparison == period {
                        Image(systemName: "checkmark")
                    }
                }
                .lineLimit(1)
            }
        } label: {
            Label(Strings.DatePicker.compareWith, systemImage: "arrow.left.arrow.right")
        }
    }

    private func formattedComparisonRange(for period: DateRangeComparisonPeriod) -> String {
        var copy = selection
        copy.update(comparisonPeriod: period)
        return context.formatters.dateRange.string(from: copy.effectiveComparisonInterval)
    }
}
