import Foundation

extension String.Encoding {
    /// Windows-31J (CP932)。Foundation の `.shiftJIS` は JIS X 0208 のみで、
    /// 日本の電力会社CSVで使われる機種依存文字（丸数字・全角チルダ等）を含む
    /// 実データのデコードに失敗するため、より寛容な CP932 を使う。
    static let cp932 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.dosJapanese.rawValue)
        )
    )
}

struct PowerArea: Identifiable, Hashable, Sendable {
    static func == (lhs: PowerArea, rhs: PowerArea) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: String
    let nameKey: String
    let companyKey: String
    let websiteURL: URL
    let csvStrategy: CSVURLStrategy
    let csvFormat: CSVFormat
}

// MARK: - URL Strategy

enum CSVURLStrategy: Sendable {
    /// {date} プレースホルダーを YYYYMMDD に置換する
    case dateBased(template: String)
    /// 固定 URL（常に当日データを返すエンドポイント）
    case fixed(url: String)

    nonisolated func resolve(for date: Date) -> URL? {
        switch self {
        case .dateBased(let template):
            let str = template.replacingOccurrences(of: "{date}", with: yyyyMMdd(date))
            return URL(string: str)
        case .fixed(let url):
            return URL(string: url)
        }
    }

    nonisolated private func yyyyMMdd(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - CSV Format

struct CSVFormat: Sendable {
    let encoding: String.Encoding
    let intervalMinutes: Int
    let columns: ColumnMap

    /// DATE(0), TIME(1), 実績(2), 予測(3), 使用率(4), 供給力(5) — 東北・関西等の標準6列構成
    static let standard = CSVFormat(
        encoding: .cp932,
        intervalMinutes: 30,
        columns: .standard
    )

    /// DATE(0), TIME(1), 実績(2), 予測(3), 供給力(4), 使用率(5) — 東京(TEPCO)固有の列順
    static let tepco = CSVFormat(
        encoding: .cp932,
        intervalMinutes: 30,
        columns: .tepco
    )
}

struct ColumnMap: Sendable {
    let date: Int
    let time: Int
    let actual: Int
    let predicted: Int
    let capacity: Int

    /// 大多数のエリア: capacity が列5（使用率%が列4の6列構成）
    static let standard = ColumnMap(date: 0, time: 1, actual: 2, predicted: 3, capacity: 5)

    /// 東京(TEPCO): capacity が列4（使用率%が列5の独自列順）
    static let tepco = ColumnMap(date: 0, time: 1, actual: 2, predicted: 3, capacity: 4)
}

// MARK: - All areas

extension PowerArea {
    static let all: [PowerArea] = [
        hokkaido, tohoku, tokyo, chubu,
        hokuriku, kansai, chugoku, shikoku, kyushu, okinawa
    ]

    static let hokkaido = PowerArea(
        id: "hokkaido",
        nameKey: "area.hokkaido",
        companyKey: "company.hokkaido",
        websiteURL: URL(string: "https://denkiyoho.hepco.co.jp/")!,
        csvStrategy: .dateBased(
            template: "https://denkiyoho.hepco.co.jp/area/data/juyo_01_{date}.csv"
        ),
        csvFormat: .standard
    )

    static let tohoku = PowerArea(
        id: "tohoku",
        nameKey: "area.tohoku",
        companyKey: "company.tohoku",
        websiteURL: URL(string: "https://setsuden.nw.tohoku-epco.co.jp/")!,
        csvStrategy: .dateBased(
            template: "https://setsuden.nw.tohoku-epco.co.jp/common/demand/juyo_02_{date}.csv"
        ),
        csvFormat: .standard
    )

    /// 東京(TEPCO): 固定 URL + 独自列順（capacity=列4）
    static let tokyo = PowerArea(
        id: "tokyo",
        nameKey: "area.tokyo",
        companyKey: "company.tokyo",
        websiteURL: URL(string: "https://www.tepco.co.jp/forecast/")!,
        csvStrategy: .fixed(
            url: "https://www.tepco.co.jp/forecast/html/images/juyo-s1-j.csv"
        ),
        csvFormat: .tepco
    )

    static let chubu = PowerArea(
        id: "chubu",
        nameKey: "area.chubu",
        companyKey: "company.chubu",
        websiteURL: URL(string: "https://powergrid.chuden.co.jp/denkiyoho/")!,
        csvStrategy: .fixed(
            url: "https://powergrid.chuden.co.jp/denki_yoho_content_data/juyo_cepco003.csv"
        ),
        csvFormat: .standard
    )

    static let hokuriku = PowerArea(
        id: "hokuriku",
        nameKey: "area.hokuriku",
        companyKey: "company.hokuriku",
        websiteURL: URL(string: "https://www.rikuden.co.jp/nw/denki-yoho/")!,
        csvStrategy: .dateBased(
            template: "https://www.rikuden.co.jp/nw/denki-yoho/csv/juyo_05_{date}.csv"
        ),
        csvFormat: .standard
    )

    /// 関西: かつては固定URL(juyo1_kansai.csv)だったが、サイト更新により
    /// 実績データは日付ベースの `juyo_06_{date}.csv` に移行済み（jisseki-latest.json で確認）
    static let kansai = PowerArea(
        id: "kansai",
        nameKey: "area.kansai",
        companyKey: "company.kansai",
        websiteURL: URL(string: "https://www.kansai-td.co.jp/denkiyoho/")!,
        csvStrategy: .dateBased(
            template: "https://www.kansai-td.co.jp/yamasou/juyo_06_{date}.csv"
        ),
        csvFormat: .standard
    )

    static let chugoku = PowerArea(
        id: "chugoku",
        nameKey: "area.chugoku",
        companyKey: "company.chugoku",
        websiteURL: URL(string: "https://www.energia.co.jp/nw/jukyuu/")!,
        csvStrategy: .dateBased(
            template: "https://www.energia.co.jp/nw/jukyuu/sys/juyo_07_{date}.csv"
        ),
        csvFormat: .standard
    )

    static let shikoku = PowerArea(
        id: "shikoku",
        nameKey: "area.shikoku",
        companyKey: "company.shikoku",
        websiteURL: URL(string: "https://www.yonden.co.jp/nw/denkiyoho/")!,
        csvStrategy: .dateBased(
            template: "https://www.yonden.co.jp/nw/denkiyoho/juyo_08_{date}.csv"
        ),
        csvFormat: .standard
    )

    static let kyushu = PowerArea(
        id: "kyushu",
        nameKey: "area.kyushu",
        companyKey: "company.kyushu",
        websiteURL: URL(string: "https://www.kyuden.co.jp/td_power_usages/pc.html")!,
        csvStrategy: .dateBased(
            template: "https://www.kyuden.co.jp/td_power_usages/csv/juyo-hourly-{date}.csv"
        ),
        csvFormat: CSVFormat(encoding: .cp932, intervalMinutes: 60, columns: .standard)
    )

    static let okinawa = PowerArea(
        id: "okinawa",
        nameKey: "area.okinawa",
        companyKey: "company.okinawa",
        websiteURL: URL(string: "https://www.okiden.co.jp/denki2/")!,
        csvStrategy: .dateBased(
            template: "https://www.okiden.co.jp/denki2/juyo_10_{date}.csv"
        ),
        csvFormat: .standard
    )
}
