#include <SPI.h>
#include <Adafruit_NeoPixel.h>

// v7.0: Individual LE Control for High-Speed Triggering
// - Separates LE pins for Red and White LED drivers (TLC_LE_RED_PIN, TLC_LE_WHITE_PIN).
// - Pre-loads LED channel data into shift registers at setup.
// - Triggers LEDs instantly by pulsing the corresponding LE pin, no SPI transfer needed.
// - This significantly reduces latency from trigger to light-on.

// Pin Definitions for Seeed XIAO SAMD21
const int PHOTO_SENSOR_PIN = A0;      // Photocoupler input for water drop detection
const int AMBIENT_LIGHT_PIN = A1;     // Ambient light sensor
const int NEOPIXEL_PIN = D2;          // NeoPixel data pin

// TLC5916 Control Pins
const int TLC_LE_RED_PIN = D3;        // Latch Enable for RED LED Driver
const int TLC_LE_WHITE_PIN = D5;      // Latch Enable for WHITE LED Driver
const int TLC_OE_PIN = D4;            // Shared Output Enable (OE_n, Active LOW)

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

// Object Declarations
Adafruit_NeoPixel pixels(NUM_NEOPIXELS, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

// -----------------------------------------------------------------------------
// Setup & Main Loop
// -----------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("Water Drop Trigger v7.0 - Individual LE Control");

  pinMode(PHOTO_SENSOR_PIN, INPUT_PULLUP);
  pinMode(AMBIENT_LIGHT_PIN, INPUT);
  pinMode(TLC_LE_RED_PIN, OUTPUT);
  pinMode(TLC_LE_WHITE_PIN, OUTPUT);
  pinMode(TLC_OE_PIN, OUTPUT);

  SPI.begin();
  pixels.begin();
  pixels.setBrightness(150);
  pixels.show();

  // Initialize TLCs to OFF state
  digitalWrite(TLC_OE_PIN, HIGH); // Disable outputs
  digitalWrite(TLC_LE_RED_PIN, LOW);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);

  // --- Pre-load LED ON data into both TLC5916 shift registers ---
  // This data will sit in the shift registers, ready to be latched.
  Serial.println("Pre-loading LED channel data into shift registers...");
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(TLC_CHANNEL_DATA); // This data goes to BOTH ICs as MOSI is shared
  SPI.endTransaction();
  Serial.println("Pre-load complete. Data is ready.");

  // Latch the pre-loaded data into the respective output latches.
  // The LEDs won't turn on yet because OE is HIGH (disabled).
  pulseLE(TLC_LE_RED_PIN);
  pulseLE(TLC_LE_WHITE_PIN);
  Serial.println("Data latched. Ready for OE trigger.");

  // You can still set dynamic brightness if needed
  // int initialLight = analogRead(AMBIENT_LIGHT_PIN);
  // uint8_t brightness_cc = mapLightToBrightness(initialLight);
  // uint8_t configByte = (brightness_cc << 2) | (1 << 1) | 1;
  // setBrightness(TLC_LE_RED_PIN, configByte); // Set red brightness
  // setBrightness(TLC_LE_WHITE_PIN, configByte); // Set white brightness

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

// -----------------------------------------------------------------------------
// High-Speed LED Control
// -----------------------------------------------------------------------------

void startRecording() {
  // To turn on LEDs, we just need to pull OE LOW.
  // The channel data is already latched and waiting.
  digitalWrite(TLC_OE_PIN, LOW); // Enable outputs INSTANTLY

  // You could also trigger them individually with LE pulses if OE is already LOW
  // pulseLE(TLC_LE_RED_PIN);
  // pulseLE(TLC_LE_WHITE_PIN);

  // NeoPixel animation still runs
  for (int i = 0; i < pixels.numPixels(); i++) {
    pixels.setPixelColor(i, pixels.Color(255, 0, 0));
  }
  pixels.show();
}

void stopRecording() {
  digitalWrite(TLC_OE_PIN, HIGH); // Disable outputs INSTANTLY
  pixels.clear();
  pixels.show();
}

/**
 * @brief Pulses a specific LE pin to latch data from shift register to output.
 */
void pulseLE(int pin) {
  digitalWrite(pin, HIGH);
  delayMicroseconds(1);
  digitalWrite(pin, LOW);
}


// -----------------------------------------------------------------------------
// Brightness Control (Special Mode) - Adapted for Individual LE
// -----------------------------------------------------------------------------

/**
 * @brief Sets the brightness for a SINGLE TLC5916 by targeting its LE pin.
 * @param target_le_pin The LE pin of the TLC5916 to configure.
 * @param configByte The 8-bit configuration code.
 */
void setBrightness(int target_le_pin, uint8_t configByte) {
  Serial.print("Setting Brightness for LE Pin "); Serial.print(target_le_pin);
  Serial.print(" - Config: 0x"); Serial.println(configByte, HEX);

  enterSpecialMode();

  // Send the configuration data. It goes to both ICs, but that's okay.
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
  SPI.transfer(configByte);
  SPI.endTransaction();

  // Latch the data ONLY into the target IC's configuration latch.
  pulseLE(target_le_pin);

  exitSpecialMode();
  Serial.println("Returned to Normal Mode.");
}

void enterSpecialMode() {
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(TLC_LE_RED_PIN, LOW);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);
  delayMicroseconds(1);

  pinMode(D8, OUTPUT); // SCK
  pinMode(D10, OUTPUT); // MOSI

  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 1
  digitalWrite(TLC_OE_PIN, HIGH); digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 2
  digitalWrite(TLC_OE_PIN, LOW); digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 3
  
  // For Special mode, LE needs to be high at 4th clock edge.
  // We can use one of the LE pins for this, it doesn't matter which.
  digitalWrite(TLC_LE_RED_PIN, HIGH); 
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 4

  digitalWrite(TLC_LE_RED_PIN, LOW);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 5

  digitalWrite(TLC_OE_PIN, HIGH);
}

void exitSpecialMode() {
  digitalWrite(TLC_OE_PIN, LOW);
  digitalWrite(TLC_LE_RED_PIN, LOW);
  digitalWrite(TLC_LE_WHITE_PIN, LOW);
  delayMicroseconds(1);

  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 1
  digitalWrite(TLC_OE_PIN, HIGH); digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 2
  digitalWrite(TLC_OE_PIN, LOW); digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 3
  
  // For Normal mode, LE is low at 4th clock edge.
  digitalWrite(TLC_OE_PIN, HIGH);
  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 4

  digitalWrite(D8, HIGH); digitalWrite(D8, LOW); // CLK 5

  digitalWrite(TLC_OE_PIN, HIGH);
}

uint8_t mapLightToBrightness(int lightValue) {
  int invertedValue = 1023 - lightValue;
  return map(invertedValue, 0, 1023, 0, 63);
}
