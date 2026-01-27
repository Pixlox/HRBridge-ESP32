//
//  WatchConnectivityManager.swift
//  HRBridge
//
//  Created by Omar Hafeezullah on 27/1/2026.
//


import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    
    @Published var receivedHR: Int = 0
    @Published var isWatchConnected = false
    
    var onHeartRateUpdate: ((Int) -> Void)?
    
    static let shared = WatchConnectivityManager()
    
    override private init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func sendMessage(_ message: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = (activationState == .activated)
            print("Watch session activated: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("Session deactivated")
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let hr = message["heartRate"] as? Int {
            DispatchQueue.main.async {
                self.receivedHR = hr
                self.onHeartRateUpdate?(hr)
                print("Received HR from Watch: \(hr)")
            }
        }
    }
}