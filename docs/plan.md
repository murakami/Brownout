# Brownout リニューアル計画

## 背景・目的

2016年に作成した「Brownout」iOS アプリ（Swift 2 / Xcode 7.2 時代のテンプレート）を、現代の iOS 開発標準で全面的に作り直す。当初は TEPCO 専用として設計したが、仕様変更により日本全国10エリア対応に拡張した。

Twitter 投稿・tden.me リンク・Debug タブは廃止し、でんき予報の閲覧機能のみに絞る。

---

## 現状分析（旧バージョン）

| 項目 | 旧バージョン |
|------|------|
| 言語 | Swift 2.0 |
| フレームワーク | UIKit + Storyboard |
| 最低 iOS | iOS 9 相当 |
| CI | Travis CI（`.travis.yml`、現在未使用） |
| 実装状態 | テンプレートのみ、実装なし |

---

## 新しいアプリ仕様

### 技術スタック

| 項目 | 採用技術 |
|------|---------|
| 言語 | Swift 6 |
| UI フレームワーク | SwiftUI |
| チャート | Swift Charts |
| 非同期処理 | Swift Concurrency (async/await) |
| 最低 iOS | iOS 26 |
| CI | 廃止（`.travis.yml` 削除） |

### 画面構成

タブバーなし。NavigationStack + ツールバー左端のエリア選択 Menu。About はシートで表示。

```
ContentView（メイン画面）
├── NavigationStack
│   ├── ツールバー左: AreaPickerView（エリア選択 Menu）
│   ├── ツールバー右: About ボタン + 更新ボタン
│   ├── UsageRateView（現在の使用率 %）
│   └── DemandChartView（ラインチャート）
│       ├── 青破線: 最大供給力
│       ├── 緑実線: 実績需要
│       └── 赤点線: 予測値
└── AboutView（Sheet）
    ├── アプリ名・バージョン
    ├── 送配電網協議会まとめページへのリンク
    └── 全10エリア公式ページへのリンク一覧
```

---

## ファイル構成（現在）

```
Brownout/
├── Brownout.xcodeproj/
├── Brownout/
│   ├── BrownoutApp.swift
│   ├── Models/
│   │   ├── PowerArea.swift           # 10エリア定義・URL 戦略・CSV フォーマット
│   │   └── ForecastEntry.swift       # データモデル（ForecastEntry / DailyForecast）
│   ├── Services/
│   │   └── PowerForecastService.swift # CSV フェッチ + パース（actor）
│   ├── ViewModels/
│   │   └── ForecastViewModel.swift   # @Observable、エリア選択・AppStorage 永続化
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── AreaPickerView.swift      # エリア選択 Menu
│   │   ├── DemandChartView.swift
│   │   ├── UsageRateView.swift
│   │   ├── AboutView.swift
│   │   └── ErrorView.swift
│   ├── en.lproj/Localizable.strings
│   └── ja.lproj/Localizable.strings
├── BrownoutTests/BrownoutTests.swift
├── docs/
│   ├── plan.md
│   ├── requirements.md
│   ├── design.md
│   ├── spec.md
│   └── images/
├── CLAUDE.md
└── README.md
```

---

## 実装ステップ

### Phase 1: プロジェクト整備 ✅

- [x] `.travis.yml` 削除（新テンプレートに存在しない）
- [x] Xcode プロジェクトを Swift 6 / iOS 26 で新規作成（SwiftUI テンプレート）
- [x] 既存 Storyboard・ViewController を削除（新テンプレートのため不要）
- [x] `CLAUDE.md` 作成

### Phase 2: データ層 ✅

- [x] `ForecastEntry` / `DailyForecast` モデル定義
- [x] `PowerForecastService`（actor）— URLSession で CSV 取得 + パース
- [x] `ForecastViewModel`（`@Observable @MainActor`）— データ保持・更新

### Phase 3: UI 層 ✅

- [x] `ContentView` — NavigationStack、ツールバー、状態分岐（ローディング/エラー/正常）
- [x] `DemandChartView` — Swift Charts で3系列ライン描画、現在時刻マーカー
- [x] `UsageRateView` — 現在使用率、カラーコーディング
- [x] `AboutView` — アプリ情報 + 全エリアリンク
- [x] `ErrorView` — エラーメッセージ + 再試行 + 公式サイトリンク

### Phase 4: 全国対応（仕様変更により追加）✅

- [x] `PowerArea.swift` — 10エリア定義（URL 戦略・CSV フォーマット）
- [x] `CSVURLStrategy` — 日付ベース / 固定 URL の2方式
- [x] `PowerForecastService` をエリア引数対応に変更
- [x] `AreaPickerView` — エリア選択 Menu（ツールバー左端）
- [x] `ForecastViewModel` に `selectedArea`（`@AppStorage` 永続化）追加
- [x] ローカライズ文字列にエリア名・会社名（英語/日本語）追加

### Phase 5: 仕上げ 🔄 進行中

- [x] Xcode でビルド・実機起動確認（iOS 26 デプロイターゲット変更済み）
- [x] HTTP 403 対策: `URLRequest` に Safari iOS User-Agent / Referer ヘッダー追加
- [x] CSV パーサー修正: 日付形式 `YYYY/M/D`（9文字）対応・actual=0 を nil 扱いに修正
- [x] `ColumnMap.standard` を capacity:5 に修正（東北・北陸・九州・関西・中部・四国・沖縄）
- [x] 東京 URL 更新: `juyo-{date}.csv` → 固定 `juyo-s1-j.csv`（TEPCO の新 URL）
- [x] 北海道 URL 更新: `_hokkaido_jisseki.csv` → `juyo_01_{date}.csv`（標準形式）
- [x] 中部 URL 更新: `/denkiyoho/juyo_cepco003.csv` → `/denki_yoho_content_data/juyo_cepco003.csv`
- [x] 四国 URL 更新: 固定 `juyo_shikoku.csv` → 日付ベース `juyo_08_{date}.csv`
- [x] 中国 URL 更新: `/nw/jukyuu/csv/` → `/nw/jukyuu/sys/juyo_07_{date}.csv`
- [ ] 実機で全エリアのデータ取得確認
- [ ] ダーク/ライトモード表示確認
- [ ] `BrownoutTests` に CSV パーステスト追加
- [ ] `README.md` 更新

---

## 廃止した機能

| 機能 | 理由 |
|------|------|
| Twitter（SNS）投稿 | SNS 連携不要の方針 |
| tden.me リンク | サービス終了済み |
| Debug タブ | 不要 |
| その他タブ | コンテンツなし |
| Travis CI | 使用していない |
