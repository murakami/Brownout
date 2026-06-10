# Brownout

日本全国 10 エリアの「でんき予報」（電力需給予報）を表示する iOS アプリ。

## 概要

各送配電事業者が公開している CSV データを取得し、1 日分の電力需要実績・予測・供給力をラインチャートで表示します。エリアはアプリ内でいつでも切り替えられます。

## 対応エリア

| # | エリア | 事業者 |
|---|--------|--------|
| 1 | 北海道 | 北海道電力ネットワーク |
| 2 | 東北 | 東北電力ネットワーク |
| 3 | 東京 | 東京電力パワーグリッド |
| 4 | 中部 | 中部電力パワーグリッド |
| 5 | 北陸 | 北陸電力送配電 |
| 6 | 関西 | 関西電力送配電 |
| 7 | 中国 | 中国電力ネットワーク |
| 8 | 四国 | 四国電力送配電 |
| 9 | 九州 | 九州電力送配電 |
| 10 | 沖縄 | 沖縄電力 |

データソース一覧: [送配電網協議会 でんき予報まとめページ](https://www.tdgc.jp/areainfo/denki/)

## 技術仕様

| 項目 | 内容 |
|------|------|
| 言語 | Swift 6 |
| UI | SwiftUI |
| チャート | Swift Charts |
| 最低 iOS | iOS 26 |
| アーキテクチャ | MVVM（`@Observable`） |
| ローカライズ | 英語（ベース）・日本語 |

## 主な機能

- **ラインチャート**: 供給力（青破線）・実績需要（緑実線）・予測値（赤点線）を表示
- **使用率表示**: 最新の電力使用率をパーセントで表示（緑/黄/赤のカラーコーディング）
- **エリア切り替え**: ツールバーから 10 エリアを即時切り替え（選択状態は永続化）
- **ダーク/ライトモード対応**: システム設定に追従
- **About シート**: 全エリアの公式サイトへのリンク一覧

## ディレクトリ構成

```
Brownout/
├── BrownoutApp.swift
├── Models/
│   ├── PowerArea.swift          # 10エリア定義・CSV URL 戦略・フォーマット
│   └── ForecastEntry.swift      # データモデル
├── Services/
│   └── PowerForecastService.swift  # ネットワーク取得 + CSV パース（actor + CSVParser）
├── ViewModels/
│   └── ForecastViewModel.swift  # @Observable、エリア選択・AppStorage 永続化
└── Views/
    ├── ContentView.swift
    ├── AreaPickerView.swift
    ├── DemandChartView.swift
    ├── UsageRateView.swift
    ├── AboutView.swift
    └── ErrorView.swift
```

## ビルド要件

- Xcode 26 以降
- iOS 26 実機またはシミュレーター

## CSV URL の変更

各エリアの CSV URL は `PowerArea.swift` の `csvStrategy` プロパティで管理しています。URL が変わった場合はここのみ修正してください。

## ライセンス

Copyright © 2026 Yukio Murakami. All rights reserved.
