_#include <Adafruit_NeoPixel.h>

// Project 2: Solenoid-Controlled Water Drop Trigger
// - Replaces passive photo-sensor detection with active solenoid control.
// - Triggers a water drop via a solenoid valve, then fires the LEDs after a calculated delay.

// Pin Definitions for Seeed XIAO SAMD21
const int SOLENOID_PIN = A0;          // D0, connected to MOSFET Gate
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

// --- Timing Parameters (Adjust these for your setup) ---
int solenoidOpenTime = 50;  // ms: How long the valve stays open (controls drop size)
int dropFallDelay = 150;    // ms: Time from valve close to when the drop hits the surface
int flashDelay = 10;        // ms: Time from drop impact to flash firing (for crown formation)
int ledOnDuration = 50;     // ms: How long the main LEDs stay on

Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRBW + NEO_KHZ800);

// -----------------------------------------------------------------------------
// Bit-Banging Shift Register Control (from Project 1)
// -----------------------------------------------------------------------------
void shiftOutData(int sdiPin, int clkPin, byte data) {
  for (int i = 7; i >= 0; i--)  {
    digitalWrite(clkPin, LOW);
    digitalWrite(sdiPin, (data & (1 << i)) ? HIGH : LOW);
    digitalWrite(clkPin, HIGH);
    delayMicroseconds(1);
  }
  digitalWrite(clkPin, LOW);
}

// -----------------------------------------------------------------------------
// Setup & Main Loop
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Project 2: Solenoid Water Drop Trigger");
  Serial.println("Send any character to trigger the sequence.");

  // Solenoid, NeoPixel, and TLC Pins
  pinMode(SOLENOID_PIN, OUTPUT);
  digitalWrite(SOLENOID_PIN, LOW); // Ensure valve is closed
  pixels.begin();
  pixels.setBrightness(150);
  pixels.show();

  pinMode(TLC1_SDI_PIN, OUTPUT); pinMode(TLC1_CLK_PIN, OUTPUT); pinMode(TLC1_LE_PIN, OUTPUT); pinMode(TLC1_OE_PIN, OUTPUT);
  pinMode(TLC2_SDI_PIN, OUTPUT); pinMode(TLC2_CLK_PIN, OUTPUT); pinMode(TLC2_LE_PIN, OUTPUT); pinMode(TLC2_OE_PIN, OUTPUT);

  // Initialize TLCs to OFF state
  digitalWrite(TLC1_OE_PIN, HIGH); digitalWrite(TLC1_LE_PIN, LOW); digitalWrite(TLC1_CLK_PIN, LOW);
  digitalWrite(TLC2_OE_PIN, HIGH); digitalWrite(TLC2_LE_PIN, LOW); digitalWrite(TLC2_CLK_PIN, LOW);

  // Pre-load and Latch LED ON data into both TLC5916s
  shiftOutData(TLC1_SDI_PIN, TLC1_CLK_PIN, TLC_CHANNEL_DATA);
  digitalWrite(TLC1_LE_PIN, HIGH); delayMicroseconds(1); digitalWrite(TLC1_LE_PIN, LOW);
  shiftOutData(TLC2_SDI_PIN, TLC2_CLK_PIN, TLC_CHANNEL_DATA);
  digitalWrite(TLC2_LE_PIN, HIGH); delayMicroseconds(1); digitalWrite(TLC2_LE_PIN, LOW);

  Serial.println("System Ready.");
}

void loop() {
  if (Serial.available() > 0) {
    Serial.read(); // Clear the buffer
    triggerSequence();
  }
}

// -----------------------------------------------------------------------------
// Water Drop & Flash Sequence
// -----------------------------------------------------------------------------
void triggerSequence() {
  Serial.println("--- SEQUENCE START ---");

  // 1. Open solenoid to release a drop
  Serial.print("1. Opening valve for "); Serial.print(solenoidOpenTime); Serial.println("ms...");
  digitalWrite(SOLENOID_PIN, HIGH);
  delay(solenoidOpenTime);

  // 2. Close solenoid
  Serial.println("2. Closing valve.");
  digitalWrite(SOLENOID_PIN, LOW);

  // 3. Wait for the drop to fall
  Serial.print("3. Waiting for drop to fall ("); Serial.print(dropFallDelay); Serial.println("ms)...");
  delay(dropFallDelay);

  // 4. Wait for the crown to form
  Serial.print("4. Waiting for crown to form ("); Serial.print(flashDelay); Serial.println("ms)...");
  delay(flashDelay);

  // 5. Fire the main LEDs!
  Serial.print("5. FLASH! ("); Serial.print(ledOnDuration); Serial.println("ms)");
  digitalWrite(TLC1_OE_PIN, LOW);   // Enable Red LEDs
  digitalWrite(TLC2_OE_PIN, LOW); // Enable White LEDs
  pixels.fill(pixels.Color(0, 255, 0), 0, NUM_NEOPIXELS);
  pixels.show();

  // 6. Turn off LEDs
  delay(ledOnDuration);
  digitalWrite(TLC1_OE_PIN, HIGH);
  digitalWrite(TLC2_OE_PIN, HIGH);
  pixels.clear();
  pixels.show();

  Serial.println("--- SEQUENCE END ---");
  Serial.println("\nReady for next trigger.");
}
