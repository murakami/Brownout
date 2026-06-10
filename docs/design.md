# 設計書

## アーキテクチャ概要

MVVM パターンを採用。データフローは一方向（Service → ViewModel → View）。

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  ContentView                                 │
│    ├── AreaPickerView（エリア選択）            │
│    ├── UsageRateView                         │
│    ├── DemandChartView                       │
│    ├── ErrorView                             │
│    └── AboutView (Sheet)                     │
└──────────────────┬──────────────────────────┘
                   │ observes
┌──────────────────▼──────────────────────────┐
│              ForecastViewModel               │
│  @Observable @MainActor                      │
│  selectedArea: PowerArea                     │
│  forecast: DailyForecast?                    │
│  isLoading: Bool                             │
│  error: ForecastError?                       │
└──────────────────┬──────────────────────────┘
                   │ async/await
┌──────────────────▼──────────────────────────┐
│           PowerForecastService               │
│  actor (スレッドセーフ)                        │
│  fetchForecast(area:date:) async throws      │
│  parseCSV(data:area:) throws                 │
└──────────────────┬──────────────────────────┘
                   │ URLSession
         各社 でんき予報 CSV
```

---

## ディレクトリ構成

```
Brownout/
├── BrownoutApp.swift
├── Models/
│   ├── PowerArea.swift         # エリア定義（10社）
│   ├── ForecastEntry.swift     # データモデル
│   └── CSVURLStrategy.swift    # URL解決戦略
├── Services/
│   ├── PowerForecastService.swift  # ネットワーク + CSV パース
│   └── CSVParser.swift             # CSV パーサー
├── ViewModels/
│   └── ForecastViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── AreaPickerView.swift        # エリア選択ピッカー
│   ├── DemandChartView.swift
│   ├── UsageRateView.swift
│   ├── AboutView.swift
│   └── ErrorView.swift
├── en.lproj/Localizable.strings
└── ja.lproj/Localizable.strings
```

---

## エリアモデル設計

### PowerArea

```swift
struct PowerArea: Identifiable, Hashable, Sendable {
    let id: String           // 識別子 ("tokyo", "kansai" 等)
    let nameKey: String      // ローカライズキー
    let companyKey: String   // 会社名ローカライズキー
    let websiteURL: URL
    let csvStrategy: CSVURLStrategy
    let csvFormat: CSVFormat
}
```

### CSVURLStrategy

各社の CSV URL は大きく2種類:

```swift
enum CSVURLStrategy: Sendable {
    case dateBased(template: String)
    // 例: "https://www.okiden.co.jp/denki2/juyo_10_{date}.csv"
    // {date} → "YYYYMMDD"

    case fixed(url: String)
    // 例: "https://www.kansai-td.co.jp/yamasou/juyo1_kansai.csv"
}
```

### CSVFormat

各社でフォーマットが微妙に異なる（列数・ヘッダー行数等）:

```swift
struct CSVFormat: Sendable {
    let encoding: String.Encoding   // .shiftJIS or .utf8
    let interval: Int               // 分単位（30 or 60）
    let columnOrder: ColumnOrder    // 列の順序指定
}

struct ColumnOrder: Sendable {
    let date: Int        // デフォルト: 0
    let time: Int        // デフォルト: 1
    let actual: Int      // デフォルト: 2
    let predicted: Int   // デフォルト: 3
    let capacity: Int    // デフォルト: 4
}
```

### 全エリア定義

```swift
extension PowerArea {
    static let all: [PowerArea] = [
        .hokkaido, .tohoku, .tokyo,
        .chubu, .hokuriku, .kansai,
        .chugoku, .shikoku, .kyushu, .okinawa
    ]

    static let tokyo = PowerArea(
        id: "tokyo",
        nameKey: "area.tokyo",
        companyKey: "company.tokyo",
        websiteURL: URL(string: "https://www.tepco.co.jp/forecast/")!,
        csvStrategy: .dateBased(
            template: "https://www.tepco.co.jp/forecast/html/images/juyo-{date}.csv"
        ),
        csvFormat: CSVFormat(encoding: .shiftJIS, interval: 30, columnOrder: .default)
    )
    // ... 他9エリア
}
```

---

## 各エリア CSV URL 一覧

| エリア | URL 戦略 | テンプレート / 固定 URL |
|--------|---------|----------------------|
| 北海道 | 日付ベース | `https://denkiyoho.hepco.co.jp/area/data/{date}_hokkaido_jisseki.csv` |
| 東北 | 日付ベース | `https://setsuden.nw.tohoku-epco.co.jp/common/demand/juyo_02_{date}.csv` |
| 東京 | 日付ベース | `https://www.tepco.co.jp/forecast/html/images/juyo-{date}.csv` |
| 中部 | 日付ベース | `https://powergrid.chuden.co.jp/denkiyoho/juyo_cepco003.csv` ※要確認 |
| 北陸 | 日付ベース | `https://www.rikuden.co.jp/nw/denki-yoho/csv/juyo_05_{date}.csv` |
| 関西 | 固定 | `https://www.kansai-td.co.jp/yamasou/juyo1_kansai.csv` |
| 中国 | 日付ベース | `https://www.energia.co.jp/nw/jukyuu/csv/juyo_07_{date}.csv` ※要確認 |
| 四国 | 固定 | `https://www.yonden.co.jp/nw/denkiyoho/juyo_shikoku.csv` |
| 九州 | 日付ベース | `https://www.kyuden.co.jp/td_power_usages/csv/juyo-hourly-{date}.csv` |
| 沖縄 | 日付ベース | `https://www.okiden.co.jp/denki2/juyo_10_{date}.csv` |

> **注意**: ※要確認の URL は調査中。`PowerArea` の定義を更新することで容易に変更可能な設計とする。  
> 九州は 60 分間隔（他社は 30 分間隔）。

---

## サービス設計

### PowerForecastService（actor）

```swift
actor PowerForecastService {
    static let shared = PowerForecastService()

    func fetchForecast(area: PowerArea, date: Date = .now) async throws -> DailyForecast
    private func resolveURL(strategy: CSVURLStrategy, date: Date) throws -> URL
    private func parseCSV(_ data: Data, area: PowerArea, date: Date) throws -> DailyForecast
}
```

**URL 解決**:
- `dateBased(template:)` → `{date}` を `yyyyMMdd` 形式の日付文字列に置換
- `fixed(url:)` → そのまま使用

**CSVパース戦略**:
1. 指定エンコーディングでデコード（フォールバック: UTF-8）
2. 各行を `,` で分割
3. DATE 列が `YYYY/MM/DD` 形式の行のみ処理
4. `ColumnOrder` に従って各列を読み取り
5. 無効な時刻・空行を除外

---

## ViewModel 設計

### ForecastViewModel（@Observable, @MainActor）

```swift
@MainActor @Observable
final class ForecastViewModel {
    // エリア選択（UserDefaults に永続化）
    var selectedArea: PowerArea = PowerArea.tokyo {
        didSet {
            Task { await load() }
        }
    }

    var forecast: DailyForecast?
    var isLoading: Bool = false
    var error: ForecastError?

    func load(date: Date = .now) async
}
```

エリア変更時に自動リロード。`@AppStorage` で選択エリアを永続化。

---

## View 設計

### ContentView

ナビゲーションバー左端にエリア選択ピッカーを配置:

```
[< Tokyo ▾]          [↺] [ℹ]
─────────────────────────────
  72%              Actual 4,500万kW
                  Supply  6,000万kW
─────────────────────────────
  [ラインチャート]
```

### AreaPickerView

`Picker` または `Menu` でエリアを選択:

```swift
Menu {
    ForEach(PowerArea.all) { area in
        Button(action: { viewModel.selectedArea = area }) {
            Label(area.localizedName, systemImage: area.isSelected ? "checkmark" : "")
        }
    }
} label: {
    HStack {
        Text(viewModel.selectedArea.localizedName)
        Image(systemName: "chevron.down")
    }
}
```

---

## ローカライズ追加キー

| キー | 英語 | 日本語 |
|------|------|--------|
| `area.hokkaido` | Hokkaido | 北海道 |
| `area.tohoku` | Tohoku | 東北 |
| `area.tokyo` | Tokyo | 東京 |
| `area.chubu` | Chubu | 中部 |
| `area.hokuriku` | Hokuriku | 北陸 |
| `area.kansai` | Kansai | 関西 |
| `area.chugoku` | Chugoku | 中国 |
| `area.shikoku` | Shikoku | 四国 |
| `area.kyushu` | Kyushu | 九州 |
| `area.okinawa` | Okinawa | 沖縄 |
| `company.hokkaido` | Hokkaido Power Network | 北海道電力ネットワーク |
| `company.tohoku` | Tohoku Power Network | 東北電力ネットワーク |
| `company.tokyo` | TEPCO Power Grid | 東京電力パワーグリッド |
| `company.chubu` | Chubu Power Grid | 中部電力パワーグリッド |
| `company.hokuriku` | Hokuriku Power Transmission | 北陸電力送配電 |
| `company.kansai` | Kansai Power Transmission | 関西電力送配電 |
| `company.chugoku` | Chugoku Power Network | 中国電力ネットワーク |
| `company.shikoku` | Shikoku Power Transmission | 四国電力送配電 |
| `company.kyushu` | Kyushu Power Transmission | 九州電力送配電 |
| `company.okinawa` | Okinawa Electric Power | 沖縄電力 |
| `Select Area` | Select Area | エリアを選択 |
