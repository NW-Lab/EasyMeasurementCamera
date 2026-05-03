// Project 3: Droplet Air Collision
// v1.0

// --- ライブラリ ---
// なし

// --- ピン定義 ---
// 電磁弁 (Project 2)
const int SOLENOID_PIN = 1;      // D1: MOSFETゲート

// マイクロブロア (Project 3)
const int BLOWER_PWM_PIN = 0;    // D0: TC4428ドライバ入力 (TCC0/WO[4])

// LED照明 (Project 1)
const int LED_RED_SDI_PIN = 2;   // D2
const int LED_RED_CLK_PIN = 3;   // D3
const int LED_RED_LE_PIN = 4;    // D4
const int LED_RED_OE_PIN = 5;    // D5

const int LED_WHITE_SDI_PIN = 6; // D6
const int LED_WHITE_CLK_PIN = 7; // D7
const int LED_WHITE_LE_PIN = 8;  // D8
const int LED_WHITE_OE_PIN = 9;  // D9

// --- タイミングパラメータ (ms) ---
unsigned long solenoidOpenTime = 50;   // 電磁弁を開いている時間
unsigned long dropFallDelay = 150;     // 水滴がブロアの高さまで落下する時間
unsigned long blowerOnDelay = 10;      // 落下後、ブロアをONにするまでの遅延
unsigned long blowerOnDuration = 30;   // ブロアをONにしておく時間
unsigned long flashDelay = 20;         // ブロアON後、フラッシュを焚くまでの遅延
unsigned long ledOnDuration = 5;       // LEDフラッシュの時間

// --- ブロアパラメータ ---
const int BLOWER_FREQUENCY = 25000; // 駆動周波数 (Hz)

// --- グローバル変数 ---
bool sequenceRunning = false;

// --- setup --- 
void setup() {
  Serial.begin(115200);
  // シリアルポートが開くまで待つ（デバッグ用）
  // while (!Serial) { ; }

  // ピンモード設定
  pinMode(SOLENOID_PIN, OUTPUT);
  digitalWrite(SOLENOID_PIN, LOW);

  pinMode(LED_RED_SDI_PIN, OUTPUT);
  pinMode(LED_RED_CLK_PIN, OUTPUT);
  pinMode(LED_RED_LE_PIN, OUTPUT);
  pinMode(LED_RED_OE_PIN, OUTPUT);
  digitalWrite(LED_RED_OE_PIN, HIGH); // OEはActive LowなのでHIGHで消灯

  pinMode(LED_WHITE_SDI_PIN, OUTPUT);
  pinMode(LED_WHITE_CLK_PIN, OUTPUT);
  pinMode(LED_WHITE_LE_PIN, OUTPUT);
  pinMode(LED_WHITE_OE_PIN, OUTPUT);
  digitalWrite(LED_WHITE_OE_PIN, HIGH); // 消灯

  // LEDドライバにデータを初期ロード
  loadTlc5916Data(LED_RED_SDI_PIN, LED_RED_CLK_PIN, LED_RED_LE_PIN, 0b00111111);
  loadTlc5916Data(LED_WHITE_SDI_PIN, LED_WHITE_CLK_PIN, LED_WHITE_LE_PIN, 0b00111111);

  // ブロア駆動用PWM初期化
  setupBlowerPwm();
  stopBlower(); // 最初は停止

  Serial.println("Project 3: Droplet Air Collision");
  Serial.println("Send any character to start sequence.");
}

// --- loop ---
void loop() {
  if (Serial.available() > 0 && !sequenceRunning) {
    while(Serial.read() != -1); // シリアルバッファをクリア
    sequenceRunning = true;
    runSequence();
    sequenceRunning = false;
    Serial.println("Sequence finished. Send any character to start again.");
  }
}

// --- 撮影シーケンス実行 ---
void runSequence() {
  Serial.println("--- Sequence Start ---");

  // 1. 電磁弁を開いて水滴を生成
  Serial.println("1. Solenoid ON");
  digitalWrite(SOLENOID_PIN, HIGH);
  delay(solenoidOpenTime);
  digitalWrite(SOLENOID_PIN, LOW);
  Serial.println("2. Solenoid OFF -> Droplet falling...");

  // 2. 水滴がブロアの高さまで落下するのを待つ
  delay(dropFallDelay);

  // 3. ブロアをONにする
  delay(blowerOnDelay);
  Serial.println("3. Blower ON");
  startBlower(128); // 50%デューティで最大出力

  // 4. フラッシュ撮影
  delay(flashDelay);
  Serial.println("4. Flash ON");
  digitalWrite(LED_RED_OE_PIN, LOW);
  digitalWrite(LED_WHITE_OE_PIN, LOW);
  delay(ledOnDuration);
  digitalWrite(LED_RED_OE_PIN, HIGH);
  digitalWrite(LED_WHITE_OE_PIN, HIGH);
  Serial.println("5. Flash OFF");

  // 5. ブロアを停止
  delay(blowerOnDuration - flashDelay - ledOnDuration); // ブロアの総ON時間を維持
  stopBlower();
  Serial.println("6. Blower OFF");
}

// --- TLC5916 データ送信関数 ---
void loadTlc5916Data(int sdiPin, int clkPin, int lePin, byte data) {
  digitalWrite(lePin, LOW);
  for (int i = 7; i >= 0; i--)  {
    digitalWrite(clkPin, LOW);
    digitalWrite(sdiPin, (data >> i) & 1);
    digitalWrite(clkPin, HIGH);
  }
  digitalWrite(lePin, HIGH);
  delayMicroseconds(1);
  digitalWrite(lePin, LOW);
}

// --- ブロア制御関数 ---
void setupBlowerPwm() {
  GCLK->GENDIV.reg = GCLK_GENDIV_DIV(1) | GCLK_GENDIV_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);
  GCLK->GENCTRL.reg = GCLK_GENCTRL_IDC | GCLK_GENCTRL_GENEN | GCLK_GENCTRL_SRC_DFLL48M | GCLK_GENCTRL_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);
  GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK4 | GCLK_CLKCTRL_ID_TCC0_TCC1;
  while (GCLK->STATUS.bit.SYNCBUSY);
  pinPeripheral(BLOWER_PWM_PIN, PIO_TIMER_ALT);
  TCC0->CTRLA.reg = TC_CTRLA_SWRST;
  while (TCC0->SYNCBUSY.bit.SWRST);
  TCC0->WAVE.reg = TC_WAVE_WAVEGEN_NPWM;
  while (TCC0->SYNCBUSY.bit.WAVE);
  TCC0->PER.reg = (48000000 / BLOWER_FREQUENCY) - 1;
  while (TCC0->SYNCBUSY.bit.PER);
  TCC0->CTRLA.reg |= TC_CTRLA_ENABLE;
  while (TCC0->SYNCBUSY.bit.ENABLE);
}

void startBlower(int duty) { // duty: 0-255
  int dutyValue = map(duty, 0, 255, 0, TCC0->PER.reg / 2);
  TCC0->CC[0].reg = dutyValue;
  while (TCC0->SYNCBUSY.bit.CC0);
}

void stopBlower() {
  TCC0->CC[0].reg = 0;
  while (TCC0->SYNCBUSY.bit.CC0);
}
