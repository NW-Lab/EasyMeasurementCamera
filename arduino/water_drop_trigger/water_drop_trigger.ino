/*
 * Water Drop Trigger System for Milk Crown Photography
 * Seeed XIAO SAMD21 / ESP32-S3 Compatible
 * 
 * フォトカプラで水滴を検知し、Neopixel 8連で赤色・白色を点灯させて
 * iPhoneのカメラに撮影開始のトリガーを送るシステム
 * 
 * ハードウェア:
 * - Seeed XIAO SAMD21 (または ESP32-S3)
 * - フォトカプラ（水滴検知用）
 * - Neopixel 8連（WS2812B）
 * - 赤色LED（オプション、バックアップ用）
 * - 白色LED（オプション、バックアップ用）
 * - 抵抗 220Ω x2（個別LED用）
 * 
 * 接続:
 * - フォトカプラ出力 → D1 (GPIO1)
 * - Neopixel DIN → D2 (GPIO2)
 * - 赤色LED（オプション） → D3 (GPIO3)
 * - 白色LED（オプション） → D4 (GPIO4)
 * 
 * 動作:
 * 1. フォトカプラが水滴を検知（LOW信号）
 * 2. Neopixel 8連で赤色・白色を点灯
 * 3. オプションの個別LEDも点灯
 * 4. 一定時間後に消灯
 * 5. 次の検知に備える
 */

#include <Adafruit_NeoPixel.h>

// ボード自動検出
#if defined(ARDUINO_SAMD_ZERO)
  #define BOARD_NAME "XIAO SAMD21"
#elif defined(ARDUINO_XIAO_ESP32S3)
  #define BOARD_NAME "XIAO ESP32-S3"
#elif defined(ARDUINO_XIAO_ESP32C3)
  #define BOARD_NAME "XIAO ESP32-C3"
#else
  #define BOARD_NAME "Unknown Board"
#endif

// ピン定義（XIAO共通）
const int PHOTOCOUPLER_PIN = 1;      // フォトカプラ入力ピン (D1)
const int NEOPIXEL_PIN = 2;          // Neopixel データピン (D2)
const int RED_LED_PIN = 3;           // 赤色LED出力ピン (D3, オプション)
const int WHITE_LED_PIN = 4;         // 白色LED出力ピン (D4, オプション)

// Neopixel設定
const int NUM_PIXELS = 8;            // Neopixel LED数
Adafruit_NeoPixel strip(NUM_PIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

// タイミング設定
const unsigned long LED_ON_DURATION = 5000;  // LED点灯時間（5秒）
const unsigned long DEBOUNCE_DELAY = 50;     // チャタリング防止（50ms）
const unsigned long COOLDOWN_TIME = 1000;    // クールダウン時間（1秒）

// LED色設定（RGB値: 0-255）
const uint8_t RED_COLOR_R = 255;
const uint8_t RED_COLOR_G = 0;
const uint8_t RED_COLOR_B = 0;

const uint8_t WHITE_COLOR_R = 255;
const uint8_t WHITE_COLOR_G = 255;
const uint8_t WHITE_COLOR_B = 255;

// LED輝度設定（0-255、Neopixelは明るすぎるので調整推奨）
const uint8_t NEOPIXEL_BRIGHTNESS = 128;  // 50%輝度（調整可能）

// オプション機能の有効化
const bool ENABLE_BACKUP_LEDS = true;  // 個別LED使用（true/false）

// 状態変数
bool isTriggered = false;
unsigned long triggerTime = 0;
unsigned long lastDebounceTime = 0;
bool lastButtonState = HIGH;
bool buttonState = HIGH;

void setup() {
  // シリアル通信初期化（デバッグ用）
  Serial.begin(115200);
  delay(1000);  // シリアル接続待機
  
  Serial.println("========================================");
  Serial.println("Water Drop Trigger System v3.0");
  Serial.println("with Neopixel 8-LED Strip");
  Serial.print("Board: ");
  Serial.println(BOARD_NAME);
  Serial.println("========================================");
  
  // ピンモード設定
  pinMode(PHOTOCOUPLER_PIN, INPUT_PULLUP);  // プルアップ抵抗を有効化
  
  if (ENABLE_BACKUP_LEDS) {
    pinMode(RED_LED_PIN, OUTPUT);
    pinMode(WHITE_LED_PIN, OUTPUT);
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(WHITE_LED_PIN, LOW);
  }
  
  // Neopixel初期化
  strip.begin();
  strip.setBrightness(NEOPIXEL_BRIGHTNESS);
  strip.show();  // 全消灯
  
  Serial.println("Initializing Neopixel...");
  
  // 起動確認（虹色アニメーション）
  Serial.println("System check: Rainbow animation");
  rainbowAnimation();
  
  // 赤色・白色テスト
  Serial.println("System check: Red color test");
  setAllPixels(RED_COLOR_R, RED_COLOR_G, RED_COLOR_B);
  delay(500);
  strip.show();
  
  Serial.println("System check: White color test");
  setAllPixels(WHITE_COLOR_R, WHITE_COLOR_G, WHITE_COLOR_B);
  delay(500);
  strip.show();
  
  // 全消灯
  strip.clear();
  strip.show();
  
  Serial.println("========================================");
  Serial.println("System ready!");
  Serial.println("Neopixel: 8 LEDs for trigger & lighting");
  if (ENABLE_BACKUP_LEDS) {
    Serial.println("Backup LEDs: Enabled (D3=Red, D4=White)");
  }
  Serial.println("Waiting for water drop detection...");
  Serial.println("========================================");
}

void loop() {
  // フォトカプラの状態を読み取り
  int reading = digitalRead(PHOTOCOUPLER_PIN);
  
  // チャタリング防止
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  
  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY) {
    if (reading != buttonState) {
      buttonState = reading;
      
      // フォトカプラがLOW（水滴検知）かつトリガー未発動の場合
      if (buttonState == LOW && !isTriggered) {
        triggerWaterDrop();
      }
    }
  }
  
  lastButtonState = reading;
  
  // トリガー後の処理
  if (isTriggered) {
    unsigned long elapsed = millis() - triggerTime;
    
    // LED点灯時間が経過したら消灯
    if (elapsed >= LED_ON_DURATION) {
      turnOffAllLEDs();
      
      // クールダウン時間を待つ
      delay(COOLDOWN_TIME);
      
      // 次の検知に備える
      isTriggered = false;
      Serial.println("----------------------------------------");
      Serial.println("Ready for next detection");
      Serial.println("----------------------------------------");
    }
  }
}

// 水滴検知時の処理
void triggerWaterDrop() {
  isTriggered = true;
  triggerTime = millis();
  
  // Neopixel: 前半4個を赤色（トリガー用）
  for (int i = 0; i < 4; i++) {
    strip.setPixelColor(i, strip.Color(RED_COLOR_R, RED_COLOR_G, RED_COLOR_B));
  }
  
  // Neopixel: 後半4個を白色（照明用）
  for (int i = 4; i < NUM_PIXELS; i++) {
    strip.setPixelColor(i, strip.Color(WHITE_COLOR_R, WHITE_COLOR_G, WHITE_COLOR_B));
  }
  
  strip.show();
  
  // オプション: 個別LEDも点灯
  if (ENABLE_BACKUP_LEDS) {
    digitalWrite(RED_LED_PIN, HIGH);
    digitalWrite(WHITE_LED_PIN, HIGH);
  }
  
  // シリアル出力
  Serial.println("");
  Serial.println("========================================");
  Serial.println("🔴 WATER DROP DETECTED!");
  Serial.println("========================================");
  Serial.println("✅ Neopixel ON - 4 Red + 4 White LEDs");
  if (ENABLE_BACKUP_LEDS) {
    Serial.println("✅ Backup LEDs ON - Red & White");
  }
  Serial.print("⏱️  Timestamp: ");
  Serial.print(millis());
  Serial.println(" ms");
  Serial.println("========================================");
  Serial.println("Recording should start now...");
}

// 全LED消灯
void turnOffAllLEDs() {
  // Neopixel消灯
  strip.clear();
  strip.show();
  
  // オプション: 個別LED消灯
  if (ENABLE_BACKUP_LEDS) {
    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(WHITE_LED_PIN, LOW);
  }
  
  Serial.println("");
  Serial.println("🔴 Neopixel OFF");
  if (ENABLE_BACKUP_LEDS) {
    Serial.println("🔴 Backup LEDs OFF");
  }
  Serial.println("Recording should be completed");
}

// 全Neopixelを同じ色に設定
void setAllPixels(uint8_t r, uint8_t g, uint8_t b) {
  for (int i = 0; i < NUM_PIXELS; i++) {
    strip.setPixelColor(i, strip.Color(r, g, b));
  }
  strip.show();
}

// 虹色アニメーション（起動確認用）
void rainbowAnimation() {
  for (int j = 0; j < 256; j += 8) {
    for (int i = 0; i < NUM_PIXELS; i++) {
      strip.setPixelColor(i, Wheel((i * 256 / NUM_PIXELS + j) & 255));
    }
    strip.show();
    delay(10);
  }
}

// 虹色生成関数
uint32_t Wheel(byte WheelPos) {
  WheelPos = 255 - WheelPos;
  if (WheelPos < 85) {
    return strip.Color(255 - WheelPos * 3, 0, WheelPos * 3);
  }
  if (WheelPos < 170) {
    WheelPos -= 85;
    return strip.Color(0, WheelPos * 3, 255 - WheelPos * 3);
  }
  WheelPos -= 170;
  return strip.Color(WheelPos * 3, 255 - WheelPos * 3, 0);
}
