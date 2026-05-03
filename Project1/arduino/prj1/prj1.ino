#include <Adafruit_NeoPixel.h>
#define NEOPIXEL 1
// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;      // Photocoupler input for water drop detection
const int AMBIENT_LIGHT_PIN = A1;     // Ambient light sensor (e.g., LDR voltage divider)
const int NEOPIXEL_PIN = D2;          // NeoPixel data pin (via 74AHC1G125W5 level shifter)

// TLC5916 #1 (WHITE) Control Pins
const int TLC1_SDI_PIN = D6;
const int TLC1_CLK_PIN = D7;
const int TLC1_LE_PIN = D8;
const int TLC1_OE_PIN = D9;           // Active LOW

// TLC5916 #2 (RED) Control Pins
const int TLC2_SDI_PIN = D3;
const int TLC2_CLK_PIN = D4;
const int TLC2_LE_PIN = D5;
const int TLC2_OE_PIN = D10;          // Active LOW

// LED & System Configuration
const int NUM_NEOPIXELS = 6;
const byte TLC_CHANNEL_DATA = 0b00111111; // 6 channels ON

Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

void shiftOutData(int sdiPin, int clkPin, byte data) {
  // MSBFIRST
  for (int i = 7; i >= 0; i--)  {
    digitalWrite(clkPin, LOW);
    // Set the SDI pin to the current bit value
    if (data & (1 << i)) {
      digitalWrite(sdiPin, HIGH);
    } else {
      digitalWrite(sdiPin, LOW);
    }
    // Pulse the clock to shift the bit in
    digitalWrite(clkPin, HIGH);
    delayMicroseconds(1); // Clock pulse width
  }
  digitalWrite(clkPin, LOW); // End with clock low
}

void myISR(){
  Serial.println("Trigger");
#if NEOPIXEL
  for(int i=0 ;i<6;i++){
    pixels.setPixelColor(i,255,0,0); //red
  }
  pixels.show();
#else
//digitalWrite(TLC2_OE_PIN, LOW);   // Enable Red LEDs
#endif
  //1/240FPS = 4.2ms
  for(int i=0;i<9;i++)
    delayMicroseconds(1000);  

#if NEOPIXEL
  for(int i=0 ;i<6;i++){
    pixels.setPixelColor(i,255,255,255); //white
  }
  pixels.show();
#else
digitalWrite(TLC2_OE_PIN, HIGH);   // disenable Red LEDs
//digitalWrite(TLC1_OE_PIN, LOW);   // Enable WHITE LEDs
#endif

  for(int i=0;i<300;i++)
    delayMicroseconds(1000); // 
#if NEOPIXEL
  pixels.clear();
  pixels.show();
#else
digitalWrite(TLC1_OE_PIN, HIGH);   // disenable WHITE LEDs
#endif
}
void setup() {
 Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v6.0 - Dynamic Brightness");

  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
 
  //NeoPixel initialize
  pixels.begin();
  pixels.setBrightness(10);
  pixels.clear();
  pixels.show();

  // Setup all 8 TLC5916 control pins as outputs
  pinMode(TLC1_SDI_PIN, OUTPUT);
  pinMode(TLC1_CLK_PIN, OUTPUT);
  pinMode(TLC1_LE_PIN, OUTPUT);
  pinMode(TLC1_OE_PIN, OUTPUT);
  pinMode(TLC2_SDI_PIN, OUTPUT);
  pinMode(TLC2_CLK_PIN, OUTPUT);
  pinMode(TLC2_LE_PIN, OUTPUT);
  pinMode(TLC2_OE_PIN, OUTPUT);

  // Initialize TLCs to a known state (all outputs off)
  digitalWrite(TLC1_OE_PIN, HIGH); // Disable output
  digitalWrite(TLC1_LE_PIN, LOW);
  digitalWrite(TLC1_CLK_PIN, LOW);
  digitalWrite(TLC2_OE_PIN, HIGH); // Disable output
  digitalWrite(TLC2_LE_PIN, LOW);
  digitalWrite(TLC2_CLK_PIN, LOW);

  // --- Pre-load and Latch LED ON data into both TLC5916s independently ---
  Serial.println("Pre-loading and latching LED data...");
  
  // Load data into Red LED driver
  shiftOutData(TLC1_SDI_PIN, TLC1_CLK_PIN, TLC_CHANNEL_DATA);
  // Latch it
  digitalWrite(TLC1_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC1_LE_PIN, LOW);

  // Load data into White LED driver
  shiftOutData(TLC2_SDI_PIN, TLC2_CLK_PIN, TLC_CHANNEL_DATA);
  // Latch it
  digitalWrite(TLC2_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC2_LE_PIN, LOW);

  Serial.println("Data latched. Ready for OE trigger.");
  //割り込み準備
  attachInterrupt(digitalPinToInterrupt(PHOTO_SENSOR_PIN), myISR, FALLING); // 割り込み設定

  Serial.println("System Ready.");
}

void loop() {
  // put your main code here, to run repeatedly:
delay(1);
}
