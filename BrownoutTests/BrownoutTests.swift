import Testing
import Foundation
@testable import Brownout

struct CSVParserTests {

    // 東北・北陸・九州等の標準 6 列形式（capacity = col 5）
    private let standardCSV =
        "2026/6/10 13:47 UPDATE\n" +
        "ピーク時供給力(万kW),時間帯,供給力情報更新日,供給力情報更新時刻,ピーク時予備率(%),ピーク時使用率(%)\n" +
        "1172,14:00〜15:00,6月10日,13:42,26,79\n" +
        "\n" +
        "DATE,TIME,当日実績(万kW),予測値(万kW),使用率(%),供給力(万kW)\n" +
        "2026/6/10,0:00,698,691,86,807\n" +
        "2026/6/10,1:00,712,705,85,836\n" +
        "2026/6/10,2:00,0,720,0,840\n" +
        "2026/6/10,3:00,0,730,0,850\n"

    // 東京(TEPCO)の 5+1 列形式（capacity = col 4、複数 DATE セクション含む）
    private let tepcoCSV =
        "2026/6/10 13:45 UPDATE\n" +
        "ピーク時供給力(万kW),時間帯,供給力情報更新日,供給力情報更新時刻,ピーク時予備率(%),ピーク時使用率(%)\n" +
        "3775,11:00〜12:00,6/10,13:40,24,80\n" +
        "\n" +
        "DATE,TIME,当日実績(万kW),需要電力予測値(万kW),供給力予測値(万kW),使用率(%)\n" +
        "2026/6/10,0:00,2359,2342,2677,88\n" +
        "2026/6/10,1:00,2235,2234,2564,87\n" +
        "2026/6/10,2:00,0,2216,2549,\n" +
        "2026/6/10,3:00,0,2237,2589,\n" +
        "\n" +
        "DATE,TIME,曜日,ピーク時供給力(万kW),更新日,更新時間,d1,d2,d3,d4,d5,d6,使用率実績,使用率予想,d7,使用率ピーク時供給力\n" +
        "2026/6/10,0:00,3,2677,2026/6/10,13:40,,,,,,,88,0,,2677\n" +
        "2026/6/10,1:00,3,2564,2026/6/10,13:40,,,,,,,87,0,,2564\n"

    private var testDate: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var dc = DateComponents()
        dc.year = 2026; dc.month = 6; dc.day = 10
        dc.hour = 0; dc.minute = 0; dc.second = 0
        dc.timeZone = cal.timeZone
        return cal.date(from: dc)!
    }

    // MARK: 基本パース

    @Test func standardFormatParsesCorrectly() throws {
        let data = standardCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tohoku, date: testDate)
        #expect(result.entries.count == 4)
        #expect(result.entries[0].actual == 698)
        #expect(result.entries[0].predicted == 691)
        #expect(result.entries[0].capacity == 807)
    }

    // MARK: capacity 列位置

    @Test func standardFormatCapacityAtColumn5() throws {
        let data = standardCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tohoku, date: testDate)
        // 供給力 = col5 = 807、使用率(col4 = 86)と混同しないこと
        #expect(result.entries[0].capacity == 807)
        #expect(result.entries[0].capacity != 86)
    }

    @Test func tepcoFormatCapacityAtColumn4() throws {
        let data = tepcoCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tokyo, date: testDate)
        // 供給力 = col4 = 2677、使用率(col5 = 88)と混同しないこと
        #expect(result.entries[0].capacity == 2677)
        #expect(result.entries[0].capacity != 88)
    }

    // MARK: actual = 0 → nil

    @Test func actualZeroTreatedAsNil() throws {
        let data = standardCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tohoku, date: testDate)
        // 2:00, 3:00 の実績 = 0 → nil
        #expect(result.entries[2].actual == nil)
        #expect(result.entries[3].actual == nil)
        // 0:00, 1:00 の実績は非ゼロ → そのまま
        #expect(result.entries[0].actual == 698)
        #expect(result.entries[1].actual == 712)
    }

    // MARK: 重複セクション除外（TEPCO 2nd セクション対策）

    @Test func duplicateSectionIsIgnored() throws {
        let data = tepcoCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tokyo, date: testDate)
        // 1st セクション 4 行のみ採用、2nd セクション（同一タイムスタンプ）は無視
        #expect(result.entries.count == 4)
        // 1st セクションの実績が採用されていること（2nd セクションなら col2=3 が実績になるはず）
        #expect(result.entries[0].actual == 2359)
    }

    // MARK: 日付フォーマット（ゼロパディングなし）

    @Test func shortDateFormatParsed() throws {
        let csv =
            "DATE,TIME,当日実績(万kW),予測値(万kW),使用率(%),供給力(万kW)\n" +
            "2026/6/9,0:00,500,490,85,600\n" +
            "2026/6/9,1:00,490,485,84,600\n"
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var dc = DateComponents()
        dc.year = 2026; dc.month = 6; dc.day = 9; dc.hour = 0; dc.timeZone = cal.timeZone
        let date = cal.date(from: dc)!
        let data = csv.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tohoku, date: date)
        #expect(result.entries.count == 2)
        #expect(result.entries[0].actual == 500)
    }

    // MARK: データなしエラー

    @Test func emptyCSVThrowsNoData() {
        let data = "some header\nanother line\n".data(using: .utf8)!
        #expect {
            try CSVParser.parse(data, area: .tohoku, date: testDate)
        } throws: { error in
            if case ForecastError.noData = error { return true }
            return false
        }
    }

    // MARK: currentUsageRate

    @Test func usageRateCalculation() throws {
        let data = standardCSV.data(using: .utf8)!
        let result = try CSVParser.parse(data, area: .tohoku, date: testDate)
        // latestActualEntry = 1:00（実績 712、供給力 836）
        let rate = result.currentUsageRate
        #expect(rate != nil)
        if let r = rate {
            #expect(abs(r - (712.0 / 836.0 * 100)) < 0.01)
        }
    }
}
