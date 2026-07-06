import Foundation
import os

private let forecastLog = Logger(subsystem: "jp.co.bitz.Brownout", category: "PowerForecastService")

enum ForecastError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int)
    case parseError(String)
    case noData
    case staleData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "error.invalid_url")
        case .networkError(let e):
            return e.localizedDescription
        case .httpError(let code):
            return String.localizedStringWithFormat(
                NSLocalizedString("error.http %lld", comment: ""), Int64(code)
            )
        case .parseError(let msg):
            return String.localizedStringWithFormat(
                NSLocalizedString("error.parse %@", comment: ""), msg
            )
        case .noData:
            return String(localized: "error.no_data")
        case .staleData:
            return String(localized: "error.stale_data")
        }
    }
}

// MARK: - CSV Parser (テスト可能な独立型)

struct CSVParser {
    nonisolated static func parse(_ data: Data, area: PowerArea, date: Date) throws -> DailyForecast {
        let fmt = area.csvFormat
        let text = String(data: data, encoding: fmt.encoding)
            ?? String(data: data, encoding: .utf8)
            ?? ""
        return try parseText(text, format: fmt, area: area, date: date)
    }

    nonisolated static func parseText(_ text: String, format fmt: CSVFormat, area: PowerArea, date: Date) throws -> DailyForecast {
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = jst
        var base = cal.dateComponents([.year, .month, .day], from: date)
        base.timeZone = jst

        let c = fmt.columns
        let minCols = max(c.date, c.time, c.actual, c.predicted, c.capacity) + 1
        var entries: [ForecastEntry] = []
        var seenTimes = Set<Date>()   // 重複セクション除外（TEPCO 等は複数 DATE/TIME ブロックを持つ）
        var sawDateRow = false        // DATE 形式の行を1つでも見たか（フォーマット崩れ検知用）
        var sawMatchingDateRow = false // 要求日と一致する行を1つでも見たか（固定URLの古いデータ検知用）

        for line in text.components(separatedBy: .newlines) {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= minCols else { continue }

            // DATE 列が "YYYY/M/D" 形式（月・日は1桁/2桁どちらもあり得る）の行のみ処理
            let datePart = fields[c.date].trimmingCharacters(in: .whitespaces)
            let dateComponents = datePart.split(separator: "/")
            guard dateComponents.count == 3,
                  dateComponents[0].count == 4, dateComponents[0].allSatisfy(\.isNumber),
                  let y = Int(dateComponents[0]), let m = Int(dateComponents[1]), let d = Int(dateComponents[2])
            else { continue }
            sawDateRow = true

            // CSV の DATE 列が要求日と一致しない行は無視する。
            // 固定URL（例: 旧関西 juyo1_kansai.csv）が更新停止して古いデータを
            // 返し続けるケースを、日付を無視して取り込んでしまわないようにするため。
            guard y == base.year, m == base.month, d == base.day else { continue }
            sawMatchingDateRow = true

            let timePart = fields[c.time].trimmingCharacters(in: .whitespaces)
            guard let time = parseTime(timePart, base: base, calendar: cal) else { continue }
            guard seenTimes.insert(time).inserted else { continue }   // 2 つ目以降のセクションを無視

            // 実績が 0 の行は "データなし" として nil 扱い（各社 CSV の慣例）
            let actualRaw = Double(fields[c.actual].trimmingCharacters(in: .whitespaces))
            let actual: Double? = actualRaw.flatMap { $0 > 0 ? $0 : nil }
            let predicted = Double(fields[c.predicted].trimmingCharacters(in: .whitespaces))
            let capacity  = Double(fields[c.capacity].trimmingCharacters(in: .whitespaces)) ?? 0

            entries.append(ForecastEntry(
                time: time,
                actual: actual,
                predicted: predicted,
                capacity: capacity
            ))
        }

        if entries.isEmpty {
            throw (sawDateRow && !sawMatchingDateRow) ? ForecastError.staleData : ForecastError.noData
        }
        return DailyForecast(area: area, date: date, entries: entries)
    }

    nonisolated private static func parseTime(_ s: String, base: DateComponents, calendar: Calendar) -> Date? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              hour < 24 else { return nil }
        var c = base
        c.hour = hour
        c.minute = minute
        c.second = 0
        return calendar.date(from: c)
    }
}

// MARK: - Service Actor

actor PowerForecastService {
    static let shared = PowerForecastService()

    // Safari on iPhone iOS 26 と同等の User-Agent – 一部サーバーがアプリからのアクセスを 403 で弾くため設定
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    func fetchForecast(area: PowerArea, date: Date = .now) async throws -> DailyForecast {
        guard let url = area.csvStrategy.resolve(for: date) else {
            throw ForecastError.invalidURL
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(area.websiteURL.absoluteString, forHTTPHeaderField: "Referer")

        let data: Data
        do {
            let (d, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            forecastLog.debug("""
                fetch \(area.id, privacy: .public): requested=\(url.absoluteString, privacy: .public) \
                final=\(response.url?.absoluteString ?? "?", privacy: .public) \
                status=\(http?.statusCode ?? -1) bytes=\(d.count)
                """)
            if let http, http.statusCode != 200 {
                throw ForecastError.httpError(http.statusCode)
            }
            data = d
        } catch let e as ForecastError {
            throw e
        } catch {
            forecastLog.error("fetch \(area.id, privacy: .public) network error: \(error.localizedDescription, privacy: .public)")
            throw ForecastError.networkError(error)
        }
        do {
            return try CSVParser.parse(data, area: area, date: date)
        } catch {
            let preview = String(data: data.prefix(200), encoding: area.csvFormat.encoding)
                ?? String(data: data.prefix(200), encoding: .utf8)
                ?? "(undecodable, \(data.count) bytes)"
            forecastLog.error("""
                parse \(area.id, privacy: .public) failed: \(String(describing: error), privacy: .public) \
                preview=\(preview, privacy: .public)
                """)
            throw error
        }
    }
}

