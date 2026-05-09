#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ESP32Servo.h> // 🌟 引入我們剛剛裝好的 ESP32 專用 Servo 函式庫

// 藍牙 UUID
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID    "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// 腳位設定
const int LED_PIN = 2;   
const int SERVO_PIN = 4; // 🌟 SG90 的橘色訊號線接這裡

Servo myServo;           // 宣告一個伺服馬達物件
bool shouldBloom = false;

// 藍牙接收回呼
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue().c_str();
      if (rxValue.length() > 0) {
        Serial.print("📥 收到手機 BLE 指令: ");
        Serial.println(rxValue);
        if (rxValue == "BLOOM") {
          shouldBloom = true;
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // ==========================================
  // ⚙️ 伺服馬達初始化設定
  // ==========================================
  // 分配硬體計時器給 PWM 使用 (ESP32 的特殊要求)
  ESP32PWM::allocateTimer(0);
  ESP32PWM::allocateTimer(1);
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  
  myServo.setPeriodHertz(50); // 標準 SG90 是 50Hz
  myServo.attach(SERVO_PIN, 500, 2400); // 綁定腳位，並設定脈衝寬度範圍
  
  // 開機先讓馬達歸零 (花瓣閉合)
  myServo.write(0); 
  Serial.println("⚙️ 馬達初始化完成，目前位置: 0度");

  // ==========================================
  // 📡 藍牙初始化設定
  // ==========================================
  BLEDevice::init("EcoNexus_Flower");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("🌸 花花吊飾已啟動！等待手機藍牙連線...");
}

void loop() {
  if (shouldBloom) {
    Serial.println("✨ 執行物理回饋：花瓣緩緩張開、發光！");
    digitalWrite(LED_PIN, HIGH);
    
    // 🌟 讓花瓣緩慢平滑地張開 (從 0 度轉到 90 度)
    // 你可以修改 90 這個數字來調整花瓣張開的幅度
    for (int pos = 0; pos <= 70; pos += 2) { 
      myServo.write(pos);
      delay(15); // delay 越長，張開越慢
    }
    
    // 維持綻放 3 秒鐘
    delay(3000); 
    
    Serial.println("💤 物理回饋結束，花瓣緩緩閉合。");
    digitalWrite(LED_PIN, LOW);
    
    // 🌟 讓花瓣緩慢平滑地閉合 (從 90 度轉回 0 度)
    for (int pos = 70; pos >= 0; pos -= 2) { 
      myServo.write(pos);
      delay(15);
    }
    
    shouldBloom = false; 
  }
  
  delay(10); 
}