//
//  ContentView.swift
//  HRBridgeWatch Watch App
//
//  Created by Omar Hafeezullah on 27/1/2026.
//

import SwiftUI
import HealthKit
import WatchConnectivity

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                Text("HR Bridge")
                    .font(.headline)
                    .fontWeight(.bold)
                
                // Heart Rate Display
                VStack(spacing: 3) {
                    Text("\(workoutManager.heartRate)")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Status
                Text(workoutManager.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Start/Stop Button
                Button(action: {
                    if workoutManager.isRunning {
                        workoutManager.stopWorkout()
                    } else {
                        workoutManager.startWorkout()
                    }
                }) {
                    Text(workoutManager.isRunning ? "Stop" : "Start")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(workoutManager.isRunning ? Color.red : Color.green)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }
}

#Preview {
    ContentView()
}
