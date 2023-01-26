//
//  BLE_backgroundApp.swift
//  BLE background
//
//  Created by Per Friis on 26/01/2023.
//

import SwiftUI

@main
struct BLE_backgroundApp: App {
    @StateObject var store = BLEStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
