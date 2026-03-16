#include <SPI.h>
#include <Adafruit_NeoPixel.h>

// v6.0: Dynamic Brightness Control using TLC5916 Special Mode
// - Implements functions to enter/exit Special Mode.
// - Allows setting brightness for each cascaded TLC5916 independently.
// - Reads an ambient light sensor to adjust LED current dynamically.

// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;      // Photocoupler input for water drop detection
const int AMBIENT_LIGHT_PIN = A1;     // Ambient light sensor (e.g., LDR voltage divider)
const int NEOPIXEL_PIN = D2;          // NeoPixel data pin (via 74AHC1G125W5 level shifter)

// TLC5916 Control Pins (Shared for both ICs)
const int TLC_LE_PIN = D3;            // Latch Enable (LE) for both TLC5916s
const int TLC_OE_PIN = D4;            // Output Enable (OE_n) for both TLC5916s (Active LOW)

// SPI pins are automatically used: MOSI (D10), SCK (D8)

// LED & System Configuration
const int NUM_NEOPIXELS = 6;
const byte TLC_RED_CHANNELS = 0b00111111;   // Use 6 channels
const byte TLC_WHITE_CHANNELS = 0b00111111; // Use 6 channels
const byte TLC_ALL_OFF = 0b00000000;

// Timing Constants
const unsigned long LED_ON_DURATION = 4000;
const unsigned long COOLDOWN_PERIOD = 1000;

// State Machine
enum State { IDLE, RECORDING, COOLDOWN };
State currentState = IDLE;
unsigned long triggerTime = 0;

// Object Declarations
Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

// -----------------------------------------------------------------------------
// TLC5916 Special Mode Functions
// -----------------------------------------------------------------------------

/**
 * @brief Enters Special Mode for both TLC5916s.
 * According to the datasheet (Figure 16), this requires a specific
 * OE and LE pulse sequence synchronized with the clock.
 */
void enterSpecialMode() {
  // Ensure OE and LE start LOW
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(TLC_LE_PIN, LOW);
  delayMicroseconds(1);

  // Sequence to enter Special Mode: OE(1-0-1) pulse while LE is HIGH at the 4th clock edge.
  // We will manually control SPI pins for this precise timing.
  pinMode(D8, OUTPUT); // SCK
  pinMode(D10, OUTPUT); // MOSI

  // CLK 1
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  // CLK 2 (OE goes HIGH)
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  // CLK 3 (OE goes LOW)
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  // CLK 4 (LE goes HIGH, OE goes HIGH)
  digitalWrite(TLC_LE_PIN, HIGH);
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  // CLK 5 (LE goes LOW)
  digitalWrite(TLC_LE_PIN, LOW);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  // Restore OE to its default (disabled) state for safety
  digitalWrite(TLC_OE_PIN, HIGH);
}

/**
 * @brief Exits Special Mode and returns to Normal Mode.
 * Sequence is similar to entering, but LE is LOW at the 4th clock edge.
 */
void exitSpecialMode() {
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(TLC_LE_PIN, LOW);
  delayMicroseconds(1);

  // CLK 1
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);
  // CLK 2 (OE HIGH)
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);
  // CLK 3 (OE LOW)
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);
  // CLK 4 (LE stays LOW, OE HIGH)
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);
  // CLK 5
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW);

  digitalWrite(TLC_OE_PIN, HIGH);
}

/**
 * @brief Sets the brightness for both TLC5916s using a configuration code.
 * @param whiteConfig 8-bit configuration code for the white LED driver.
 * @param redConfig 8-bit configuration code for the red LED driver.
 */
void setBrightness(uint8_t whiteConfig, uint8_t redConfig) {
  Serial.print("Setting Brightness - White: 0x"); Serial.print(whiteConfig, HEX);
  Serial.print(", Red: 0x"); Serial.println(redConfig, HEX);

  enterSpecialMode();

  // In Special Mode, data sent via SPI is treated as configuration data.
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(whiteConfig); // First byte for the second chip in the chain
  SPI.transfer(redConfig);   // Second byte for the first chip
  SPI.endTransaction();

  // Latch the configuration data into the configuration latches
  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);

  exitSpecialMode();
  Serial.println("Returned to Normal Mode.");
}

/**
 * @brief Converts an analog light sensor reading to a 6-bit brightness value.
 * @param lightValue The analog reading (0-1023).
 * @return A 6-bit value (0-63) for the CC0-CC5 configuration bits.
 */
uint8_t mapLightToBrightness(int lightValue) {
  // Invert the reading so that darker ambient -> brighter LED
  int invertedValue = 1023 - lightValue;
  // Map the 0-1023 range to the 6-bit 0-63 range
  return map(invertedValue, 0, 1023, 0, 63);
}

// -----------------------------------------------------------------------------
// Main Application Logic
// -----------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v6.0 - Dynamic Brightness");

  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
  pinMode(AMBIENT_LIGHT_PIN, INPUT);
  pinMode(TLC_LE_PIN, OUTPUT);
  pinMode(TLC_OE_PIN, OUTPUT);

  SPI.begin();
  pixels.begin();
  pixels.setBrightness(150);
  pixels.show();

  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(TLC_LE_PIN, LOW);
  clearAllLeds();

  // --- Initial Brightness Setting ---
  int initialLight = analogRead(AMBIENT_LIGHT_PIN);
  Serial.print("Initial ambient light reading: "); Serial.println(initialLight);
  uint8_t brightness_cc = mapLightToBrightness(initialLight);

  // Construct the configuration code. CM=1, HC=1 for max range.
  // Format: {CC5, CC4, CC3, CC2, CC1, CC0, HC, CM}
  uint8_t configByte = (brightness_cc << 2) | (1 << 1) | 1;

  // Set both drivers to the same initial brightness
  setBrightness(configByte, configByte);

  Serial.println("System Ready.");
}

void loop() {
  // Note: For a real application, brightness adjustment would likely not happen
  // during the high-speed capture sequence. It would be set beforehand.
  // This loop demonstrates the principle.

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

void startRecording() {
  digitalWrite(TLC_OE_PIN, LOW); // Enable outputs
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(TLC_WHITE_CHANNELS);
  SPI.transfer(TLC_RED_CHANNELS);
  SPI.endTransaction();

  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);

  for (int i = 0; i < pixels.numPixels(); i++) {
    pixels.setPixelColor(i, pixels.Color(255, 0, 0));
  }
  pixels.show();
}

void stopRecording() {
  clearAllLeds();
  pixels.clear();
  pixels.show();
}

void clearAllLeds() {
  digitalWrite(TLC_OE_PIN, LOW);
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(TLC_ALL_OFF);
  SPI.transfer(TLC_ALL_OFF);
  SPI.endTransaction();

  digitalWrite(TLC_LE_PIN, HIGH);
  delayMicroseconds(1);
  digitalWrite(TLC_LE_PIN, LOW);
  digitalWrite(TLC_OE_PIN, HIGH);
}
