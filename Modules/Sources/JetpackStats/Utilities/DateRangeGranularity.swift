import Foundation

enum DateRangeGranularity: Comparable {
    case hour
    case day
    case week
    case month
    case year
}

extension DateInterval {
    /// Automatically determine the appropriate period for chart display based
    /// on date range. This aims to show between 7 and 30 data points for optimal
    /// visualization on both bar charts and line charts where you can use drag
    /// gesture to see information about individual periods.
    var preferredGranularity: DateRangeGranularity {
        // Calculate total days for more accurate granularity selection
        let totalDays = Int(ceil(duration / 86400)) // 86400 seconds in a day

        // For ranges <= 1 day: show hourly data (up to 24 points)
        if totalDays <= 1 {
            return .hour
        }
        // For ranges 2-90 days: show daily data (2-90 points)
        else if totalDays <= 31 {
            return .day
        }
        else if totalDays <= 90 {
            return .week
        }
        // For ranges under about 4 years, show months
        else if totalDays <= 365 * 4 {
            return .month
        }
        // For ranges > 2 years: show yearly data
        else {
            return .year
        }
    }
}

extension DateRangeGranularity {
    /// Components needed to aggregate data at this granularity
    var calendarComponents: Set<Calendar.Component> {
        switch self {
        case .hour: [.year, .month, .day, .hour]
        case .day: [.year, .month, .day]
        case .week: [.year, .month, .day]
        case .month: [.year, .month]
        case .year: [.year]
        }
    }

    /// Component to increment when generating date sequences
    var component: Calendar.Component {
        switch self {
        case .hour: .hour
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}
