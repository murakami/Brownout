import SwiftUI
import Charts

struct DemandChartView: View {
    let forecast: DailyForecast

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var chartData: [SeriesPoint] {
        forecast.entries.flatMap { entry -> [SeriesPoint] in
            var pts = [SeriesPoint(time: entry.time, value: entry.capacity, series: .capacity)]
            if let v = entry.actual    { pts.append(.init(time: entry.time, value: v, series: .actual)) }
            if let v = entry.predicted { pts.append(.init(time: entry.time, value: v, series: .predicted)) }
            return pts
        }
    }

    private var yDomain: ClosedRange<Double> {
        let hi = (chartData.map(\.value).max() ?? 1) * 1.05
        return 0...hi
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                ForEach(ChartSeries.allCases, id: \.self) { s in
                    LegendItem(series: s)
                }
            }
            .font(.caption)
            .padding(.horizontal, 4)
            .padding(.bottom, verticalSizeClass == .regular ? 24 : 12)

            Chart {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("万kW", point.value),
                        series: .value("Series", point.series.label)
                    )
                    .foregroundStyle(by: .value("Series", point.series.label))
                    .lineStyle(point.series.strokeStyle)
                }

                RuleMark(x: .value("Now", Date()))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Now")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale(
                domain: ChartSeries.allCases.map(\.label),
                range: ChartSeries.allCases.map(\.color)
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel(
                        format: .dateTime
                            .hour(.defaultDigits(amPM: .omitted))
                            .minute()
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Int(v).formatted(.number))
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartLegend(.hidden)
            .frame(maxHeight: .infinity)
            .padding(.bottom, verticalSizeClass == .regular ? 32 : 0)

            Text("Unit: 万kW  (×10,000 kW)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Supporting types

private struct SeriesPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
    let series: ChartSeries
}

enum ChartSeries: String, CaseIterable {
    case capacity  = "Max Supply"
    case actual    = "Actual"
    case predicted = "Forecast"

    var label: String { rawValue }

    var color: Color {
        switch self {
        case .capacity:  .blue
        case .actual:    .green
        case .predicted: .red
        }
    }

    var strokeStyle: StrokeStyle {
        switch self {
        case .capacity:  StrokeStyle(lineWidth: 1.5, dash: [5, 3])
        case .actual:    StrokeStyle(lineWidth: 2)
        case .predicted: StrokeStyle(lineWidth: 1.5, dash: [2, 2])
        }
    }
}

private struct LegendItem: View {
    let series: ChartSeries

    var body: some View {
        HStack(spacing: 4) {
            Canvas { ctx, size in
                let y = size.height / 2
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(series.color), style: series.strokeStyle)
            }
            .frame(width: 20, height: 8)
            Text(LocalizedStringKey(series.label))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let now = Date()
    let entries = (0..<48).map { i -> ForecastEntry in
        let t = Calendar.current.date(
            byAdding: .minute, value: i * 30,
            to: Calendar.current.startOfDay(for: now)
        )!
        let base = 4000.0 + 800 * sin(Double(i) / 48 * .pi)
        return ForecastEntry(
            time: t,
            actual: i < 24 ? base + Double.random(in: -80...80) : nil,
            predicted: base + Double.random(in: -50...50),
            capacity: 6000
        )
    }
    Group {
        DemandChartView(forecast: DailyForecast(area: .tokyo, date: now, entries: entries))
            .padding()
            .preferredColorScheme(.dark)
        DemandChartView(forecast: DailyForecast(area: .tokyo, date: now, entries: entries))
            .padding()
            .preferredColorScheme(.light)
    }
}
