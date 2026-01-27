//
//  HealthKitManager.swift
//  HRBridge
//
//  Created by Omar Hafeezullah on 27/1/2026.
//


import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    
    @Published var currentHR: Int = 0
    @Published var isAuthorized = false
    @Published var statusMessage = "Not authorized"
    
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    // Callback to send HR to BLE
    var onHeartRateUpdate: ((Int) -> Void)?
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "HealthKit not available"
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let status = healthStore.authorizationStatus(for: heartRateType)
        
        switch status {
        case .sharingAuthorized:
            isAuthorized = true
            statusMessage = "Authorized"
        case .notDetermined:
            statusMessage = "Need permission"
        default:
            statusMessage = "Not authorized"
        }
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "HealthKit not available"
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthorized = true
                    self?.statusMessage = "Authorized"
                    print("HealthKit authorized!")
                } else {
                    self?.statusMessage = "Authorization failed"
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }
    
    func startMonitoring() {
        guard isAuthorized else {
            print("Not authorized to read heart rate")
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Create query for real-time heart rate updates
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSamples(samples)
        }
        
        // Set update handler for continuous monitoring
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSamples(samples)
        }
        
        heartRateQuery = query
        healthStore.execute(query)
        
        statusMessage = "Monitoring heart rate..."
        print("Started heart rate monitoring")
    }
    
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        statusMessage = "Stopped monitoring"
        print("Stopped heart rate monitoring")
    }
    
    private func processSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {
            return
        }
        
        guard let sample = heartRateSamples.last else {
            return
        }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
        let heartRateInt = Int(heartRate)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentHR = heartRateInt
            self?.onHeartRateUpdate?(heartRateInt)
            print("Heart rate updated: \(heartRateInt) BPM")
        }
    }
}