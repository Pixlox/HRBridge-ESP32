//
//  WorkoutManager.swift
//  HRBridge
//
//  Created by Omar Hafeezullah on 27/1/2026.
//


import Foundation
import HealthKit
import WatchConnectivity
import Combine

class WorkoutManager: NSObject, ObservableObject {
    
    @Published var heartRate: Int = 0
    @Published var isRunning: Bool = false
    @Published var statusMessage: String = "Ready"
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    private func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorized on Watch")
                    self.statusMessage = "Ready to start"
                } else {
                    self.statusMessage = "Need Health permission"
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            session?.delegate = self
            builder?.delegate = self
            
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.isRunning = true
                        self.statusMessage = "Monitoring..."
                        print("Workout started successfully")
                    } else {
                        self.statusMessage = "Failed to start"
                        print("Failed to start collection: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.statusMessage = "Error starting"
            }
            print("Failed to start workout: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusMessage = "Stopped"
            }
        }
    }
    
    private func sendHeartRateToPhone(_ hr: Int) {
        guard WCSession.default.isReachable else {
            print("Phone not reachable")
            return
        }
        
        let message = ["heartRate": hr]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Error sending HR to phone: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.isRunning = (toState == .running)
            
            switch toState {
            case .running:
                self.statusMessage = "Running"
            case .ended:
                self.statusMessage = "Ended"
            case .paused:
                self.statusMessage = "Paused"
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Session failed"
        }
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continue
            }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            let value = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
            
            if let hr = value {
                let heartRateInt = Int(hr)
                DispatchQueue.main.async {
                    self.heartRate = heartRateInt
                    print("Heart rate: \(heartRateInt) BPM")
                }
                self.sendHeartRateToPhone(heartRateInt)
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
}

// MARK: - WCSessionDelegate
extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if activationState == .activated {
                self.statusMessage = "Connected to iPhone"
            }
        }
        print("Watch session activated: \(activationState.rawValue)")
    }
}
