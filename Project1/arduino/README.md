# Arduino水滴トリガーシステム（Seeed XIAO + Neopixel対応）

フォトカプラで水滴を検知し、Neopixel 8連で赤色・白色を点灯させてiPhoneに撮影トリガーを送るシステムです。

## ハードウェア構成

### 必要な部品

| 部品 | 数量 | 備考 |
|---|---|---|
| Seeed XIAO SAMD21 | 1 | ESP32-S3でも互換 |
| フォトカプラモジュール | 1 | 3.3V動作、赤外線LED + フォトトランジスタ |
| Neopixel 8連 | 1 | WS2812B、5V動作 |
| 赤色LED（オプション） | 1 | 5mm、バックアップ用 |
| 白色LED（オプション） | 1 | 5mm、バックアップ用 |
| 抵抗 220Ω（オプション） | 2 | 個別LED用 |
| ブレッドボード | 1 | プロトタイピング用 |
| ジャンパーワイヤー | 適量 | オス-オス、オス-メス |
| USB-Cケーブル | 1 | 電源・プログラミング用 |

### 回路図

```
                    Seeed XIAO SAMD21
                   ┌──────────────────┐
                   │                  │
フォトカプラ ────────┤ D1      3V3     ├─── フォトカプラ VCC
  (OUT)            │ (INPUT)          │
                   │              5V  ├─── Neopixel 5V
                   │                  │
                   │              D2  ├─── Neopixel DIN
                   │         (DATA)   │
                   │                  │
                   │              D3  ├─── 赤色LED（オプション）
                   │              D4  ├─── 白色LED（オプション）
                   │                  │
                   │             GND  ├─── GND（共通）
                   └──────────────────┘
```

### 詳細な接続

#### フォトカプラ側

1. **送信側（赤外線LED）**
   - VCC → XIAO 3V3
   - GND → XIAO GND
   - 水滴が通過する位置に設置

2. **受信側（フォトトランジスタ）**
   - OUT → XIAO D1 (GPIO1)
   - VCC → XIAO 3V3
   - GND → XIAO GND

**重要**: 3.3V動作のフォトカプラを選択してください。

#### Neopixel 8連

1. **接続**
   - DIN → XIAO D2 (GPIO2)
   - 5V → XIAO 5V（USB給電時）
   - GND → XIAO GND

2. **LED配置**
   - LED 0-3: 赤色（トリガー用）
   - LED 4-7: 白色（照明用）

3. **電源注意**
   - Neopixelは5V動作
   - XIAO SAMD21は3.3V動作
   - データ信号は3.3Vだが、多くのNeopixelは認識可能
   - より確実にするにはレベルシフタ使用

#### オプション：個別LED（バックアップ用）

1. **赤色LED（D3）**
   - アノード（長い足）→ D3 (GPIO3)
   - カソード（短い足）→ 220Ω抵抗 → GND

2. **白色LED（D4）**
   - アノード（長い足）→ D4 (GPIO4)
   - カソード（短い足）→ 220Ω抵抗 → GND

コード内で有効化：
```cpp
const bool ENABLE_BACKUP_LEDS = true;  // true で有効化
```

## ソフトウェアセットアップ

### 1. Arduino IDEのインストール

[Arduino公式サイト](https://www.arduino.cc/en/software)からダウンロードしてインストール。

### 2. Seeed XIAO SAMD21のボード設定

1. Arduino IDEを起動
2. ファイル > 環境設定
3. 「追加のボードマネージャのURL」に以下を追加：
   ```
   https://files.seeedstudio.com/arduino/package_seeeduino_boards_index.json
   ```
4. ツール > ボード > ボードマネージャ
5. 「Seeed SAMD Boards」を検索してインストール
6. ツール > ボード > Seeed SAMD Boards > Seeeduino XIAO を選択

### 3. Adafruit NeoPixelライブラリのインストール

1. スケッチ > ライブラリをインクルード > ライブラリを管理
2. 「Adafruit NeoPixel」を検索
3. 「Adafruit NeoPixel by Adafruit」をインストール

### 4. コードのアップロード

1. Arduino IDEで `arduino/water_drop_trigger/water_drop_trigger.ino` を開く
2. ボード選択：ツール > ボード > Seeeduino XIAO
3. ポート選択：ツール > ポート > 接続されているポート
4. アップロードボタンをクリック

### 5. 動作確認

1. シリアルモニタを開く（ツール > シリアルモニタ）
2. ボーレートを `115200` に設定
3. 起動メッセージと虹色アニメーションが表示されることを確認

```
========================================
Water Drop Trigger System v3.0
with Neopixel 8-LED Strip
Board: XIAO SAMD21
========================================
Initializing Neopixel...
System check: Rainbow animation
System check: Red color test
System check: White color test
========================================
System ready!
Neopixel: 8 LEDs for trigger & lighting
Backup LEDs: Enabled (D3=Red, D4=White)
Waiting for water drop detection...
========================================
```

## 使い方

### 1. セットアップ

1. **フォトカプラの設置**
   - 送信側と受信側を向かい合わせに配置
   - 水滴が通過する位置（30cm上）に設置
   - 光軸を正確に合わせる

2. **Neopixelの配置**
   - iPhoneのカメラから見える位置に配置
   - 赤色LED（前半4個）が画面中央に映るように調整
   - 白色LED（後半4個）で撮影領域全体を照らす

3. **電源投入**
   - XIAOをUSB-Cで接続
   - 虹色アニメーション → 赤色 → 白色 の順に点灯すれば正常起動

### 2. 撮影フロー

1. iPhoneアプリで「撮影準備」をタップ
2. 水滴を落とす
3. フォトカプラが水滴を検知
4. Neopixel 前半4個が赤色点灯（トリガー用、5秒間）
5. Neopixel 後半4個が白色点灯（照明用、5秒間）
6. オプションの個別LEDも点灯（有効化時）
7. iPhoneが自動的に録画開始
8. 録画完了後、全LEDが消灯
9. 1秒のクールダウン後、次の撮影が可能

### 3. トラブルシューティング

#### Neopixelが点灯しない

- 電源（5V、GND）の接続を確認
- データ線（DIN）の接続を確認（D2に接続）
- Neopixelの向き（DIN/DOUT）を確認
- Adafruit_NeoPixelライブラリがインストールされているか確認
- シリアルモニタでエラーメッセージを確認

#### Neopixelが正しく動作しない（ちらつき、色がおかしい）

- データ信号レベルの問題（3.3V → 5V）
- レベルシフタ（74HCT245など）の追加を検討
- データ線を短くする（30cm以内推奨）
- 電源を安定化（100μFコンデンサをNeopixel電源に並列接続）

#### フォトカプラが反応しない

- 3.3V動作のフォトカプラを使用しているか確認
- 光軸がずれていないか確認
- 水滴のサイズを大きくする
- シリアルモニタで信号を確認（HIGH/LOW）

#### iPhoneが検知しない

- Neopixelの赤色LEDがカメラに映っているか確認
- 撮影環境を暗くする
- Neopixelの輝度を上げる（コード内で調整）
- 他の赤い光源を取り除く

#### 誤検知が多い

- `DEBOUNCE_DELAY` を増やす（50ms → 100ms）
- フォトカプラを遮光する
- 環境光の影響を減らす

## カスタマイズ

### LED点灯時間の変更

```cpp
const unsigned long LED_ON_DURATION = 5000;  // 5秒 → 任意の値（ms）
```

### Neopixel輝度の調整

```cpp
const uint8_t NEOPIXEL_BRIGHTNESS = 128;  // 0-255（128=50%）
```

**注意**: 輝度を上げすぎると電流が増加し、USB給電では不足する可能性があります。

### LED色の変更

```cpp
// 赤色（RGB値）
const uint8_t RED_COLOR_R = 255;
const uint8_t RED_COLOR_G = 0;
const uint8_t RED_COLOR_B = 0;

// 白色（RGB値）
const uint8_t WHITE_COLOR_R = 255;
const uint8_t WHITE_COLOR_G = 255;
const uint8_t WHITE_COLOR_B = 255;
```

### LED配置の変更

デフォルトでは前半4個が赤色、後半4個が白色ですが、変更可能です：

```cpp
void triggerWaterDrop() {
  // 例：全8個を赤色にする
  for (int i = 0; i < NUM_PIXELS; i++) {
    strip.setPixelColor(i, strip.Color(RED_COLOR_R, RED_COLOR_G, RED_COLOR_B));
  }
  strip.show();
}
```

### バックアップLEDの無効化

Neopixelのみ使用する場合：

```cpp
const bool ENABLE_BACKUP_LEDS = false;  // false で無効化
```

## 将来のアップグレード：XIAO ESP32-S3

現在のコードは、XIAO ESP32-S3にも対応しています。

### ESP32-S3の利点

1. **Wi-Fi/Bluetooth内蔵**: 複数台同期撮影が可能
2. **高速処理**: より高度な画像処理が可能
3. **大容量メモリ**: 複雑な処理に対応

### 移行方法

1. ボードマネージャで「esp32」をインストール
2. ボード選択：XIAO ESP32-S3
3. コードはそのまま使用可能（自動検出）

## 高度な使用例

### Wi-Fi連携（ESP32-S3使用時）

ESP32-S3を使用する場合、Wi-Fi経由でiPhoneに通知を送ることも可能：

```cpp
#include <WiFi.h>
#include <WiFiUdp.h>

// Wi-Fi設定
const char* ssid = "your-ssid";
const char* password = "your-password";

// UDP設定
WiFiUDP udp;
IPAddress broadcastIP(192, 168, 1, 255);
const int udpPort = 12345;

void triggerWaterDrop() {
  // Neopixel点灯
  // ...
  
  // UDP送信（バックアップ）
  udp.beginPacket(broadcastIP, udpPort);
  udp.write((const uint8_t*)"TRIGGER", 7);
  udp.endPacket();
}
```

## 物理的な配置例

```
                    30cm
                     │
                     ↓
    ┌────────────────────────────┐
    │  フォトカプラ（送信・受信） │  ← 水滴検知位置
    └────────────────────────────┘
                     │
                     │ 水滴落下
                     ↓
    ┌────────────────────────────┐
    │                            │
    │     ミルククラウン発生      │  ← 撮影対象
    │                            │
    └────────────────────────────┘
                     ↑
              Neopixel 8連
           (赤4個 + 白4個)


    ┌────────────────────────────┐
    │                            │
    │        iPhone              │  ← カメラ
    │                            │
    └────────────────────────────┘
```

## 参考情報

### Neopixelの利点

- **配線が簡単**: 1本の信号線で8個のLEDを制御
- **個別制御**: 各LEDの色と輝度を個別に設定可能
- **省スペース**: 小型で扱いやすい
- **拡張性**: 将来的にLED数を増やすことも容易

### 推奨Neopixel製品

- **Adafruit NeoPixel Stick - 8 x 5050 RGB LED**
- **WS2812B 8連 LEDストリップ**
- **互換品**: AliExpressなどで安価に入手可能

### Seeed XIAOの選び方

| モデル | 価格 | 特徴 | 推奨用途 |
|---|---|---|---|
| XIAO SAMD21 | 安価 | シンプル、低消費電力 | テスト・プロトタイプ |
| XIAO ESP32-C3 | 中価格 | Wi-Fi/BLE、コンパクト | 単体撮影 |
| XIAO ESP32-S3 | 高価格 | Wi-Fi/BLE、カメラ対応 | 複数台同期撮影 |

## ライセンス

MIT License

## 作者

EasyMeasurementCamera開発チーム
