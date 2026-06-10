import Foundation

enum ForecastError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int)
    case parseError(String)
    case noData

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
        }
    }
}

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
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ForecastError.httpError(http.statusCode)
            }
            data = d
        } catch let e as ForecastError {
            throw e
        } catch {
            throw ForecastError.networkError(error)
        }
        return try parseCSV(data, area: area, date: date)
    }

    private func parseCSV(_ data: Data, area: PowerArea, date: Date) throws -> DailyForecast {
        let fmt = area.csvFormat
        let text = String(data: data, encoding: fmt.encoding)
            ?? String(data: data, encoding: .utf8)
            ?? ""

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .jst
        var base = cal.dateComponents([.year, .month, .day], from: date)
        base.timeZone = .jst

        let c = fmt.columns
        let minCols = max(c.date, c.time, c.actual, c.predicted, c.capacity) + 1
        var entries: [ForecastEntry] = []
        var seenTimes = Set<Date>()   // 重複セクション除外（TEPCO 等は複数 DATE/TIME ブロックを持つ）

        for line in text.components(separatedBy: .newlines) {
            let fields = line.components(separatedBy: ",")
            guard fields.count >= minCols else { continue }

            // DATE 列が "YYYY/MM/DD" または "YYYY/M/D" 形式の行のみ処理
            let datePart = fields[c.date].trimmingCharacters(in: .whitespaces)
            guard datePart.count >= 9,
                  datePart.prefix(4).allSatisfy(\.isNumber),
                  datePart.dropFirst(4).first == "/" else { continue }

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

        if entries.isEmpty { throw ForecastError.noData }
        return DailyForecast(area: area, date: date, entries: entries)
    }

    private func parseTime(_ s: String, base: DateComponents, calendar: Calendar) -> Date? {
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

private extension TimeZone {
    static let jst = TimeZone(identifier: "Asia/Tokyo")!
}
