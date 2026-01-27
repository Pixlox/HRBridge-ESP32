#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define HR_SERVICE_UUID        "180D"
#define HR_CHAR_UUID           "2A37"

#define DEVICE_INFO_SERVICE_UUID "180A"
#define MANUFACTURER_CHAR_UUID   "2A29"
#define MODEL_CHAR_UUID          "2A24"

#define PHONE_SERVICE_UUID     "12345678-1234-1234-1234-1234567890AB"
#define PHONE_CHAR_UUID        "12345678-1234-1234-1234-1234567890AC"

BLEServer *pServer;
BLECharacteristic *hrCharacteristic;
BLECharacteristic *phoneCharacteristic;

uint8_t heartRate = 75;

class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        Serial.println("Device connected");
        BLEDevice::startAdvertising();
    }

    void onDisconnect(BLEServer* pServer) {
        Serial.println("Device disconnected");
        BLEDevice::startAdvertising();
    }
};

class PhoneCharCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        uint8_t* pData = pCharacteristic->getData();
        size_t len = pCharacteristic->getValue().length();
        
        if (len > 0) {
            heartRate = pData[0];
            Serial.print("iPhone sent HR: ");
            Serial.println(heartRate);
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("\n\n=== ESP32 HR Bridge for Magene ===");

    BLEDevice::init("ESP32-HR-Bridge");

    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService *deviceInfoService = pServer->createService(DEVICE_INFO_SERVICE_UUID);
    
    BLECharacteristic *manufacturerChar = deviceInfoService->createCharacteristic(
        MANUFACTURER_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ
    );
    manufacturerChar->setValue("ESP32");
    
    BLECharacteristic *modelChar = deviceInfoService->createCharacteristic(
        MODEL_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ
    );
    modelChar->setValue("HR-Bridge");
    
    deviceInfoService->start();

    BLEService *hrService = pServer->createService(HR_SERVICE_UUID);
    
    hrCharacteristic = hrService->createCharacteristic(
        HR_CHAR_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    
    BLE2902 *ble2902 = new BLE2902();
    ble2902->setNotifications(true);
    hrCharacteristic->addDescriptor(ble2902);
    
    uint8_t initialHR[2] = {0x00, heartRate};
    hrCharacteristic->setValue(initialHR, 2);
    
    hrService->start();

    BLEService *phoneService = pServer->createService(PHONE_SERVICE_UUID);
    
    phoneCharacteristic = phoneService->createCharacteristic(
        PHONE_CHAR_UUID,
        BLECharacteristic::PROPERTY_WRITE | 
        BLECharacteristic::PROPERTY_WRITE_NR
    );
    phoneCharacteristic->setCallbacks(new PhoneCharCallbacks());
    
    phoneService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(HR_SERVICE_UUID);
    pAdvertising->addServiceUUID(DEVICE_INFO_SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    
    BLEDevice::startAdvertising();

    Serial.println("READY for Magene C606!");
    Serial.println("Device: ESP32-HR-Bridge");
    Serial.println("Waiting for connections...");
}

void loop() {
    uint8_t hrmData[2];
    hrmData[0] = 0x00;  // Flags: HR is UINT8, no other data
    hrmData[1] = heartRate;
    
    hrCharacteristic->setValue(hrmData, 2);
    hrCharacteristic->notify();
    
    Serial.print("Broadcasting HR: ");
    Serial.println(heartRate);
    
    delay(1000);
}
