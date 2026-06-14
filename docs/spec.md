# 仕様書

## CSV データ仕様（全エリア共通）

### 共通フォーマット

各社の CSV は先頭数行がメタ情報・ヘッダー行（スキップ対象）。データ行の形式:

```
DATE,TIME,実績(万kW),予測(万kW),供給力(万kW)
2026/06/10,0:00,,4200,6000
2026/06/10,0:30,,4100,6000
...
2026/06/10,9:00,4500,4480,6000
...
2026/06/10,23:30,,3800,6000
```

| 列 | 型 | 説明 |
|----|-----|------|
| DATE | String (`YYYY/MM/DD`) | 日付 |
| TIME | String (`H:MM`) | 時刻（JST） |
| 実績(万kW) | Double または空 | 過去時刻のみ値あり |
| 予測(万kW) | Double または空 | 予測値（未来時刻） |
| 供給力(万kW) | Double | 当日の最大供給能力（全行同値） |

- エンコーディング: Shift-JIS（UTF-8 へのフォールバックあり）
- `24:00` 行が含まれる場合は除外

### データ行の判定ロジック

```
DATE 列が "YYYY/MM/DD" 形式（10文字、先頭4桁が数字、5文字目が "/"）
かつ列数が ColumnMap で指定された最大インデックス + 1 以上
```

---

## 各エリア CSV URL 仕様

| エリア | URL 戦略 | 間隔 | URL / テンプレート（`{date}` = YYYYMMDD） |
|--------|---------|------|----------------------------------------|
| 北海道 | 日付ベース | 30分 | `https://denkiyoho.hepco.co.jp/area/data/juyo_01_{date}.csv` |
| 東北 | 日付ベース | 30分 | `https://setsuden.nw.tohoku-epco.co.jp/common/demand/juyo_02_{date}.csv` |
| 東京 | 固定 | 30分 | `https://www.tepco.co.jp/forecast/html/images/juyo-s1-j.csv` |
| 中部 | 固定 | 30分 | `https://powergrid.chuden.co.jp/denki_yoho_content_data/juyo_cepco003.csv` |
| 北陸 | 日付ベース | 30分 | `https://www.rikuden.co.jp/nw/denki-yoho/csv/juyo_05_{date}.csv` |
| 関西 | 固定 | 30分 | `https://www.kansai-td.co.jp/yamasou/juyo1_kansai.csv` |
| 中国 | 日付ベース | 30分 | `https://www.energia.co.jp/nw/jukyuu/sys/juyo_07_{date}.csv` |
| 四国 | 日付ベース | 30分 | `https://www.yonden.co.jp/nw/denkiyoho/juyo_08_{date}.csv` |
| 九州 | 日付ベース | 60分 | `https://www.kyuden.co.jp/td_power_usages/csv/juyo-hourly-{date}.csv` |
| 沖縄 | 日付ベース | 30分 | `https://www.okiden.co.jp/denki2/juyo_10_{date}.csv` |

参考まとめページ（送配電網協議会）: `https://www.tdgc.jp/areainfo/denki/`

---

## 画面仕様

### メイン画面（ContentView）

**ナビゲーションバー**:
- タイトル: "Power Forecast" / "でんき予報"（inline 表示）
- 左: `AreaPickerView`（エリア名 + `chevron.down`）
- 右: 更新ボタン（`arrow.clockwise`）+ About ボタン（`info.circle`）

**状態一覧**:

| 状態 | 表示 |
|------|------|
| 読み込み中 | `ProgressView` + "Loading…" |
| エラー | `ErrorView` |
| 正常 | `ScrollView { UsageRateView + DemandChartView }` |

プルトゥリフレッシュ（`.refreshable`）対応。

---

### エリア選択（AreaPickerView）

ナビゲーションバー左端に `Menu` として表示。

```
[ Tokyo ▾ ]    ← タップでメニュー展開
  ✓ Tokyo
    Hokkaido
    Tohoku
    ...
```

- 選択中のエリアにチェックマーク
- エリア変更時に `ForecastViewModel.selectedArea` を更新し、自動リロード
- 選択エリアは `@AppStorage("selectedAreaID")` でアプリ再起動後も保持

---

### 使用率ビュー（UsageRateView）

```
┌──────────────────────────────────────┐
│ Usage Rate       Actual  4,500万kW   │
│     72%        Supply  6,000万kW     │
└──────────────────────────────────────┘
```

- 使用率の数値: 52pt、Rounded、Bold
- カラー: 緑（< 80%）/ 黄（80–90%）/ 赤（≥ 90%）
- データなし時: "--" を secondary で表示

---

### チャートビュー（DemandChartView）

**凡例**（チャート上部、横並び）:

| 色 | 線スタイル | 系列名 |
|----|---------|--------|
| 🔵 青 | 破線（5-3） | Max Supply（最大供給力） |
| 🟢 緑 | 実線（太） | Actual（実績） |
| 🔴 赤 | 点線（2-2） | Forecast（予測） |

**チャートエリア**:
- 高さ: 280pt
- Y スケール: 全データの最小値 × 0.95 〜 最大値 × 1.05
- X 軸: 3時間刻み（0:00, 3:00 … 21:00）
- Y 軸: 整数値（万kW 単位）
- 現在時刻: 白半透明縦線 + "Now" アノテーション（上部左寄せ）
- チャート内蔵凡例: 非表示（`.chartLegend(.hidden)`、独自凡例を使用）

**単位ラベル**（チャート下部右寄せ）:
- 英語: "Unit: 万kW  (×10,000 kW)"
- 日本語: "単位: 万kW"

---

### エラービュー（ErrorView）

```
           ⚠️

    Failed to fetch data
    <エラー詳細メッセージ>

       [  Retry  ]

    Open official website ↗    ← 選択中エリアの公式ページを開く
```

- エリアごとの公式ページ URL は `PowerArea.websiteURL` から取得

---

### About 画面（AboutView）

Sheet として表示。

```
💡  Brownout
    Japan Power Forecast Viewer

─ Data ─────────────────────────────
  Area Power Forecasts (TDGC) ↗
  Hokkaido ↗
  Tohoku ↗
  Tokyo ↗
  ... (全10エリア)

─ Version ───────────────────────────
  App Version         2.0
```

---

## 使用率アルゴリズム

```
currentUsageRate = latestActual / capacity × 100
```

`latestActual`: `DailyForecast.entries` を末尾から検索して最初に `actual != nil` のエントリ

---

## ローカライズ文字列一覧

### 共通 UI

| キー | 英語 | 日本語 |
|------|------|--------|
| `Power Forecast` | Power Forecast | でんき予報 |
| `Loading…` | Loading… | 読み込み中… |
| `Failed to fetch data` | Failed to fetch data | データを取得できませんでした |
| `Retry` | Retry | 再試行 |
| `Open official website` | Open official website | 公式サイトを開く |
| `Usage Rate` | Usage Rate | 使用率 |
| `Actual` | Actual | 実績 |
| `Supply Capacity` | Supply Capacity | 供給力 |
| `Now` | Now | 現在 |
| `Max Supply` | Max Supply | 最大供給力 |
| `Forecast` | Forecast | 予測 |
| `Unit: 万kW  (×10,000 kW)` | Unit: 万kW (×10,000 kW) | 単位: 万kW |
| `About` | About | アプリ情報 |
| `Japan Power Forecast Viewer` | Japan Power Forecast Viewer | でんき予報ビューア |
| `Data` | Data | データ |
| `Area Power Forecasts (TDGC)` | Area Power Forecasts (TDGC) | 各エリアのでんき予報（送配電網協議会） |
| `App Version` | App Version | バージョン |
| `Close` | Close | 閉じる |

### エリア名

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

### 会社名

| キー | 英語 | 日本語 |
|------|------|--------|
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

### エラーメッセージ

| キー | 英語 | 日本語 |
|------|------|--------|
| `error.invalid_url` | Invalid URL | URLが無効です |
| `error.http %lld` | HTTP error: %lld | HTTPエラー: %lld |
| `error.parse %@` | Data parse error: %@ | データ解析エラー: %@ |
| `error.no_data` | No data found. The URL may have changed. | データが見つかりませんでした。URLが変更された可能性があります。 |

---

## 依存ライブラリ

外部ライブラリ依存なし。すべて Apple 標準フレームワークで実装:

| フレームワーク | 用途 |
|--------------|------|
| SwiftUI | UI |
| Charts | ラインチャート |
| Foundation | URLSession, CSV パース |
