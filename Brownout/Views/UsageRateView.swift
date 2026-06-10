import SwiftUI

struct UsageRateView: View {
    let forecast: DailyForecast

    private var rate: Double? { forecast.currentUsageRate }

    private var rateColor: Color {
        guard let r = rate else { return .secondary }
        switch r {
        case ..<80: return .green
        case 80..<90: return .yellow
        default: return .red
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Usage Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let r = rate {
                    Text(String(format: "%.0f%%", r))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(rateColor)
                        .contentTransition(.numericText())
                } else {
                    Text("--")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let entry = forecast.latestActualEntry {
                VStack(alignment: .trailing, spacing: 6) {
                    if let actual = entry.actual {
                        StatRow(label: "Actual", value: actual)
                    }
                    StatRow(label: "Supply Capacity", value: entry.capacity)
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
    }
}

private struct StatRow: View {
    let label: LocalizedStringKey
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text("\(Int(value).formatted(.number))万kW")
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let entries = [ForecastEntry(time: .now, actual: 4200, predicted: 4300, capacity: 6000)]
    Group {
        UsageRateView(forecast: DailyForecast(area: .tokyo, date: .now, entries: entries))
            .padding()
            .preferredColorScheme(.dark)
        UsageRateView(forecast: DailyForecast(area: .tokyo, date: .now, entries: entries))
            .padding()
            .preferredColorScheme(.light)
    }
}
