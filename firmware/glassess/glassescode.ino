#include <HardwareSerial.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_NeoPixel.h>
#include <esp_now.h>
#include <WiFi.h>

#define DEVICE_NAME "RadarGlasses"
#define SERVICE_UUID        "4FAFC201-1FB5-459E-8FCC-C5C9C331914B"
#define CHARACTERISTIC_UUID "BEB5483E-36E1-4688-B7F5-EA07361B26A8"
#define PHONE_WRITE_CHARACTERISTIC_UUID "D2A8A310-53A0-4E9B-9DAB-7069B0D9F31A"

#define WarnigLight 8
#define NUM_LEDS 8
#define stby_brightness 12

#define MAX_ESPNOW_PAYLOAD 250

uint8_t receiverMac[] = {0x94, 0xA9, 0x90, 0x96, 0xD4, 0x94};

typedef struct {
  uint8_t target_id;
  int8_t angle;
  uint8_t distance;
  uint16_t speed;
  char direction[4];
} TargetInfo;

typedef struct __attribute__((packed)) {
  uint8_t msgType;   // 'N' (0x4E)
  char    command;   // 'L','R','0','S'
} NavCommand;

HardwareSerial RadarSerial(1);
Adafruit_NeoPixel strip(NUM_LEDS, WarnigLight, NEO_GRB + NEO_KHZ800);

const uint8_t FRAME_HEADER[4] = {0xF4, 0xF3, 0xF2, 0xF1};
const uint8_t FRAME_FOOTER[4] = {0xF8, 0xF7, 0xF6, 0xF5};
uint8_t buffer[128];
int bufIndex = 0;

void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "ESP-NOW OK" : "ESP-NOW FAIL");
}

BLEServer *bleServer = nullptr;
BLECharacteristic *radarCharacteristic = nullptr;
BLECharacteristic *phoneWriteCharacteristic = nullptr;
volatile bool bleClientConnected = false;
volatile bool bleClientConnectedOld = false;
volatile bool hasPendingPhoneData = false;
char pendingPhoneData[64] = {0};
bool decelWarningActive = false;
bool radarWarningActive = false;
uint16_t radarWarningRisk = 0;
bool radarBlinkOn = false;
unsigned long lastRadarWarningMs = 0;
unsigned long lastRadarBlinkToggleMs = 0;
const unsigned long RADAR_WARNING_HOLD_MS = 3500;

void Enlighting(bool color, uint8_t brightness, uint16_t RiskLevel);
void showSolidColor(uint8_t red, uint8_t green, uint8_t blue, uint8_t brightness);
void updateRadarWarningLight();

class BLEServerCallbacksImpl : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    bleClientConnected = true;
    Serial.println("[BLE] iOS connected");
  }
  void onDisconnect(BLEServer *server) override {
    bleClientConnected = false;
    Serial.println("[BLE] iOS disconnected");
  }
};

class PhoneWriteCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    std::string value = characteristic->getValue();
    if (value.empty()) return;
    size_t copyLen = value.length();
    if (copyLen >= sizeof(pendingPhoneData)) copyLen = sizeof(pendingPhoneData) - 1;
    noInterrupts();
    memcpy(pendingPhoneData, value.data(), copyLen);
    pendingPhoneData[copyLen] = '\0';
    hasPendingPhoneData = true;
    interrupts();
  }
};

void processPendingPhoneData() {
  if (!hasPendingPhoneData) return;

  char msg[64];
  noInterrupts();
  strncpy(msg, pendingPhoneData, sizeof(msg) - 1);
  msg[sizeof(msg) - 1] = '\0';
  hasPendingPhoneData = false;
  interrupts();

  size_t len = strlen(msg);
  while (len > 0 && (msg[len - 1] == '\n' || msg[len - 1] == '\r')) {
    msg[--len] = '\0';
  }

  if (strncmp(msg, "BRAKE,", 6) == 0) {
    int brakeFlag = atoi(msg + 6);
    if (brakeFlag != 0) {
      Serial.println("[ALERT] Decel detected");
      decelWarningActive = true;
    } else {
      if (decelWarningActive) Serial.println("[ALERT] Decel ended");
      decelWarningActive = false;
      Enlighting(0, stby_brightness, 0);
    }
  }
  else if (strncmp(msg, "NAV,", 4) == 0 && len >= 5) {
    NavCommand nav;
    nav.msgType = 'N';
    nav.command = msg[4];
    esp_now_send(receiverMac, (uint8_t*)&nav, sizeof(NavCommand));
    Serial.printf("[NAV] Forwarded -> %c\n", nav.command);
  }
}

void sendTargetInfoViaBLE(TargetInfo *t) {
  if (!bleClientConnected || radarCharacteristic == nullptr) return;
  char buf[128];
  int len = snprintf(buf, sizeof(buf),
      "{\"target_id\":%d,\"angle\":%d,\"distance\":%d,\"speed\":%d,\"direction\":\"%s\"}\n",
      t->target_id, t->angle, t->distance, t->speed, t->direction);
  if (len > 0 && len < (int)sizeof(buf)) {
    radarCharacteristic->setValue((uint8_t *)buf, len);
    radarCharacteristic->notify();
  }
}

void sendTargetInfoViaESPNOW(TargetInfo* t) {
  esp_now_send(receiverMac, (uint8_t*)t, sizeof(TargetInfo));
}

void setup() {
  Serial.begin(115200);
  RadarSerial.begin(115200, SERIAL_8N1, 5, 4);
  Serial.println("LD2451 Frame Printer Ready");

  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW init failed");
    return;
  }
  esp_now_register_send_cb(OnDataSent);
  esp_now_peer_info_t peerInfo = {};
  memcpy(peerInfo.peer_addr, receiverMac, 6);
  peerInfo.channel = 0;
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) {
    Serial.println("ESP-NOW add peer failed");
    return;
  }

  BLEDevice::init(DEVICE_NAME);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new BLEServerCallbacksImpl());

  BLEService *service = bleServer->createService(SERVICE_UUID);
  radarCharacteristic = service->createCharacteristic(
      CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  radarCharacteristic->addDescriptor(new BLE2902());

  phoneWriteCharacteristic = service->createCharacteristic(
      PHONE_WRITE_CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  phoneWriteCharacteristic->setCallbacks(new PhoneWriteCallbacks());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  Serial.println("[BLE] Advertising started");
}

void Enlighting(bool color, uint8_t brightness, uint16_t RiskLevel) {
  if (RiskLevel != 0 && color == 1) {
    float interval = map(RiskLevel, 1, 10, 100, 10);
    for (int i = 0; i < NUM_LEDS; i++)
      strip.setPixelColor(i, strip.Color(color * 255, !color * 255, 0));
    strip.setBrightness(brightness);
    strip.show();
    delay(interval);
    strip.clear();
    strip.show();
    delay(interval);
  } else {
    strip.setBrightness(brightness);
    for (int i = 0; i < NUM_LEDS; i++)
      strip.setPixelColor(i, strip.Color(color * 255, !color * 255, 0));
    strip.show();
  }
}

void showSolidColor(uint8_t red, uint8_t green, uint8_t blue, uint8_t brightness) {
  strip.setBrightness(brightness);
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(red, green, blue));
  }
  strip.show();
}

short caculateRiskLevel(uint16_t speed) {
  if (speed >= 60) return 10;
  if (speed >= 40) return 8;
  if (speed >= 20) return 6;
  if (speed >= 10) return 4;
  if (speed >= 5)  return 2;
  if (speed > 0)   return 1;
  return 0;
}

void parseFrameData(int frameStart, int frameEnd) {
  uint8_t* payload = buffer + frameStart + 4;
  uint16_t dataLength = payload[0] | (payload[1] << 8);
  payload += 2;

  if (dataLength == 0) {
    Serial.println("No target");
    return;
  }

  uint8_t targetCount = payload[0];
  uint8_t alarmStatus = payload[1];
  Serial.printf("Targets: %d | Alarm: %s\n", targetCount,
                (alarmStatus & 0x01) ? "YES" : "NO");

  bool hasDangerTarget = false;
  uint16_t maxRiskLevel = 0;
  TargetInfo bestTarget;
  bool hasBestTarget = false;
  int bestThreatScore = 0;

  for (int i = 0; i < targetCount; i++) {
    uint8_t* target = payload + 2 + i * 5;
    if (target + 4 >= buffer + frameEnd) {
      Serial.println("Incomplete data");
      break;
    }

    int8_t angle = target[0] - 0x80;
    uint8_t distance = target[1];
    bool approaching = (target[2] & 0x01);
    uint16_t speed = target[3];
    uint8_t snr = target[4];

    Serial.printf("T%d: %+03ddeg %03dm %s %03dkm/h SNR%03d\n",
                  i + 1, angle, distance,
                  approaching ? "NEAR" : "FAR", speed, snr);

    if (approaching && distance <= 50) {
      uint16_t riskLevel = caculateRiskLevel(speed);
      if (riskLevel > maxRiskLevel) maxRiskLevel = riskLevel;
      hasDangerTarget = true;

      int threat = (int)riskLevel * 100 + (50 - (int)distance);
      if (threat > bestThreatScore) {
        bestThreatScore = threat;
        bestTarget.target_id = i + 1;
        bestTarget.angle = angle;
        bestTarget.distance = distance;
        bestTarget.speed = speed;
        strcpy(bestTarget.direction, "近");
        hasBestTarget = true;
      }
    }
  }

  if (hasBestTarget) {
    sendTargetInfoViaESPNOW(&bestTarget);
    sendTargetInfoViaBLE(&bestTarget);
  }

  if (hasDangerTarget) {
    radarWarningActive = true;
    radarWarningRisk = maxRiskLevel;
    lastRadarWarningMs = millis();
  }
  Serial.println("---");
}

void tryParseFrame() {
  if (bufIndex < 6) return;
  for (int start = 0; start <= bufIndex - 4; start++) {
    if (memcmp(buffer + start, FRAME_HEADER, 4) == 0) {
      uint16_t dataLength = buffer[start + 4] | (buffer[start + 5] << 8);
      int totalLength = 4 + 2 + dataLength + 4;
      if (start + totalLength > bufIndex) return;
      if (memcmp(buffer + start + totalLength - 4, FRAME_FOOTER, 4) == 0) {
        parseFrameData(start, start + totalLength);
        int remain = bufIndex - (start + totalLength);
        memmove(buffer, buffer + start + totalLength, remain);
        bufIndex = remain;
        return;
      }
    }
  }
}

void loop() {
  processPendingPhoneData();
  if (decelWarningActive) {
    showSolidColor(255, 90, 0, 80);
  } else {
    updateRadarWarningLight();
  }

  while (RadarSerial.available()) {
    buffer[bufIndex] = RadarSerial.read();
    if (++bufIndex >= (int)sizeof(buffer)) bufIndex = 0;
    tryParseFrame();
  }

  if (!bleClientConnected && bleClientConnectedOld) {
    delay(300);
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Re-advertising");
  }
  bleClientConnectedOld = bleClientConnected;
}

void updateRadarWarningLight() {
  unsigned long now = millis();

  if (radarWarningActive && (now - lastRadarWarningMs > RADAR_WARNING_HOLD_MS)) {
    radarWarningActive = false;
    radarWarningRisk = 0;
    radarBlinkOn = false;
    strip.clear();
    strip.show();
    Enlighting(0, stby_brightness, 0);
    return;
  }

  if (!radarWarningActive) {
    Enlighting(0, stby_brightness, 0);
    return;
  }

  uint16_t risk = radarWarningRisk == 0 ? 1 : radarWarningRisk;
  //unsigned long interval = map(risk, 1, 10, 650, 180);
  unsigned long interval = map(risk, 1, 10, 400, 125);

  if (now - lastRadarBlinkToggleMs >= interval) {
    lastRadarBlinkToggleMs = now;
    radarBlinkOn = !radarBlinkOn;
    if (radarBlinkOn) {
      showSolidColor(255, 0, 0, 128);
    } else {
      strip.clear();
      strip.show();
    }
  }
}
