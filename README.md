# LivePhotos

iPhoneで撮影した動画から Live Photo を作成するiOSアプリです。

## 機能

- 動画の読み込み（フォトライブラリから選択）
- トリミング（1〜5秒の範囲を指定）
- 全体シークバーで動画の任意の位置にジャンプ
- フレーム選択（Live Photoの静止画として使うフレームを選択）
- Live Photo の生成・プレビュー・写真ライブラリへの保存

## 使い方

1. **動画を選択** — 「動画を選択」ボタンからフォトライブラリの動画を選ぶ
2. **トリミング** — 全体シークバーで大まかな位置に移動し、「ここから開始」で範囲を設定。下部のスライダーで微調整（1〜5秒）
3. **フレーム選択** — サムネイル一覧から Live Photo の代表フレームを選ぶ
4. **プレビュー・保存** — 生成された Live Photo を確認し、「保存」で写真ライブラリに保存

## 動作環境

- iOS 17.0+
- Xcode 16+
- Swift 6

## 技術構成

| レイヤー | 内容 |
|---------|------|
| App | エントリポイント |
| Presentation | SwiftUI画面・ViewModel・UIコンポーネント |
| Domain | プロトコル・モデル定義 |
| Infrastructure | AVFoundation / PhotoKit を使った各種サービス実装 |

### Live Photo 生成の流れ

1. `AVAssetExportSession` で動画をトリミング
2. 静止画をsRGBに正規化し、JPEG + MakerAppleメタデータとして書き出し
3. `AVAssetReader` / `AVAssetWriter` でパススルーremux（再エンコードなし）し、Content Identifier と still-image-time メタデータを付与
4. `PHLivePhoto.request` でプレビューを生成
5. `PHPhotoLibrary.performChanges` で写真ライブラリに保存
