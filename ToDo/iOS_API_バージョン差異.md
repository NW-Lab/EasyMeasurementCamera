# iOS API バージョン差異

このドキュメントは EasyShareCamera の開発で使用する AVFoundation API やカメラ関連機能の iOS バージョンごとの対応状況をまとめたものです。
最小対応バージョンの決定や機能実装時の参考資料として使用してください。

---

## AVFoundation 主要 API の対応バージョン

### カメラ制御 API

| API / 機能 | iOS 対応バージョン | 備考 |
|------------|-------------------|------|
| `AVCaptureDevice` 基本機能 | iOS 4.0+ | 基本的なカメラ制御 |
| `AVCaptureDevice.iso` | iOS 8.0+ | ISO感度制御 |
| `AVCaptureDevice.exposureDuration` | iOS 8.0+ | 露出時間制御 |
| `AVCaptureDevice.lensPosition` | iOS 8.0+ | フォーカス位置制御 |
| `AVCaptureDevice.videoZoomFactor` | iOS 7.0+ | ズーム制御 |
| `AVCaptureDevice.whiteBalanceMode` | iOS 8.0+ | ホワイトバランス制御 |
| `AVCaptureDevice.torchMode` | iOS 4.0+ | フラッシュライト制御 |

### 高速撮影・動画関連

| API / 機能 | iOS 対応バージョン | 備考 |
|------------|-------------------|------|
| スローモーション録画 | iOS 7.0+ | 基本的な高フレームレート |
| 240fps@1080p | iOS 9.0+ | デバイス依存 |
| 4K録画 | iOS 8.0+ | デバイス依存（iPhone 6s以降） |
| `AVCaptureMovieFileOutput` | iOS 4.0+ | 動画ファイル出力 |
| `AVAssetWriter` | iOS 4.1+ | カスタム動画書き出し |

### 通信・連携 API

| API / 機能 | iOS 対応バージョン | 備考 |
|------------|-------------------|------|
| `MultipeerConnectivity` | iOS 7.0+ | デバイス間通信（基本） |
| `MCNearbyServiceBrowser` | iOS 7.0+ | 近くのデバイス検索 |
| `MCNearbyServiceAdvertiser` | iOS 7.0+ | サービス公開 |
| `MCSession` 大容量転送改善 | iOS 11.0+ | 性能向上 |

### UI・ユーザビリティ

| API / 機能 | iOS 対応バージョン | 備考 |
|------------|-------------------|------|
| `AVCaptureVideoPreviewLayer` | iOS 4.0+ | カメラプレビュー |
| SwiftUI | iOS 13.0+ | モダン UI フレームワーク |
| SwiftUI `Camera` controls | iOS 17.0+ | 最新のカメラ UI コンポーネント |
| `UIKit` ベースの実装 | iOS 2.0+ | 従来の UI フレームワーク |

---

## iOS バージョン別 主要機能まとめ

### iOS 17.0+ (2023年)
**新機能・改善点:**
- SwiftUI でのカメラコントロール UI 大幅改善
- AVFoundation のパフォーマンス向上
- MultipeerConnectivity の安定性向上

**対応デバイス:** iPhone 12 以降、iPad (第6世代) 以降

### iOS 16.0+ (2022年)
**新機能・改善点:**
- カメラ API の安定性向上
- バックグラウンド処理の改善
- SwiftUI との統合強化

**対応デバイス:** iPhone 8 以降、iPad (第5世代) 以降

### iOS 15.0+ (2021年)
**新機能・改善点:**
- AVFoundation の大幅なパフォーマンス改善
- MultipeerConnectivity の信頼性向上
- 新しいカメラ機能 API

**対応デバイス:** iPhone 6s 以降、iPad (第5世代) 以降

### iOS 14.0+ (2020年)
**新機能・改善点:**
- カメラ権限の詳細化
- SwiftUI 2.0 との統合
- バックグラウンド録画の制限強化

**対応デバイス:** iPhone 6s 以降、iPad Air 2 以降

### iOS 13.0+ (2019年)
**重要な変更点:**
- SwiftUI の導入
- Dark Mode 対応
- カメラ API のセキュリティ強化

**対応デバイス:** iPhone 6s 以降、iPad Air 2 以降

---

## 推奨最小対応バージョン

### EasyShareCamera プロジェクトでの推奨

**最小対応バージョン: iOS 17.0**

**理由:**
1. **SwiftUI カメラコントロール**: iOS 17 で本格的なカメラ UI コンポーネントが導入
2. **AVFoundation の最新機能**: 最新の API とパフォーマンス最適化
3. **MultipeerConnectivity の完成度**: 最高レベルの安定性と性能
4. **モダン開発体験**: 最新の SwiftUI 機能をフル活用可能
5. **将来性**: 長期間のサポートとアップデート対応

### iOS 17+ での利点

**SwiftUI カメラ機能:**
- 標準的なカメラコントロール UI
- ネイティブなカメラプレビュー統合
- Apple 標準カメラアプリに近い UX の実現が容易

**開発効率:**
- 最新の API と開発ツール
- Xcode の最新機能をフル活用
- コード量の削減とメンテナンス性向上

**性能:**
- 最適化された AVFoundation
- 低遅延の MultipeerConnectivity
- バッテリー効率の向上

### 対応デバイス（iOS 17.0+）

| デバイス | 対応状況 | 備考 |
|----------|----------|------|
| **iPhone** | iPhone 12 以降 | 全機能対応 |
| **iPad** | iPad (第6世代) 以降 | 全機能対応 |
| **iPad Pro** | 全世代対応 | 最高性能 |
| **iPad Air** | iPad Air (第3世代) 以降 | 高性能 |
| **iPad mini** | iPad mini (第5世代) 以降 | コンパクト |

### 実装戦略・作業手順について

詳細な実装戦略、開発フェーズ、作業手順については `ToDo/作業手順.md` を参照してください。
このファイルは iOS API の技術的差異に特化しています。

---

## 開発時の注意点

### 1. API 利用可能性の確認
```swift
if #available(iOS 15.0, *) {
    // iOS 15 以降の機能
} else {
    // フォールバック処理
}
```

### 2. デバイス機能の確認
```swift
guard let device = AVCaptureDevice.default(for: .video) else { return }
if device.hasFlash {
    // フラッシュ機能あり
}
```

### 3. MultipeerConnectivity の対応
- iOS 11 以降で大容量データ転送が安定
- iOS 15 以降で接続の信頼性が大幅向上

### 4. SwiftUI での開発方針
- **採用決定**: iOS 17+ での SwiftUI ベース実装
- **利点**: 最新カメラ UI コンポーネント、開発効率、将来性
- **UIKit との併用**: 必要に応じて UIViewRepresentable で補完

---

## 参考リンク

- [Apple Developer Documentation - AVFoundation](https://developer.apple.com/documentation/avfoundation)
- [iOS Device Compatibility](https://developer.apple.com/support/app-store/)
- [SwiftUI Availability](https://developer.apple.com/documentation/swiftui)