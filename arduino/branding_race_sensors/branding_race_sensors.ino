// Branding Race: example firmware for two running platforms.
//
// One pulse sensor per platform (hall-effect + magnet on the roller, or an IR slot sensor),
// wired to the two interrupt pins of an Uno/Nano. Every SEND_INTERVAL_MS it prints:
//   PLAYER1:12.4
//   PLAYER2:9.8
// which is exactly what backend/src/serial/parser.js expects. Adjust the calibration below.

const uint8_t SENSOR_PINS[2] = {2, 3};         // interrupt pins on Uno/Nano
const float ROLLER_CIRCUMFERENCE_M = 0.20;     // distance travelled per roller revolution
const uint8_t PULSES_PER_REVOLUTION = 1;       // magnets per roller
const unsigned long SEND_INTERVAL_MS = 100;    // 10 readings per second per player
const unsigned long DEBOUNCE_US = 2000;        // ignore pulses closer than this

volatile unsigned long pulseCount[2] = {0, 0};
volatile unsigned long lastPulseUs[2] = {0, 0};
unsigned long lastSendMs = 0;

void countPulse(uint8_t i) {
  unsigned long now = micros();
  if (now - lastPulseUs[i] < DEBOUNCE_US) return;
  lastPulseUs[i] = now;
  pulseCount[i]++;
}
void onPulse1() { countPulse(0); }
void onPulse2() { countPulse(1); }

void setup() {
  Serial.begin(9600);  // must match DIGIRUN_BAUD_RATE in backend/.env
  for (uint8_t i = 0; i < 2; i++) pinMode(SENSOR_PINS[i], INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(SENSOR_PINS[0]), onPulse1, FALLING);
  attachInterrupt(digitalPinToInterrupt(SENSOR_PINS[1]), onPulse2, FALLING);
  lastSendMs = millis();
}

void loop() {
  unsigned long now = millis();
  unsigned long elapsed = now - lastSendMs;
  if (elapsed < SEND_INTERVAL_MS) return;
  lastSendMs = now;

  for (uint8_t i = 0; i < 2; i++) {
    noInterrupts();
    unsigned long pulses = pulseCount[i];
    pulseCount[i] = 0;
    interrupts();

    float meters = (pulses / (float)PULSES_PER_REVOLUTION) * ROLLER_CIRCUMFERENCE_M;
    float kmh = (meters / (elapsed / 1000.0)) * 3.6;

    Serial.print("PLAYER");
    Serial.print(i + 1);
    Serial.print(":");
    Serial.println(kmh, 1);
  }
}
