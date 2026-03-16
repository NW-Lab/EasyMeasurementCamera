/**
 * EasyMeasurementCamera - ミルククラウン撮影トリガーシステム v4.0
 *
 * ハードウェア構成:
 *   - Seeed XIAO SAMD21（将来 ESP32-S3 へのアップグレード対応）
 *   - WS2813B × 6（NeoPixel、74AHC1G125W5経由でレベルシフト）
 *   - TLC5916IPWR × 2（赤色LED × 6、白色LED × 6、SPI制御・定電流）
 *   - フォトカプラ PC817（水滴検知）
 *
 * ピン割り当て:
 *   D0  : フォトカプラ（水滴検知入力、INPUT_PULLUP）
 *   D2  : WS2813B データ（74AHC1G125W5経由）
 *   D3  : TLC5916 #1 LE（赤色LEDラッチ）
 *   D4  : TLC5916 #2 LE（白色LEDラッチ）
 *   D5  : TLC5916 #1/#2 ~OE（出力イネーブル共通、LOWで出力ON）
 *   D8  : TLC5916 CLK（SPI SCK）
 *   D10 : TLC5916 SDI（SPI MOSI）
 *
 * LED構成:
 *   - WS2813B × 6: 赤色点灯（iPhoneトリガー兼用）または白色点灯（照明兼用）
 *   - 赤色LED × 6（SML-E12V8WT86）: TLC5916 #1 で定電流制御
 *   - 白色LED × 6（NSSW157T）: TLC5916 #2 で定電流制御
 *
 * 動作フロー:
 *   1. フォトカプラが水滴を検知（HIGHになる）
 *   2. 赤色LED全点灯（WS2813B赤 + TLC5916 #1）→ iPhoneが赤色を検知
 *   3. 白色LED全点灯（WS2813B白 + TLC5916 #2）→ 240fps撮影用照明
 *   4. 落下時間（約247ms）後がミルククラウン発生タイミング
 *   5. LED_ON_DURATION_MS 経過後にすべてのLEDを消灯
 *
 * 物理計算（落下高さ30cm）:
 *   落下時間 t = sqrt(2h/g) = sqrt(2×0.3/9.8) ≈ 247ms
 *   着水速度 v = sqrt(2gh) = sqrt(2×9.8×0.3) ≈ 2.43 m/s
 *   240fps時の1フレーム = 4.17ms → 落下時間は約59フレーム分
 *
 * 必要ライブラリ:
 *   - Adafruit NeoPixel（Arduino IDEのライブラリマネージャからインストール）
 *
 * 注意事項:
 *   - WS2813B は 5V 電源が必要。74AHC1G125W5 で 3.3V → 5V に変換すること。
 *   - TLC5916 の R-EXT は 1.0kΩ を推奨（出力電流 ≈ 18.6mA）。
 *   - 全LED同時点灯時は約650mA消費。5V 1A以上のACアダプタを使用すること。
 */

#include <Adafruit_NeoPixel.h>
#include <SPI.h>

// ─── ボード自動検出 ────────────────────────────────────────
#if defined(ARDUINO_SAMD_ZERO)
  #define BOARD_NAME "XIAO SAMD21"
#elif defined(ARDUINO_XIAO_ESP32S3)
  #define BOARD_NAME "XIAO ESP32-S3"
#elif defined(ARDUINO_XIAO_ESP32C3)
  #define BOARD_NAME "XIAO ESP32-C3"
#else
  #define BOARD_NAME "Unknown Board"
#endif

// ─── ピン設定 ───────────────────────────────────────────────
#define PHOTOCOUPLER_PIN  0   // フォトカプラ入力（INPUT_PULLUP）
#define NEOPIXEL_PIN      2   // WS2813B データ（74AHC1G125W5経由）
#define TLC_LE_RED_PIN    3   // TLC5916 #1 LE（赤色LEDラッチ）
#define TLC_LE_WHITE_PIN  4   // TLC5916 #2 LE（白色LEDラッチ）
#define TLC_OE_PIN        5   // TLC5916 ~OE（共通、LOWで出力ON）
// D8 = SCK、D10 = MOSI は SPI.begin() で自動設定

// ─── NeoPixel 設定 ────────────────────────────────────────────
#define NEOPIXEL_COUNT      6    // WS2813B の個数
#define NEOPIXEL_BRIGHTNESS 150  // 輝度（0-255）、消費電流を抑えるため150推奨

Adafruit_NeoPixel strip(NEOPIXEL_COUNT, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

// ─── TLC5916 設定 ─────────────────────────────────────────────
// OUT0-5 の 6チャンネルを使用（赤色6個 / 白色6個）
#define TLC_RED_CHANNELS   0b00111111  // OUT0-5 = 赤色LED 6個
#define TLC_WHITE_CHANNELS 0b00111111  // OUT0-5 = 白色LED 6個

// ─── タイミング設定（ms）────────────────────────────────────
// 落下高さ30cmの物理計算値
const unsigned long DROP_FALL_TIME_MS  = 247;   // 落下時間（約247ms）
const unsigned long LED_ON_DURATION_MS = 4000;  // LED点灯時間（前後2秒 = 計4秒）
const unsigned long DEBOUNCE_MS        = 50;    // チャタリング防止
const unsigned long COOLDOWN_MS        = 1000;  // クールダウン時間

// ─── 状態管理 ──────────────────────────────────────────────
enum SystemState {
  STATE_IDLE,       // 待機中
  STATE_TRIGGERED,  // トリガー検知済み → LED点灯
  STATE_RECORDING,  // 撮影中（LED点灯中）
  STATE_COOLDOWN    // クールダウン中
};

SystemState currentState = STATE_IDLE;
unsigned long triggerTime     = 0;
unsigned long lastDebounceTime = 0;
int           lastSensorState  = LOW;

// ─── セットアップ ──────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("========================================");
  Serial.println("EasyMeasurementCamera v4.0");
  Serial.println("Milk Crown Trigger System");
  Serial.print("Board: ");
  Serial.println(BOARD_NAME);
  Serial.println("========================================");

  // ピン設定
  pinMode(PHOTOCOUPLER_PIN, INPUT_PULLUP);
  pinMode(TLC_LE_RED_PIN,   OUTPUT);
  pinMode(TLC_LE_WHITE_PIN, OUTPUT);
  pinMode(TLC_OE_PIN,       OUTPUT);

  // TLC5916 初期状態（出力OFF）
  digitalWrite(TLC_LE_RED_PIN,   LOW);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);
  digitalWrite(TLC_OE_PIN,       HIGH);  // HIGH = 出力無効

  // SPI 初期化（TLC5916用）
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));

  // NeoPixel 初期化
  strip.begin();
  strip.setBrightness(NEOPIXEL_BRIGHTNESS);
  strip.show();

  // 全LED消灯
  tlcAllOff();

  // ─── 起動確認アニメーション ───────────────────────────────
  Serial.println("起動確認: 虹色アニメーション");
  neopixelRainbow();

  Serial.println("起動確認: 赤色テスト点灯");
  neopixelSetRed();
  tlcSetRed(TLC_RED_CHANNELS);
  delay(500);

  Serial.println("起動確認: 白色テスト点灯");
  neopixelSetWhite();
  tlcSetWhite(TLC_WHITE_CHANNELS);
  delay(500);

  // 全消灯
  neopixelSetOff();
  tlcAllOff();

  Serial.println("========================================");
  Serial.println("初期化完了。水滴を待機中...");
  Serial.print("落下時間（30cm）: ");
  Serial.print(DROP_FALL_TIME_MS);
  Serial.println("ms");
  Serial.print("LED点灯時間: ");
  Serial.print(LED_ON_DURATION_MS);
  Serial.println("ms");
  Serial.println("========================================");
}

// ─── メインループ ──────────────────────────────────────────
void loop() {
  unsigned long now = millis();
  int sensorReading = digitalRead(PHOTOCOUPLER_PIN);

  switch (currentState) {

    // ── 待機状態 ──────────────────────────────────────────
    case STATE_IDLE:
      // チャタリング防止
      if (sensorReading != lastSensorState) {
        lastDebounceTime = now;
      }
      if ((now - lastDebounceTime) > DEBOUNCE_MS) {
        // フォトカプラが水滴を検知（HIGH: 光が遮られた）
        if (sensorReading == HIGH && lastSensorState == LOW) {
          triggerTime  = now;
          currentState = STATE_TRIGGERED;
          Serial.println("");
          Serial.println("========================================");
          Serial.print("水滴検知！ 時刻: ");
          Serial.print(now);
          Serial.println("ms");
          Serial.print("撮影タイミング（着水）: ");
          Serial.print(now + DROP_FALL_TIME_MS);
          Serial.println("ms");
        }
      }
      lastSensorState = sensorReading;
      break;

    // ── トリガー検知済み → 即座にLED点灯 ────────────────
    case STATE_TRIGGERED:
      startRecording();
      currentState = STATE_RECORDING;
      Serial.println("LED点灯！ 撮影開始。");
      Serial.print(DROP_FALL_TIME_MS);
      Serial.println("ms後がミルククラウン発生タイミング");
      Serial.println("========================================");
      break;

    // ── 撮影中 ────────────────────────────────────────────
    case STATE_RECORDING:
      if (now - triggerTime >= LED_ON_DURATION_MS) {
        stopRecording();
        currentState = STATE_COOLDOWN;
        Serial.println("撮影完了。LED消灯。クールダウン中...");
      }
      break;

    // ── クールダウン ──────────────────────────────────────
    case STATE_COOLDOWN:
      if (now - triggerTime >= LED_ON_DURATION_MS + COOLDOWN_MS) {
        currentState    = STATE_IDLE;
        lastSensorState = LOW;
        Serial.println("待機中... 次の水滴を待っています。");
        Serial.println("========================================");
      }
      break;
  }
}

// ─── TLC5916 制御関数 ─────────────────────────────────────

/**
 * 赤色LED を点灯（TLC5916 #1）
 * カスケード接続のため、#2（白色）のデータを先に送信する
 */
void tlcSetRed(uint8_t channels) {
  SPI.transfer(0x00);      // TLC5916 #2（白色）は変更しない
  SPI.transfer(channels);  // TLC5916 #1（赤色）

  // 赤色ラッチを更新
  digitalWrite(TLC_LE_RED_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_RED_PIN, LOW);

  // 出力イネーブル
  digitalWrite(TLC_OE_PIN, LOW);
}

/**
 * 白色LED を点灯（TLC5916 #2）
 */
void tlcSetWhite(uint8_t channels) {
  SPI.transfer(channels);  // TLC5916 #2（白色）
  SPI.transfer(0x00);      // TLC5916 #1（赤色）は変更しない

  // 白色ラッチを更新
  digitalWrite(TLC_LE_WHITE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);

  // 出力イネーブル
  digitalWrite(TLC_OE_PIN, LOW);
}

/**
 * 全LED消灯（TLC5916 #1/#2）
 */
void tlcAllOff() {
  SPI.transfer(0x00);  // TLC5916 #2（白色）
  SPI.transfer(0x00);  // TLC5916 #1（赤色）

  // 両ラッチを更新
  digitalWrite(TLC_LE_RED_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_RED_PIN, LOW);

  digitalWrite(TLC_LE_WHITE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);

  // 出力無効
  digitalWrite(TLC_OE_PIN, HIGH);
}

// ─── NeoPixel 制御関数 ────────────────────────────────────

/** NeoPixel を赤色に点灯（iPhoneトリガー用） */
void neopixelSetRed() {
  for (int i = 0; i < NEOPIXEL_COUNT; i++) {
    strip.setPixelColor(i, strip.Color(255, 0, 0));
  }
  strip.show();
}

/** NeoPixel を白色に点灯（240fps照明用） */
void neopixelSetWhite() {
  for (int i = 0; i < NEOPIXEL_COUNT; i++) {
    strip.setPixelColor(i, strip.Color(255, 255, 255));
  }
  strip.show();
}

/** NeoPixel を消灯 */
void neopixelSetOff() {
  strip.clear();
  strip.show();
}

/** 起動確認用の虹色アニメーション */
void neopixelRainbow() {
  uint32_t colors[] = {
    strip.Color(255, 0,   0),    // 赤
    strip.Color(255, 127, 0),    // オレンジ
    strip.Color(255, 255, 0),    // 黄
    strip.Color(0,   255, 0),    // 緑
    strip.Color(0,   0,   255),  // 青
    strip.Color(148, 0,   211)   // 紫
  };
  for (int i = 0; i < NEOPIXEL_COUNT; i++) {
    strip.setPixelColor(i, colors[i % 6]);
  }
  strip.show();
  delay(800);
  neopixelSetOff();
}

// ─── 撮影制御関数 ─────────────────────────────────────────

/**
 * 撮影開始：全LEDを点灯
 *   - WS2813B 赤色 + TLC5916 #1 赤色LED → iPhoneのトリガー信号
 *   - WS2813B 白色 + TLC5916 #2 白色LED → 240fps撮影用照明
 *
 * ※ 赤色と白色を同時に点灯することで、iPhoneが赤色を確実に検知しつつ
 *    撮影に必要な照明も確保する。
 */
void startRecording() {
  // NeoPixel: 赤色点灯（iPhoneトリガー用）
  neopixelSetRed();

  // TLC5916 #1: 赤色LED全点灯
  tlcSetRed(TLC_RED_CHANNELS);

  // TLC5916 #2: 白色LED全点灯（照明）
  // ※ tlcSetWhite は #1 のデータを 0x00 で上書きしてしまうため、
  //   両方同時に点灯させる場合は以下のように一括送信する
  SPI.transfer(TLC_WHITE_CHANNELS);  // TLC5916 #2（白色）
  SPI.transfer(TLC_RED_CHANNELS);    // TLC5916 #1（赤色）

  // 両ラッチを同時に更新
  digitalWrite(TLC_LE_RED_PIN, HIGH);
  digitalWrite(TLC_LE_WHITE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_RED_PIN, LOW);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);

  // 出力イネーブル
  digitalWrite(TLC_OE_PIN, LOW);
}

/**
 * 撮影終了：全LEDを消灯
 */
void stopRecording() {
  neopixelSetOff();
  tlcAllOff();
}
