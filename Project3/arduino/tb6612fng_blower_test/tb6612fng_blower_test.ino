// ---------------------------------------------------------------------------
// Project3: マイクロブロア（MZB1001T02）動作確認用コード
// ドライバ: TB6612FNGモジュール（秋月電子）
// マイコン: Seeeduino XIAO (SAMD21)
// ---------------------------------------------------------------------------

// 25kHzのPWMを使用する場合は、以下のコメントを外してください。
// コメントアウトされている場合は、標準のPWM周波数（約1kHz）で動作します。
#define USE_25KHZ

// --- ピン定義 ---
const int PWMA_PIN = 0; // PWM出力
const int AIN1_PIN = 1; // 方向制御1
const int AIN2_PIN = 2; // 方向制御2
const int STBY_PIN = 3; // スタンバイ制御 (HIGHで有効)

// 25kHz設定用の変数
#ifdef USE_25KHZ
  // SAMD21のタイマー(TCC0)を使用して25kHzを生成するための設定値
  // 48MHz / (25kHz * 2) = 960 (TOP値)
  // ※TCC0はD0(PA02)とD1(PA04)などで使用可能
  const int PWM_TOP = 960; 
#endif

void setup() {
  Serial.begin(115200);
  
  // ピンモード設定
  pinMode(PWMA_PIN, OUTPUT);
  pinMode(AIN1_PIN, OUTPUT);
  pinMode(AIN2_PIN, OUTPUT);
  pinMode(STBY_PIN, OUTPUT);
  
  // 初期状態: ブロア停止
  digitalWrite(STBY_PIN, LOW); // スタンバイ状態（モーター出力オフ）
  digitalWrite(AIN1_PIN, LOW);
  digitalWrite(AIN2_PIN, LOW);

#ifdef USE_25KHZ
  setupPWM25kHz();
  setPWMDuty(0);
#else
  analogWrite(PWMA_PIN, 0);
#endif

  Serial.println("--- Micro Blower Test (TB6612FNG) ---");
#ifdef USE_25KHZ
  Serial.println("PWM Frequency: 25 kHz");
#else
  Serial.println("PWM Frequency: Standard (~1 kHz)");
#endif
  Serial.println("Send '1' to start blower (50% power)");
  Serial.println("Send '2' to start blower (100% power)");
  Serial.println("Send '0' to stop blower");
}

void loop() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    
    if (cmd == '1') {
      Serial.println("Blower ON (50%)");
      digitalWrite(STBY_PIN, HIGH);
      digitalWrite(AIN1_PIN, HIGH);
      digitalWrite(AIN2_PIN, LOW);
#ifdef USE_25KHZ
      setPWMDuty(PWM_TOP / 2); // 50%
#else
      analogWrite(PWMA_PIN, 127); // 50% (0-255)
#endif
    } 
    else if (cmd == '2') {
      Serial.println("Blower ON (100%)");
      digitalWrite(STBY_PIN, HIGH);
      digitalWrite(AIN1_PIN, HIGH);
      digitalWrite(AIN2_PIN, LOW);
#ifdef USE_25KHZ
      setPWMDuty(PWM_TOP); // 100%
#else
      analogWrite(PWMA_PIN, 255); // 100%
#endif
    }
    else if (cmd == '0') {
      Serial.println("Blower OFF");
      digitalWrite(STBY_PIN, LOW);
      digitalWrite(AIN1_PIN, LOW);
      digitalWrite(AIN2_PIN, LOW);
#ifdef USE_25KHZ
      setPWMDuty(0);
#else
      analogWrite(PWMA_PIN, 0);
#endif
    }
  }
}

// ===========================================================================
// SAMD21 タイマーレジスタ操作による25kHz PWM生成 (D0ピン用)
// ===========================================================================
#ifdef USE_25KHZ
void setupPWM25kHz() {
  // D0ピン(PA02)を周辺機器(タイマーTCC0)に割り当てる
  PORT->Group[PORTA].PINCFG[2].bit.PMUXEN = 1;
  PORT->Group[PORTA].PMUX[2 >> 1].reg |= PORT_PMUX_PMUXE_E; // TCC0/WO[0]はMUX E

  // GCLK0 (48MHz) を TCC0 と TCC1 に供給
  GCLK->CLKCTRL.reg = (uint16_t) (GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK0 | GCLK_CLKCTRL_ID(TCC0_GCLK_ID));
  while (GCLK->STATUS.bit.SYNCBUSY);

  // TCC0を無効化して設定変更
  TCC0->CTRLA.bit.ENABLE = 0;
  while (TCC0->SYNCBUSY.bit.ENABLE);

  // プリスケーラ: 1 (48MHz)
  TCC0->CTRLA.reg |= TCC_CTRLA_PRESCALER_DIV1;

  // 波形生成モード: ノーマルPWM (NPWM)
  TCC0->WAVE.reg |= TCC_WAVE_WAVEGEN_NPWM;
  while (TCC0->SYNCBUSY.bit.WAVE);

  // TOP値の設定 (周期を決定)
  // 48MHz / 25kHz = 1920 -> 0ベースなので1919
  TCC0->PER.reg = 1919;
  while (TCC0->SYNCBUSY.bit.PER);

  // 初期デューティ比: 0
  TCC0->CC[0].reg = 0;
  while (TCC0->SYNCBUSY.bit.CC0);

  // TCC0を有効化
  TCC0->CTRLA.bit.ENABLE = 1;
  while (TCC0->SYNCBUSY.bit.ENABLE);
}

void setPWMDuty(int duty) {
  // dutyは 0 から 1919 の範囲
  if (duty > 1919) duty = 1919;
  if (duty < 0) duty = 0;
  
  TCC0->CCB[0].reg = duty;
  while (TCC0->SYNCBUSY.bit.CCB0);
}
#endif
