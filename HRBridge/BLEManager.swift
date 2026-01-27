import Foundation
import CoreBluetooth

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    @Published var currentHR = 75

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
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth ready")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {

        esp32 = peripheral
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {

        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {

        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([charUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {

        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.uuid == charUUID {
                hrChar = char
                print("Ready to send HR")
            }
        }
    }

    func sendHR(_ hr: Int) {
        guard let esp32 = esp32,
              let hrChar = hrChar else { return }

        currentHR = hr
        let data = Data([UInt8(hr)])
        esp32.writeValue(data, for: hrChar, type: .withoutResponse)
    }
}
