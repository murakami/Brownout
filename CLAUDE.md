# CLAUDE.md

## プロジェクト概要

**Brownout** — 日本全国10エリアの「でんき予報」（電力需給予報）を表示する iOS アプリ。

- 各エリアの電力実績需要・予測・供給力を1日分のラインチャートで表示する
- エリアはアプリ内で切り替え可能（初期: 東京）
- SwiftUI + Swift Charts で構成
- SNS 投稿機能なし

## 技術仕様

| 項目 | 内容 |
|------|------|
| 言語 | Swift 6 |
| UI | SwiftUI |
| チャート | Swift Charts |
| 最低 iOS | iOS 26 |
| アーキテクチャ | MVVM（`@Observable`） |
| ローカライズ | 英語（ベース）・日本語 |

## ディレクトリ構成

```
Brownout/
├── BrownoutApp.swift
├── Models/
│   ├── PowerArea.swift          # 10エリア定義・CSV URL 戦略
│   └── ForecastEntry.swift      # データモデル
├── Services/
│   └── PowerForecastService.swift  # ネットワーク + CSV パース（actor）
├── ViewModels/
│   └── ForecastViewModel.swift  # @Observable、エリア選択・永続化
└── Views/
    ├── ContentView.swift
    ├── AreaPickerView.swift      # エリア選択 Menu
    ├── DemandChartView.swift
    ├── UsageRateView.swift
    ├── AboutView.swift
    └── ErrorView.swift
```

## CSV データソース

各エリアの CSV URL は `PowerArea.swift` に定義。変更時は各エリアの `csvStrategy` を修正する。

| エリア | URL 戦略 | 備考 |
|--------|---------|------|
| 北海道 | 日付ベース | `{date}_hokkaido_jisseki.csv` |
| 東北 | 日付ベース | `juyo_02_{date}.csv` |
| 東京 | 日付ベース | `juyo-{date}.csv` |
| 中部 | 固定 | `juyo_cepco003.csv` ※URL 要確認 |
| 北陸 | 日付ベース | `juyo_05_{date}.csv` |
| 関西 | 日付ベース | `juyo_06_{date}.csv`（2026-07 訂正: 旧 `juyo1_kansai.csv` は更新停止・サイレントに古いデータを返すため廃止） |
| 中国 | 日付ベース | `juyo_07_{date}.csv` ※URL 要確認 |
| 四国 | 日付ベース | `juyo_08_{date}.csv` |
| 九州 | 日付ベース | `juyo-hourly-{date}.csv`（60分間隔） |
| 沖縄 | 日付ベース | `juyo_10_{date}.csv` |

多くのエリアは `juyo_0{連系線番号}_{date}.csv` という共通パターンに従う（例: 北陸=05, 関西=06, 中国=07, 四国=08, 沖縄=10）。
「固定URL」表記のエリア（中部・東京）でデータが更新されなくなった場合、まずこの連番パターンの日付ベースURLが存在しないか確認する。

固定URL・日付ベースURLを問わず、CSV の DATE 列が取得日と一致しない場合は `ForecastError.staleData` を投げて検知する
（`PowerForecastService.CSVParser` 参照）。固定URLがサイレントに古いデータを返し続けるケース（今回の関西の障害の原因）を
自動検出するための仕組みなので、新しいエリアを追加する際もこの検証ロジックに依存してよい。

参考: 送配電網協議会まとめページ https://www.tdgc.jp/areainfo/denki/

## 開発ルール

- `git commit` および `git push` はユーザーから明示的に依頼された場合のみ実行する
- ドキュメント類（要件・設計・仕様・計画）は `docs/` 配下に置く
- 新規エリア追加・URL 変更は `PowerArea.swift` のみ修正すれば済む設計
