#include <SPI.h>
#include <Adafruit_NeoPixel.h>

// v5.0: Corrected TLC5916 control logic based on user feedback.
// - Uses a single shared Latch Enable (LE) pin for both cascaded TLC5916s.
// - No Chip Select (CS) is needed.
// - Sends 16 bits of data (8 for white, 8 for red) before a single LE pulse.

// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;      // Photocoupler input for water drop detection
const int NEOPIXEL_PIN = D2;          // NeoPixel data pin (via 74AHC1G125W5 level shifter)

// TLC5916 Control Pins (Shared for both ICs)
const int TLC_LE_PIN = D3;            // Latch Enable (LE) for both TLC5916s
const int TLC_OE_PIN = D4;            // Output Enable (OE_n) for both TLC5916s (Active LOW)

// SPI pins for XIAO SAMD21 (used by TLC5916)
// SDI -> MOSI (D10)
// CLK -> SCK (D8)

// LED Configuration
const int NUM_NEOPIXELS = 6;          // 6 NeoPixels (WS2813B)
const byte TLC_RED_CHANNELS = 0b00111111; // Turn on 6 channels for Red LEDs
const byte TLC_WHITE_CHANNELS = 0b00111111; // Turn on 6 channels for White LEDs
const byte TLC_ALL_OFF = 0b00000000;       // Turn off all 8 channels

// Timing Constants
const unsigned long LED_ON_DURATION = 4000;     // ms, Total LED on time
const unsigned long COOLDOWN_PERIOD = 1000;     // ms, Prevent immediate re-triggering
const int SENSOR_THRESHOLD = 500; // Adjust based on ambient light and sensor setup

// State Machine
enum State { IDLE, RECORDING, COOLDOWN };
State currentState = IDLE;

// Timing variables
unsigned long triggerTime = 0;

// Object Declarations
Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v5.0 - Corrected TLC5916 Logic");

  // Initialize Pins
  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
  pinMode(TLC_LE_PIN, OUTPUT);
  pinMode(TLC_OE_PIN, OUTPUT);

  // Initialize SPI for TLC5916
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));

  // Initialize NeoPixels
  pixels.begin();
  pixels.setBrightness(150); // Set brightness (0-255)
  pixels.clear();
  pixels.show(); // Initialize all pixels to 'off'

  // Initial state for TLC5916
  digitalWrite(TLC_OE_PIN, HIGH); // Disable outputs initially
  digitalWrite(TLC_LE_PIN, LOW);
  clearAllLeds();
  digitalWrite(TLC_OE_PIN, LOW); // Enable outputs

  Serial.println("System Ready. Waiting for trigger...");
}

void loop() {
  switch (currentState) {
    case IDLE:
      if (digitalRead(PHOTO_SENSOR_PIN) == HIGH) { // Assuming HIGH means drop detected
        Serial.println("TRIGGERED! Starting recording sequence.");
        triggerTime = millis();
        startRecording();
        currentState = RECORDING;
      }
      break;

    case RECORDING:
      if (millis() - triggerTime >= LED_ON_DURATION) {
        Serial.println("Recording finished. Entering cooldown.");
        stopRecording();
        currentState = COOLDOWN;
      }
      break;

    case COOLDOWN:
      if (millis() - triggerTime >= (LED_ON_DURATION + COOLDOWN_PERIOD)) {
        Serial.println("Cooldown finished. Ready for next trigger.");
        currentState = IDLE;
      }
      break;
  }
}

void startRecording() {
  // Turn on Red and White LEDs simultaneously using cascaded TLC5916s
  digitalWrite(TLC_OE_PIN, LOW); // Enable outputs
  
  // The first transfer() goes to the second chip in the chain (White).
  // The second transfer() goes to the first chip in the chain (Red).
  SPI.transfer(TLC_WHITE_CHANNELS); // Data for TLC5916 #2 (White LEDs)
  SPI.transfer(TLC_RED_CHANNELS);   // Data for TLC5916 #1 (Red LEDs)

  // Pulse the shared Latch Enable pin to update both TLC5916 outputs at the same time
  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);

  // Turn on NeoPixels (Red for trigger)
  for (int i = 0; i < pixels.numPixels(); i++) {
    pixels.setPixelColor(i, pixels.Color(255, 0, 0));
  }
  pixels.show();
}

void stopRecording() {
  // Turn off all TLC5916 LEDs
  clearAllLeds();

  // Turn off NeoPixels
  pixels.clear();
  pixels.show();
}

void clearAllLeds() {
  // Send 0s to both TLC5916s to turn off all channels
  SPI.transfer(TLC_ALL_OFF); // Data for TLC5916 #2
  SPI.transfer(TLC_ALL_OFF); // Data for TLC5916 #1

  // Latch the new data
  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);
  
  digitalWrite(TLC_OE_PIN, HIGH); // Disable outputs to be safe
}
