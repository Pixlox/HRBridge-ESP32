//
//  ContentView.swift
//  HRBridge
//
//  Created by Omar Hafeezullah on 27/1/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject var ble = BLEManager()
    @StateObject var watchConnectivity = WatchConnectivityManager.shared
    
    @State private var useAppleWatch = false
    @State private var manualHR = 75
    
    var displayHR: Int {
        useAppleWatch ? watchConnectivity.receivedHR : ble.currentHR
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Text("HR Bridge")
                .font(.system(size: 40, weight: .bold))
            
            // ESP32 Connection Status
            HStack {
                Circle()
                    .fill(ble.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(ble.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Watch Connection Status
            if useAppleWatch {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundColor(watchConnectivity.isWatchConnected ? .green : .orange)
                    
                    Text(watchConnectivity.isWatchConnected ? "Watch Connected" : "Watch App Not Running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Heart Rate Display
            VStack(spacing: 10) {
                Text("\(displayHR)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.red)
                
                Text("BPM")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(useAppleWatch ? "Apple Watch" : "Manual")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Apple Watch Toggle
            VStack(spacing: 15) {
                Toggle("Use Apple Watch HR", isOn: $useAppleWatch)
                    .font(.headline)
                
                if useAppleWatch && !watchConnectivity.isWatchConnected {
                    Text("Open the HR Bridge app on your Apple Watch")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // Manual Slider
            if !useAppleWatch {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Manual Control")
                        .font(.headline)
                    
                    HStack {
                        Text("40")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("200")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(manualHR) },
                            set: {
                                manualHR = Int($0)
                                ble.sendHR(manualHR)
                            }
                        ),
                        in: 40...200,
                        step: 1
                    )
                    .accentColor(.red)
                    .disabled(!ble.isConnected)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Connection Buttons
            if !ble.isConnected {
                Button(action: {
                    ble.startScan()
                }) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Connect to ESP32")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            } else {
                Button(action: {
                    ble.disconnect()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Disconnect")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Send watch HR to BLE when received
            watchConnectivity.onHeartRateUpdate = { hr in
                if useAppleWatch && ble.isConnected {
                    ble.sendHR(hr)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
