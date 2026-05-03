// Project 3: Micro Blower Test
// マイクロブロア（MZB1001T02）単体の動作確認用コード
// XIAO SAMD21 + TC4428

// --- ピン定義 ---
const int BLOWER_PWM_PIN = 0;    // D0: TC4428ドライバ入力 (TCC0/WO[4])

// --- パラメータ ---
const int BLOWER_FREQUENCY = 25000; // 駆動周波数 25kHz

void setup() {
  Serial.begin(115200);
  // シリアル接続を待つ（必要に応じてコメントアウト解除）
  // while (!Serial) { ; }

  Serial.println("Micro Blower Test Initialized.");
  Serial.println("Send '1' to start blower (50% duty).");
  Serial.println("Send '0' to stop blower.");
  
  setupBlowerPwm();
  stopBlower(); // 最初は停止状態
}

void loop() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    
    if (cmd == '1') {
      Serial.println("Blower ON (Max Output)");
      startBlower(128); // 255の半分の128 = 50%デューティ比（最大出力）
    } 
    else if (cmd == '0') {
      Serial.println("Blower OFF");
      stopBlower();
    }
  }
}

// --- ブロア制御関数 ---

// TCC0タイマーを25kHzで初期化する
void setupBlowerPwm() {
  // GCLK4を48MHzで有効化
  GCLK->GENDIV.reg = GCLK_GENDIV_DIV(1) | GCLK_GENDIV_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);
  
  GCLK->GENCTRL.reg = GCLK_GENCTRL_IDC | GCLK_GENCTRL_GENEN | GCLK_GENCTRL_SRC_DFLL48M | GCLK_GENCTRL_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);
  
  GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK4 | GCLK_CLKCTRL_ID_TCC0_TCC1;
  while (GCLK->STATUS.bit.SYNCBUSY);

  // D0ピンをTCC0の出力（周辺機能E）に割り当て
  pinPeripheral(BLOWER_PWM_PIN, PIO_TIMER_ALT);

  // TCC0をリセット
  TCC0->CTRLA.reg = TC_CTRLA_SWRST;
  while (TCC0->SYNCBUSY.bit.SWRST);

  // Normal PWMモードに設定
  TCC0->WAVE.reg = TC_WAVE_WAVEGEN_NPWM;
  while (TCC0->SYNCBUSY.bit.WAVE);

  // 周期を設定 (48MHz / 25kHz = 1920)
  TCC0->PER.reg = (48000000 / BLOWER_FREQUENCY) - 1;
  while (TCC0->SYNCBUSY.bit.PER);

  // タイマー有効化
  TCC0->CTRLA.reg |= TC_CTRLA_ENABLE;
  while (TCC0->SYNCBUSY.bit.ENABLE);
}

// デューティ比を指定してブロアを駆動する
// duty: 0(停止) 〜 255(デューティ比50%で最大出力)
void startBlower(int duty) {
  // 0〜255の値を、0〜(PER/2)の範囲にマッピング
  int dutyValue = map(duty, 0, 255, 0, TCC0->PER.reg / 2);
  TCC0->CC[0].reg = dutyValue;
  while (TCC0->SYNCBUSY.bit.CC0);
}

// ブロアを停止する（デューティ比0%）
void stopBlower() {
  TCC0->CC[0].reg = 0;
  while (TCC0->SYNCBUSY.bit.CC0);
}
