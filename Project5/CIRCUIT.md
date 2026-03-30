# Project 3: 気流衝突による水滴変形 - 駆動回路 (v2.0)

## 概要

村田製作所のマイクロブロア（MZB1001T02）を、単一電源（USB PD 12Vまたは12V ACアダプタ）で駆動するためのHブリッジ回路です。

マイコン（XIAO SAMD21）で生成した**1本のPWM信号**を、MOSFETゲートドライバ（**TC4428**）に入力します。TC4428は内部で信号を非反転・反転に分岐してくれるため、シンプルかつ確実にHブリッジを駆動できます。

## 回路図 (ASCII)

```
              +12V
                |-------------------------------------. 
                |                                     |
+12V --+--------| VDD(8)         OUT_A(7) ----+       |       
       |        | TC4428         OUT_B(5) ----|-------+       
       |        | (Non-Inv)      IN_A(2)      |       |       
+ C1   |        | (Inverting)    IN_B(4)      |       |       
 0.1uF |        |                GND(1,3,6)   |       |       
       |        '----------------|------------'       |      
       |                         |                    |
      GND                       GND              [ Blower ]
                                                    |
(XIAO)                                              |
D0 --------------------'-----------'-----------------
                     (IN_A)      (IN_B)

```

**【重要】**
- XIAOの**D0ピン**をTC4428の**IN_A(2番)とIN_B(4番)の両方に接続**します。
- TC4428のピン1, 3, 6は全てGNDに接続してください。
- C1はTC4428のVDDピンのできるだけ近くに配置するパスコンです。

## 部品リスト (v2.0)

| 部品名 | 型番 | 数量 | 入手先 (例) | 備考 |
|:---|:---|:---:|:---|:---|
| MOSFETゲートドライバ | **TC4428COA** | 1 | 秋月電子 | DIP8。非反転+反転の組み合わせ。 |
| マイクロブロア | MZB1001T02 | 1 | 秋月電子 | |
| セラミックコンデンサ | 0.1uF (100nF) | 1 | 秋月電子 | パスコン。耐圧25V以上。 |
| 電源 | USB PDトリガー or ACアダプタ | 1 | Amazon等 | **DC 12V** / 1A以上 |
| マイコン | Seeed XIAO SAMD21 | 1 | 秋月電子 | |

## Arduinoコード (SAMD21用・v2.0)

Seeeduino XIAO (SAMD21) の **TCC0タイマー** を利用して、D0ピンから25kHzのPWM信号を1本だけ出力します。

```cpp
// Microblower H-Bridge Driver for XIAO SAMD21 (using TC4428)
// v2.0

// --- ピン定義 ---
const int PWM_PIN = 0; // D0 (TCC0/WO[4])

// --- パラメータ ---
const int PWM_FREQUENCY = 25000; // 駆動周波数 (Hz)
const int PWM_RESOLUTION = 8;    // PWM分解能 (8-bit = 0-255)

void setup() {
  Serial.begin(115200);
  while (!Serial) { ; }

  // --- TCC0タイマー設定 ---
  GCLK->GENDIV.reg = GCLK_GENDIV_DIV(1) | GCLK_GENDIV_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);

  GCLK->GENCTRL.reg = GCLK_GENCTRL_IDC | GCLK_GENCTRL_GENEN | GCLK_GENCTRL_SRC_DFLL48M | GCLK_GENCTRL_ID(GCLK_CLKCTRL_GEN_GCLK4_Val);
  while (GCLK->STATUS.bit.SYNCBUSY);

  GCLK->CLKCTRL.reg = GCLK_CLKCTRL_CLKEN | GCLK_CLKCTRL_GEN_GCLK4 | GCLK_CLKCTRL_ID_TCC0_TCC1;
  while (GCLK->STATUS.bit.SYNCBUSY);

  // D0をTCC0の出力に設定
  pinPeripheral(PWM_PIN, PIO_TIMER_ALT);

  TCC0->CTRLA.reg = TC_CTRLA_SWRST;
  while (TCC0->SYNCBUSY.bit.SWRST);

  // NP (Normal PWM) モード
  TCC0->WAVE.reg = TC_WAVE_WAVEGEN_NPWM;
  while (TCC0->SYNCBUSY.bit.WAVE);

  // 周波数を設定 (48MHz / 25kHz = 1920)
  TCC0->PER.reg = (48000000 / PWM_FREQUENCY) - 1;
  while (TCC0->SYNCBUSY.bit.PER);

  // --- デューティ比を50%に設定 ---
  // CC[0] for WO[4] (D0)
  TCC0->CC[0].reg = TCC0->PER.reg / 2;
  while (TCC0->SYNCBUSY.bit.CC0);

  // TCC0タイマーを有効化
  TCC0->CTRLA.reg |= TC_CTRLA_ENABLE;
  while (TCC0->SYNCBUSY.bit.ENABLE);

  Serial.println("Microblower driver (TC4428) started.");
  Serial.print("Frequency: ");
  Serial.print(PWM_FREQUENCY);
  Serial.println(" Hz");
}

void loop() {
  // 流量（電圧）を可変にしたい場合は、ここでデューティ比を変更する
  // デューティ比を0%に近づけると出力電圧は下がり、50%に近づけると最大になる
  // 例：アナログ入力(A1)に応じてデューティ比を0%〜50%で変更
  // int sensorValue = analogRead(A1);
  // int duty = map(sensorValue, 0, 1023, 0, TCC0->PER.reg / 2);
  // TCC0->CC[0].reg = duty;
  // delay(10);
}
```

### 動作の仕組み

1.  XIAOのD0から25kHz / 50%デューティのPWM信号を出力します。
2.  この信号をTC4428のIN_AとIN_Bの両方に入力します。
3.  TC4428のOUT_Aからは入力と同じ**非反転**の信号が、OUT_Bからは**反転**した信号が出力されます。
4.  ブロアの両端には、互いに逆位相の12V矩形波が印加され、結果として**24Vp-p**に近い交流電圧がかかり、ブロアが駆動します。
5.  ブロアの流量は、PWMのデューティ比を**50%から0%に近づける**ことで調整できます（デューティ比50%で最大出力）。
