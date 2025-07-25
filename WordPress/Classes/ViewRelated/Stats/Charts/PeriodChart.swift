import UIKit
import DGCharts
import WordPressKit
import WordPressUI

// MARK: - StatsPeriodFilterDimension

enum StatsPeriodFilterDimension: Int, CaseIterable {
    case views = 0, visitors, likes, comments
}

extension StatsPeriodFilterDimension {
    var accessibleDescription: String {
        switch self {
        case .views:
            return NSLocalizedString("Bar Chart depicting Views for selected period, Visitors superimposed", comment: "This description is used to set the accessibility label for the Period chart, with Views selected.")
        case .visitors:
            return NSLocalizedString("Bar Chart depicting Visitors for the selected period.", comment: "This description is used to set the accessibility label for the Period chart, with Visitors selected.")
        case .likes:
            return NSLocalizedString("Bar Chart depicting Likes for the selected period.", comment: "This description is used to set the accessibility label for the Period chart, with Likes selected.")
        case .comments:
            return NSLocalizedString("Bar Chart depicting Comments for the selected period.", comment: "This description is used to set the accessibility label for the Period chart, with Comments selected.")
        }
    }
}

// MARK: - PeriodChart

final class PeriodChart {
    private(set) var barChartData: [BarChartDataConvertible]
    private(set) var barChartStyling: [BarChartStyling]

    init(data: StatsSummaryTimeIntervalData) {
        let (data, styling) = PeriodChartDataTransformer.transform(data: data)

        barChartData = data
        barChartStyling = styling
    }
}

// MARK: - PeriodChartData

private struct PeriodChartData: BarChartDataConvertible {
    let accessibilityDescription: String
    let barChartData: BarChartData
}

// MARK: - PeriodChartDataTransformer

private final class PeriodChartDataTransformer {
    /// A formatter for the Chart values with no decimals
    ///
    /// The Charts' default formatter has a single decimal defined. This causes VoiceOver to
    /// sometimes read the decimal part. For example, VoiceOver would says “29.0” for a visitors
    /// value.
    ///
    /// - SeeAlso: ChartUtils.defaultValueFormatter()
    ///
    private static let dataSetValueFormatter = DefaultValueFormatter(decimals: 0)

    static func transform(data: StatsSummaryTimeIntervalData) -> (barChartData: [BarChartDataConvertible], barChartStyling: [BarChartStyling]) {
        let summaryData = data.summaryData

        let firstDateInterval: TimeInterval
        let lastDateInterval: TimeInterval
        let effectiveWidth: Double

        if summaryData.isEmpty {
            firstDateInterval = 0
            lastDateInterval = 0
            effectiveWidth = 1
        } else {
            firstDateInterval = summaryData.first?.periodStartDate.timeIntervalSince1970 ?? 0
            lastDateInterval = summaryData.last?.periodStartDate.timeIntervalSince1970 ?? 0

            let range = lastDateInterval - firstDateInterval
            let effectiveBars = Double(Double(summaryData.count) * 1.2)
            effectiveWidth = range / effectiveBars
        }

        let totalViews = summaryData.compactMap({$0.viewsCount}).reduce(0, +)
        let totalVisitors = summaryData.compactMap({$0.visitorsCount}).reduce(0, +)
        let totalLikes = summaryData.compactMap({$0.likesCount}).reduce(0, +)
        let totalComments = summaryData.compactMap({$0.commentsCount}).reduce(0, +)

        var viewEntries = [BarChartDataEntry]()
        var visitorEntries = [BarChartDataEntry]()
        var likeEntries = [BarChartDataEntry]()
        var commentEntries = [BarChartDataEntry]()

        for datum in summaryData {
            let dateInterval = datum.periodStartDate.timeIntervalSince1970
            let offset = dateInterval - firstDateInterval

            let x = offset

            // If the chart has no data, show "stub" bars
            let emptyChartBarHeight = StatsBarChartView.emptyChartBarHeight
            let viewEntry = BarChartDataEntry(x: x, y: totalViews > 0 ? Double(datum.viewsCount) : emptyChartBarHeight)
            let visitorEntry = BarChartDataEntry(x: x, y: totalVisitors > 0 ? Double(datum.visitorsCount) : emptyChartBarHeight)
            let likeEntry = BarChartDataEntry(x: x, y: totalLikes > 0 ? Double(datum.likesCount) : emptyChartBarHeight)
            let commentEntry = BarChartDataEntry(x: x, y: totalComments > 0 ? Double(datum.commentsCount) : emptyChartBarHeight)

            viewEntries.append(viewEntry)
            visitorEntries.append(visitorEntry)
            likeEntries.append(likeEntry)
            commentEntries.append(commentEntry)
        }

        var chartData = [BarChartData]()

        let viewsDataSet = BarChartDataSet(entries: viewEntries,
                                           label: NSLocalizedString("Views", comment: "Accessibility label used for distinguishing Views and Visitors in the Stats → Views bar chart."),
                                           valueFormatter: dataSetValueFormatter)
        let visitorsDataSet = BarChartDataSet(entries: visitorEntries,
                                              label: NSLocalizedString("Visitors", comment: "Accessibility label used for distinguishing Views and Visitors in the Stats → Views bar chart."),
                                              valueFormatter: dataSetValueFormatter)
        let viewsDataSets = [ viewsDataSet, visitorsDataSet ]
        let viewsChartData = BarChartData(dataSets: viewsDataSets)
        chartData.append(viewsChartData)

        let visitorsChartData = BarChartData(dataSet: visitorsDataSet)
        chartData.append(visitorsChartData)

        let likesChartData = BarChartData(entries: likeEntries, valueFormatter: dataSetValueFormatter)
        chartData.append(likesChartData)

        let commentsChartData = BarChartData(entries: commentEntries, valueFormatter: dataSetValueFormatter)
        chartData.append(commentsChartData)

        for barChart in chartData {
            barChart.barWidth = effectiveWidth
        }

        var barChartDataConvertibles = [BarChartDataConvertible]()
        for filterDimension in StatsPeriodFilterDimension.allCases {
            let filterIndex = filterDimension.rawValue

            let accessibleDescription = filterDimension.accessibleDescription
            let data = chartData[filterIndex]
            let periodChartData = PeriodChartData(accessibilityDescription: accessibleDescription, barChartData: data)

            barChartDataConvertibles.append(periodChartData)
        }

        let horizontalAxisFormatter = HorizontalAxisFormatter(initialDateInterval: firstDateInterval, period: data.period)
        let chartStyling: [BarChartStyling] = [
            ViewsPeriodChartStyling(primaryBarColor: primaryBarColor(forCount: totalViews),
                                    secondaryBarColor: secondaryBarColor(forCount: totalVisitors),
                                    primaryHighlightColor: primaryHighlightColor(forCount: totalViews),
                                    secondaryHighlightColor: secondaryHighlightColor(forCount: totalVisitors),
                                    xAxisValueFormatter: horizontalAxisFormatter),
            DefaultPeriodChartStyling(primaryBarColor: primaryBarColor(forCount: totalVisitors),
                                      primaryHighlightColor: primaryHighlightColor(forCount: totalVisitors),
                                      xAxisValueFormatter: horizontalAxisFormatter),
            DefaultPeriodChartStyling(primaryBarColor: primaryBarColor(forCount: totalLikes),
                                      primaryHighlightColor: primaryHighlightColor(forCount: totalLikes),
                                      xAxisValueFormatter: horizontalAxisFormatter),
            DefaultPeriodChartStyling(primaryBarColor: primaryBarColor(forCount: totalComments),
                                      primaryHighlightColor: primaryHighlightColor(forCount: totalComments),
                                      xAxisValueFormatter: horizontalAxisFormatter),
        ]

        return (barChartDataConvertibles, chartStyling)
    }

    static func primaryBarColor(forCount count: Int) -> UIColor {
        return count > 0 ? UIColor(light: UIAppColor.primaryLight, dark: UIAppColor.primary(.shade80)) : UIAppColor.neutral(.shade0)
    }

    static func secondaryBarColor(forCount count: Int) -> UIColor {
        return count > 0 ? UIColor(light: UIAppColor.primary(.shade60), dark: UIAppColor.primary) : UIAppColor.neutral(.shade0)
    }

    static func primaryHighlightColor(forCount count: Int) -> UIColor? {
        return count > 0 ? UIAppColor.statsPrimaryHighlight : nil
    }

    static func secondaryHighlightColor(forCount count: Int) -> UIColor? {
        return count > 0 ? UIAppColor.statsSecondaryHighlight : nil
    }
}

// MARK: - ViewsPeriodChartStyling

private struct ViewsPeriodChartStyling: BarChartStyling {
    let primaryBarColor: UIColor
    let secondaryBarColor: UIColor?
    let primaryHighlightColor: UIColor?
    let secondaryHighlightColor: UIColor?
    let labelColor: UIColor = UIAppColor.neutral(.shade30)
    let legendColor: UIColor? = UIAppColor.primary(.shade60)
    let legendTitle: String? = NSLocalizedString("Visitors", comment: "This appears in the legend of the period chart; Visitors are superimposed over Views in that case.")
    let lineColor: UIColor = UIAppColor.neutral(.shade5)
    let xAxisValueFormatter: AxisValueFormatter
    let yAxisValueFormatter: AxisValueFormatter = VerticalAxisFormatter()
}

// MARK: - DefaultPeriodChartStyling

private struct DefaultPeriodChartStyling: BarChartStyling {
    let primaryBarColor: UIColor
    let secondaryBarColor: UIColor? = nil
    let primaryHighlightColor: UIColor?
    let secondaryHighlightColor: UIColor? = nil
    let labelColor: UIColor = UIAppColor.neutral(.shade30)
    let legendColor: UIColor? = nil
    let legendTitle: String? = nil
    let lineColor: UIColor = UIAppColor.neutral(.shade5)
    let xAxisValueFormatter: AxisValueFormatter
    let yAxisValueFormatter: AxisValueFormatter = VerticalAxisFormatter()
}
