#include <Adafruit_NeoPixel.h>

// v9.0: Fully Independent Bit-Banging Control
// - Corrects the fundamental misunderstanding: The TLC5916 has a standard
//   shift register interface, NOT SPI.
// - Each TLC5916 is controlled by 4 independent GPIO pins (8 total).
// - All data transfer is done via bit-banging (manual GPIO control).
// - This provides maximum control and clarifies the interface.

// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;      // D0
const int AMBIENT_LIGHT_PIN = A1;     // D1
const int NEOPIXEL_PIN = D2;          // D2

// TLC5916 #1 (RED) Control Pins
const int TLC1_SDI_PIN = D6;
const int TLC1_CLK_PIN = D7;
const int TLC1_LE_PIN = D8;
const int TLC1_OE_PIN = D9;           // Active LOW

// TLC5916 #2 (WHITE) Control Pins
const int TLC2_SDI_PIN = D3;
const int TLC2_CLK_PIN = D4;
const int TLC2_LE_PIN = D5;
const int TLC2_OE_PIN = D10;          // Active LOW

// LED & System Configuration
const int NUM_NEOPIXELS = 6;
const byte TLC_CHANNEL_DATA = 0b00111111; // 6 channels ON

// Timing Constants
const unsigned long LED_ON_DURATION = 4000;
const unsigned long COOLDOWN_PERIOD = 1000;

// State Machine
enum State { IDLE, RECORDING, COOLDOWN };
State currentState = IDLE;
unsigned long triggerTime = 0;

Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

// -----------------------------------------------------------------------------
// Bit-Banging Shift Register Control
// -----------------------------------------------------------------------------

/**
 * @brief Sends 8 bits of data to a specific TLC5916 using bit-banging.
 * @param sdiPin The SDI (Data) pin for the target IC.
 * @param clkPin The CLK (Clock) pin for the target IC.
 * @param data The 8-bit data to send (MSB first).
 */
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

// -----------------------------------------------------------------------------
// Setup & Main Loop
// -----------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v9.0 - Fully Independent Bit-Bang Control");

  // Sensor & NeoPixel Pins
  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
  pinMode(AMBIENT_LIGHT_PIN, INPUT);
  pixels.begin();
  pixels.setBrightness(150);
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
  Serial.println("System Ready.");
}

void loop() {
  switch (currentState) {
    case IDLE:
      if (digitalRead(PHOTO_SENSOR_PIN) == HIGH) {
        Serial.println("TRIGGERED!");
        triggerTime = millis();
        startRecording();
        currentState = RECORDING;
      }
      break;

    case RECORDING:
      if (millis() - triggerTime >= LED_ON_DURATION) {
        stopRecording();
        currentState = COOLDOWN;
      }
      break;

    case COOLDOWN:
      if (millis() - triggerTime >= (LED_ON_DURATION + COOLDOWN_PERIOD)) {
        currentState = IDLE;
        Serial.println("Ready for next trigger.");
      }
      break;
  }
}

// --- High-Speed LED Control using Independent OE ---

void startRecording() {
  // Enable outputs by pulling their respective OE pins LOW.
  digitalWrite(TLC1_OE_PIN, LOW);   // Enable Red LEDs
  digitalWrite(TLC2_OE_PIN, LOW); // Enable White LEDs

  for (int i = 0; i < pixels.numPixels(); i++) {
    pixels.setPixelColor(i, pixels.Color(255, 0, 0));
  }
  pixels.show();
}

void stopRecording() {
  digitalWrite(TLC1_OE_PIN, HIGH);   // Disable Red LEDs
  digitalWrite(TLC2_OE_PIN, HIGH); // Disable White LEDs
  pixels.clear();
  pixels.show();
}
