import Foundation

struct ForecastEntry: Identifiable, Sendable {
    let id = UUID()
    let time: Date
    let actual: Double?     // 実績(万kW)、未来時刻は nil
    let predicted: Double?  // 予測(万kW)
    let capacity: Double    // 供給力(万kW)
}

struct DailyForecast: Sendable {
    let area: PowerArea
    let date: Date
    let entries: [ForecastEntry]

    var latestActualEntry: ForecastEntry? {
        entries.last { $0.actual != nil }
    }

    var currentUsageRate: Double? {
        guard let entry = latestActualEntry,
              let actual = entry.actual,
              entry.capacity > 0 else { return nil }
        return actual / entry.capacity * 100
    }
}
