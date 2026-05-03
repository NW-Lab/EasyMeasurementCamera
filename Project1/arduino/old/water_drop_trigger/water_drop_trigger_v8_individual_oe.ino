#if 0  // Legacy variant: disabled to avoid duplicate symbols when building v9

#include <SPI.h>
#include <Adafruit_NeoPixel.h>

// v8.0: Individual OE Control for True High-Speed Triggering
// - Corrects the previous misunderstanding. LE is for latching, OE is for output control.
// - LE and CLK are common to both ICs.
// - OE pins are separated (OE_RED, OE_WHITE) for individual, instant control.
// - Data is pre-loaded and latched once at setup.
// - Triggering is achieved by pulling the respective OE pin LOW (active low).

// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;
const int AMBIENT_LIGHT_PIN = A1;
const int NEOPIXEL_PIN = D2;

// TLC5916 Control Pins
const int TLC_LE_PIN = D3;            // Common Latch Enable for both ICs
const int TLC_OE_RED_PIN = D4;        // Output Enable for RED LED Driver (Active LOW)
const int TLC_OE_WHITE_PIN = D5;      // Output Enable for WHITE LED Driver (Active LOW)

// SPI pins are automatically used: MOSI (D10), SCK (D8)

// LED & System Configuration
const int NUM_NEOPIXELS = 6;
const byte TLC_CHANNEL_DATA = 0b00111111; // 6 channels ON
const byte TLC_ALL_OFF = 0b00000000;

// Timing Constants
const unsigned long LED_ON_DURATION = 4000;
const unsigned long COOLDOWN_PERIOD = 1000;

// State Machine
enum State { IDLE, RECORDING, COOLDOWN };
State currentState = IDLE;
unsigned long triggerTime = 0;

Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v8.0 - Correct Individual OE Control");

  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
  pinMode(AMBIENT_LIGHT_PIN, INPUT);
  pinMode(TLC_LE_PIN, OUTPUT);
  pinMode(TLC_OE_RED_PIN, OUTPUT);
  pinMode(TLC_OE_WHITE_PIN, OUTPUT);

  SPI.begin();
  pixels.begin();
  pixels.setBrightness(150);
  pixels.show();

  // Initialize TLCs to OFF state
  digitalWrite(TLC_OE_RED_PIN, HIGH);   // Disable Red outputs
  digitalWrite(TLC_OE_WHITE_PIN, HIGH); // Disable White outputs
  digitalWrite(TLC_LE_PIN, LOW);

  // --- Pre-load and Latch LED ON data into both TLC5916s ---
  Serial.println("Pre-loading and latching LED data...");
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(TLC_CHANNEL_DATA); // Data goes to both ICs' shift registers
  SPI.endTransaction();

  // Pulse the common LE pin to move data from shift registers to output latches
  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);
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

// --- High-Speed LED Control using OE ---

void startRecording() {
  // To turn on LEDs, just pull their respective OE pins LOW.
  // This is the correct, fastest method.
  digitalWrite(TLC_OE_RED_PIN, LOW);   // Enable Red LEDs
  digitalWrite(TLC_OE_WHITE_PIN, LOW); // Enable White LEDs

  // NeoPixel animation still runs
  for (int i = 0; i < pixels.numPixels(); i++) {
    pixels.setPixelColor(i, pixels.Color(255, 0, 0));
  }
  pixels.show();
}

void stopRecording() {
  digitalWrite(TLC_OE_RED_PIN, HIGH);   // Disable Red LEDs
  digitalWrite(TLC_OE_WHITE_PIN, HIGH); // Disable White LEDs
  pixels.clear();
  pixels.show();
}

// --- Special Mode functions are omitted for clarity in this version ---
// They would need to be adapted to use the common LE pin and one of the OE pins
// for the mode switching sequence.

#endif
