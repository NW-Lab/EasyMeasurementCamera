# 開発ガイド

## プロジェクト構成

```
EasyMeasurementCamera/
├── EasyMeasurementCamera/
│   ├── EasyMeasurementCameraApp.swift      # アプリエントリーポイント
│   ├── ContentView.swift             # メインUI
│   ├── CameraManager.swift           # カメラ制御とトリガー管理
│   ├── RedLightDetector.swift        # 赤色LED検知エンジン
│   ├── MilkCrownCaptureController.swift  # 撮影制御ロジック（予備）
│   ├── Info.plist                    # アプリ設定と権限
│   └── Assets.xcassets/              # アセット
├── EasyMeasurementCamera.xcodeproj/        # Xcodeプロジェクト
└── README.md                         # ドキュメント
```

## 主要コンポーネント

### 1. CameraManager

カメラセッションの管理と240fps撮影を担当します。

**主な機能:**
- AVCaptureSessionの初期化と管理
- 240fpsフォーマットの自動選択
- 赤色LED検知の統合
- 自動録画制御
- 写真ライブラリへの保存

**重要なメソッド:**
- `setupCaptureSession()`: カメラセッションを構成
- `configure240FPS(for:)`: 240fps設定を適用
- `armCapture()`: 撮影準備（赤色検知を有効化）
- `startRecording()`: 録画開始
- `captureOutput(_:didOutput:from:)`: フレームごとに赤色を検知

### 2. RedLightDetector

リアルタイムで赤色LEDを検知します。

**検知アルゴリズム:**
1. サンプルバッファから画像の中央領域を抽出
2. RGB値を計算
3. 赤色の強度と選択性を評価
4. 閾値を超えた場合に検知成功

**調整可能なパラメータ:**
- `detectionThreshold`: 赤色の最小強度（デフォルト: 0.7）
- `redSelectivity`: 他の色との差の最小値（デフォルト: 0.3）
- `minimumBrightness`: 最小輝度（デフォルト: 0.4）

### 3. ContentView

ユーザーインターフェースを提供します。

**UI要素:**
- カメラプレビュー（フルスクリーン）
- 撮影準備ボタン
- キャンセルボタン
- 録画進捗表示
- 情報画面

## ビルドと実行

### 必要な環境

- Xcode 15.0以降
- iOS 17.0以降のデバイス
- Apple Developer アカウント（実機テスト用）

### ビルド手順

1. Xcodeでプロジェクトを開く
   ```bash
   open EasyMeasurementCamera.xcodeproj
   ```

2. 開発チームを設定
   - プロジェクト設定 > Signing & Capabilities
   - Teamを選択

3. ターゲットデバイスを選択
   - 240fps対応のiPhone（iPhone 8以降）

4. ビルドして実行
   - ⌘R または Run ボタン

## テスト

### 単体テスト

赤色検知のテストは実機でのみ可能です（シミュレーターはカメラ非対応）。

### 統合テスト

1. **赤色LED検知テスト**
   - 赤色LEDを用意
   - 「撮影準備」をタップ
   - LEDを点灯
   - 録画が自動開始されることを確認

2. **240fps撮影テスト**
   - 撮影した動画を写真アプリで確認
   - スローモーション再生が可能か確認
   - フレームレートを確認（QuickTime Playerで「ムービーインスペクタ」を表示）

3. **タイミングテスト**
   - 実際に水滴を30cmから落下
   - ミルククラウンが録画されているか確認

## デバッグ

### ログ出力

コンソールに詳細なログが出力されます：

```
✅ [CameraManager] 240fps configured: 1920x1080
✅ [CameraManager] Armed - Waiting for red LED trigger...
🔴 [RedLightDetector] RED LIGHT DETECTED! R:0.85 G:0.23 B:0.15 Confidence:0.78
🎬 [CameraManager] Recording started: milkcrown_1738389234.mov
🛑 [CameraManager] Recording stopped
✅ [CameraManager] Video saved to photo library
```

### よくある問題

**問題: 240fpsで撮影されない**
- 解決: デバイスが240fpsに対応しているか確認（iPhone 8以降）
- 確認方法: ログで "240fps configured" を確認

**問題: 赤色LEDが検知されない**
- 解決: 撮影環境を暗くする、LEDを明るくする
- 調整: `RedLightDetector` の閾値を下げる

**問題: 録画が保存されない**
- 解決: 写真ライブラリへのアクセス許可を確認
- 確認方法: 設定 > プライバシー > 写真

## カスタマイズ

### 落下高さの変更

`CameraManager.swift` の `dropHeight` を変更：

```swift
private let dropHeight: Double = 0.5  // 50cmに変更
```

### 録画時間の変更

`CameraManager.swift` の `recordingDuration` を変更：

```swift
private let recordingDuration: Double = 6.0  // 6秒に変更
```

### 検知感度の調整

`CameraManager.swift` の `configure240FPS` 内で調整：

```swift
redLightDetector.detectionThreshold = 0.6  // より敏感に
redLightDetector.redSelectivity = 0.2      // より寛容に
```

## パフォーマンス最適化

### 1. フレーム処理の最適化

`RedLightDetector` は画像の中央50%のみを処理することで、パフォーマンスを向上させています。

### 2. クールダウン期間

誤検知を防ぐため、検知後100msのクールダウン期間を設けています。

### 3. ビデオデータキューの分離

カメラセッションキューとビデオデータ処理キューを分離し、並列処理を実現しています。

## 今後の拡張案

1. **複数台同期撮影**
   - Wi-Fiマルチキャストでトリガー信号を送信
   - 複数のiPhoneで同時撮影

2. **落下高さの自動調整**
   - UIで落下高さを設定可能に
   - 録画タイミングを自動計算

3. **検知パラメータのUI調整**
   - 設定画面で閾値を調整可能に
   - リアルタイムプレビューで確認

4. **Bluetooth外部トリガー**
   - より確実なトリガー方式
   - ESP32などのマイコンと連携

## ライセンス

MIT License

## コントリビューション

プルリクエストを歓迎します！
