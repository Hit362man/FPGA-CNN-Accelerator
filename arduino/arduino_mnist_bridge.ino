/*
 * Example Arduino USB-to-FPGA bridge reconstructed for this repository.
 * NOT hardware-verified. Match the FPGA pins in your Quartus assignments.
 *
 * USB Serial @ 115200: 0xAA + 784 grayscale pixels.
 * Arduino pins: D2 -> serial_data_in, D3 -> bit_clk_in,
 *               D4 -> frame_start_in, GND -> FPGA GND.
 * FPGA expects one start pulse and then 784 bytes sent LSB first.
 * Arduino Uno has sufficient SRAM for the 784-byte frame buffer.
 */
#include <Arduino.h>

static const uint16_t PIXEL_COUNT = 784;
static const uint8_t PIN_DATA = 2;
static const uint8_t PIN_CLOCK = 3;
static const uint8_t PIN_FRAME = 4;
static uint8_t pixels[PIXEL_COUNT];

void setup() {
  pinMode(PIN_DATA, OUTPUT);
  pinMode(PIN_CLOCK, OUTPUT);
  pinMode(PIN_FRAME, OUTPUT);
  digitalWrite(PIN_DATA, LOW);
  digitalWrite(PIN_CLOCK, LOW);
  digitalWrite(PIN_FRAME, LOW);
  Serial.begin(115200);
  Serial.setTimeout(3000);
}

void loop() {
  if (Serial.available() == 0) return;
  if (Serial.read() != 0xAA) return;

  // Buffer the full image before shifting bits to the FPGA; avoids a
  // partial frame if USB data is not yet available.
  if (Serial.readBytes(reinterpret_cast<char *>(pixels), PIXEL_COUNT)
      != PIXEL_COUNT) return;

  digitalWrite(PIN_CLOCK, LOW);
  digitalWrite(PIN_FRAME, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_FRAME, LOW);
  delayMicroseconds(10);

  for (uint16_t pixel = 0; pixel < PIXEL_COUNT; ++pixel) {
    for (uint8_t bit = 0; bit < 8; ++bit) {
      digitalWrite(PIN_DATA, (pixels[pixel] >> bit) & 1);
      delayMicroseconds(2);
      digitalWrite(PIN_CLOCK, HIGH);
      delayMicroseconds(2);
      digitalWrite(PIN_CLOCK, LOW);
      delayMicroseconds(2);
    }
  }
  digitalWrite(PIN_DATA, LOW);
}
