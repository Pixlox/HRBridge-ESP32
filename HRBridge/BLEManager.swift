//
//  BLEManager.swift
//  HRBridge
//
//  Created by Omar Hafeezullah on 27/1/2026.
//


import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject {
    
    @Published var currentHR = 75
    @Published var isConnected = false
    @Published var statusMessage = "Not connected"
    
    private var central: CBCentralManager!
    private var esp32: CBPeripheral?
    private var hrChar: CBCharacteristic?
    
    let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890AB")
    let charUUID    = CBUUID(string: "12345678-1234-1234-1234-1234567890AC")
    
    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScan() {
        guard central.state == .poweredOn else {
            statusMessage = "Bluetooth not ready"
            return
        }
        
        statusMessage = "Scanning for ESP32..."
        // Scan for ALL devices (no service filter), we'll filter by name
        central.scanForPeripherals(withServices: nil, options: nil)
        
        // Stop scanning after 10 seconds if nothing found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.esp32 == nil {
                self?.central.stopScan()
                self?.statusMessage = "ESP32 not found"
            }
        }
    }
    
    func disconnect() {
        if let esp32 = esp32 {
            central.cancelPeripheralConnection(esp32)
        }
    }
    
    func sendHR(_ hr: Int) {
        guard let esp32 = esp32,
              let hrChar = hrChar,
              isConnected else {
            print("Cannot send - not connected")
            return
        }
        
        currentHR = hr
        let data = Data([UInt8(hr)])
        esp32.writeValue(data, for: hrChar, type: .withoutResponse)
        print("Sent HR: \(hr)")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "Bluetooth ready"
        case .poweredOff:
            statusMessage = "Turn on Bluetooth"
        case .unauthorized:
            statusMessage = "Bluetooth not authorized"
        case .unsupported:
            statusMessage = "Bluetooth not supported"
        default:
            statusMessage = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {
        
        // Filter by device name instead of service UUID
        guard let name = peripheral.name,
              name == "ESP32-HR-Bridge" else {
            return
        }
        
        print("Found ESP32: \(name)")
        
        esp32 = peripheral
        central.stopScan()
        statusMessage = "Connecting..."
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager,
                       didConnect peripheral: CBPeripheral) {
        
        print("Connected to ESP32")
        statusMessage = "Connected! Discovering services..."
        
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        
        statusMessage = "Failed to connect"
        print("Connection failed: \(error?.localizedDescription ?? "unknown")")
    }
    
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        
        isConnected = false
        statusMessage = "Disconnected"
        hrChar = nil
        esp32 = nil
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverServices error: Error?) {
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([charUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        
        guard let chars = service.characteristics else { return }
        
        for char in chars {
            if char.uuid == charUUID {
                hrChar = char
                isConnected = true
                statusMessage = "Ready to send HR!"
                print("Ready to send HR to ESP32")
            }
        }
    }
}
