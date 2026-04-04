// ---------------------------------------------------------------------------
// Project3: マイクロブロア（MZB1001T02）動作確認用コード
// ドライバ: TB6612FNGモジュール（秋月電子）
// マイコン: Seeeduino XIAO (SAMD21)
// ---------------------------------------------------------------------------

// --- ピン定義 ---
const int PWMA_PIN = 0; // PWM出力 (25kHz)
const int AIN1_PIN = 1; // 方向制御1
const int AIN2_PIN = 2; // 方向制御2
const int STBY_PIN = 3; // スタンバイ制御 (HIGHで有効)

// --- ブロア制御パラメータ ---
// 25kHzのPWMを生成するための設定
// XIAO SAMD21のクロックは48MHz
// 48MHz / 25kHz = 1920
const int PWM_FREQ = 25000;
const int PWM_RESOLUTION = 8; // 8bit (0-255)

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
  analogWrite(PWMA_PIN, 0);

  // XIAO (SAMD21) のPWM周波数変更 (D0ピン)
  // analogWrite()の前に設定する必要がある場合がありますが、
  // SAMD21のコアライブラリに依存します。
  // より確実な方法は、タイマーレジスタを直接操作することですが、
  // まずは標準のanalogWrite()で動作確認を行います。
  // (必要に応じて、後でレジスタ操作による25kHz生成に切り替えます)

  Serial.println("--- Micro Blower Test (TB6612FNG) ---");
  Serial.println("Send '1' to start blower (50% power)");
  Serial.println("Send '2' to start blower (100% power)");
  Serial.println("Send '0' to stop blower");
}

void loop() {
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    
    if (cmd == '1') {
      Serial.println("Blower ON (50%)");
      // TB6612FNGを有効化
      digitalWrite(STBY_PIN, HIGH);
      // 正転方向に設定 (AIN1=H, AIN2=L)
      digitalWrite(AIN1_PIN, HIGH);
      digitalWrite(AIN2_PIN, LOW);
      // PWM出力 (50%デューティ)
      analogWrite(PWMA_PIN, 127);
    } 
    else if (cmd == '2') {
      Serial.println("Blower ON (100%)");
      // TB6612FNGを有効化
      digitalWrite(STBY_PIN, HIGH);
      // 正転方向に設定 (AIN1=H, AIN2=L)
      digitalWrite(AIN1_PIN, HIGH);
      digitalWrite(AIN2_PIN, LOW);
      // PWM出力 (100%デューティ)
      analogWrite(PWMA_PIN, 255);
    }
    else if (cmd == '0') {
      Serial.println("Blower OFF");
      // ブレーキ状態 (AIN1=H, AIN2=H) または スタンバイ (STBY=L)
      // ここではスタンバイにして出力を完全にオフにする
      digitalWrite(STBY_PIN, LOW);
      digitalWrite(AIN1_PIN, LOW);
      digitalWrite(AIN2_PIN, LOW);
      analogWrite(PWMA_PIN, 0);
    }
  }
}
