//
//  ContentView.swift
//  BLE background
//
//  Created by Per Friis on 26/01/2023.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: BLEStore
    var body: some View {
        VStack {
            if store.connected {
                    Text("button status: \(store.buttonsState)")
                    .font(.largeTitle)
                } else {
                    Text("Not connected")
                        .font(.title)
                }

            Button("Disconnect", action: disconnect)
                .buttonStyle(.borderedProminent)
                .font(.title)
                .padding()
        }
        .padding()
    }


    func disconnect() {
        store.disconnect()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BLEStore())
    }
}
