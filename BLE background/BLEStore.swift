//
//  BLEStore.swift
//  BLE background
//
//  Created by Per Friis on 26/01/2023.
//

import Foundation
import CoreBluetooth
import os.log
import UserNotifications
import UIKit

final class BLEStore: NSObject, ObservableObject {
    @Published private(set) var buttonsState: Int = 0
    @Published private(set) var connected = false

    private let debugLog: Logger = .init(subsystem: Bundle.main.bundleIdentifier!, category: "BLEStore")

    private(set) var centralManager: CBCentralManager!
    private(set) var sensorTag: CBPeripheral?
    private(set) var scanServices: [CBUUID]?

    override init() {
        super.init()
        centralManager = .init(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.friisconsult.backgroundble"])
    }


    func requestNotificationAuthorization() {
        Task {
            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .badge, .alert])
            } catch {
                print(error as NSError)
                fatalError()
            }
        }
    }


    func disconnect() {

        centralManager.stopScan()

        centralManager.scanForPeripherals(withServices: [.advertiseService])
        objectWillChange.send()
        guard let sensorTag else { return }
        centralManager.cancelPeripheralConnection(sensorTag)

    }

    private func updateBatch() {
        Task {
            let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized else { return }
            var badgeCount = await UIApplication.shared.applicationIconBadgeNumber
            switch buttonsState {
            case 1:
                badgeCount += buttonsState
            case 2:
                badgeCount -= 1

            default:
                break;
            }

            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: badgeCount)
            let notification = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try await UNUserNotificationCenter.current().add(notification)
        }

    }

}

extension BLEStore: CBCentralManagerDelegate {


    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if let scanServices {
                central.scanForPeripherals(withServices: scanServices)
            } else {
                central.scanForPeripherals(withServices: [.advertiseService])
            }

            if let sensorTag, sensorTag.state == .disconnected {
                central.connect(sensorTag)
            }

        default:
            debugLog.info("ℹ:\(#function) - unhandled state, not important for this demo")
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        debugLog.info("ℹ:\(#function) - \(dict.keys)")
        if let scanServices = dict["kCBRestoredScanServices"] as? [CBUUID] {
            self.scanServices = scanServices
        }
        if let periplerals = dict["kCBRestoredPeripherals"] as? [CBPeripheral]  {
            debugLog.info("ℹ:\(#function) - \(periplerals.compactMap({$0.identifier.uuidString}))")
            if let peripheral = periplerals.first {
                self.sensorTag = peripheral
                print(sensorTag!.state)

            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard peripheral.name == "CC2650 SensorTag",
              sensorTag == nil else {
            return
        }
        debugLog.info("ℹ:\(#function) - Got one")
        sensorTag = peripheral
        central.connect(peripheral)
    }


    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog.info("ℹ:\(#function)")
        central.stopScan()
        peripheral.delegate = self
        peripheral.discoverServices([.keyPressStateService])
        connected = peripheral.state == .connected
        requestNotificationAuthorization()
    }

    func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        debugLog.info("ℹ:\(#function) - ")
        connected = peripheral.state == .connected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connected = false
        guard error == nil else {
            debugLog.error("🛑:\(#function) - \(error!.localizedDescription)")
            sensorTag = nil
            return
        }
        debugLog.info("ℹ:\(#function)")
    }
}


extension BLEStore: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        debugLog.info("ℹ:\(#function)")

        if let service = peripheral.services?.first(where: {$0.uuid == .keyPressStateService}) {
            peripheral.discoverCharacteristics([.keyPressStateCharacteristic], for: service)
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debugLog.info("ℹ:\(#function)")

        if service.uuid == .keyPressStateService,
           let characteristic = service.characteristics?.first(where: {$0.uuid == .keyPressStateCharacteristic}) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        debugLog.info("ℹ:\(#function) - \(characteristic.uuid.uuidString)")

        switch characteristic.uuid  {
        case .keyPressStateCharacteristic:
            if let value = characteristic.value {
                buttonsState = Int(value[0])
            }
            if UIApplication.shared.applicationState != .active {
                updateBatch()
            }

        default:
            debugLog.critical("⚠️:\(#function) - We got a value we didn't asked for, characteristics: \(characteristic.uuid.uuidString)")
        }

    }
}

extension CBPeripheralState {
    var title: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        @unknown default:
            fatalError()
        }
    }
}

extension CBUUID {
    static let advertiseService = CBUUID(string: "AA80")

    /// uses the [CC2560 SensorTag from TI](https://www.ti.com/tool/TIDC-CC2650STK-SENSORTAG)
    /// Key Press state service
    static let keyPressStateService = CBUUID(string: "FFE0")

    /// And the the characteristic for the ``KeyPressStateService`` KeyPressState Characteristic
    static let keyPressStateCharacteristic = CBUUID(string: "FFE1")
}
