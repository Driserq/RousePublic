import Foundation

// MARK: - App Intents for Alarm Launch Detection (Simplified for iOS 15)

// For iOS 15, we'll use a simpler approach without AppIntents
// This will be handled through notifications and local storage

// MARK: - App Launch Detection Manager

@available(iOS 15.0, *)
final class AppLaunchDetectionManager: ObservableObject {
    static let shared = AppLaunchDetectionManager()
    
    @Published var launchType: AppLaunchType = .manual
    @Published var contextualMessage: String?
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .alarmFired,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAlarmLaunch(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .contextualMessageReady,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleContextualMessageReady(notification)
        }
    }
    
    private func handleAlarmLaunch(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let intent = userInfo["intent"] as? String,
              let launchTypeString = userInfo["launch_type"] as? String else {
            self.launchType = .manual
            return
        }
        
        if intent == "start_verification" && launchTypeString == "alarm_kit" {
            self.launchType = .alarmKit
            generateContextualMessage()
        } else {
            self.launchType = .manual
        }
    }
    
    private func handleContextualMessageReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String else {
            return
        }
        
        contextualMessage = message
    }
    
    private func generateContextualMessage() {
        // Get user data from stored preferences
        guard let name = UserDefaults.standard.string(forKey: "user_name"),
              let goal = UserDefaults.standard.string(forKey: "user_goal") else {
            return
        }
        
        // Generate contextual message directly
        let currentTime = Date()
        let weather = "72°F and sunny" // Placeholder for local testing
        
        let contextualMessage = generateContextualMessage(
            name: name,
            goal: goal,
            currentTime: currentTime,
            weather: weather
        )
        
        // Store the contextual message for the app to use
        UserDefaults.standard.set(contextualMessage, forKey: "contextual_wake_message")
        
        // Post notification that contextual message is ready
        NotificationCenter.default.post(
            name: Notification.Name("contextualMessageReady"),
            object: nil,
            userInfo: [
                "message": contextualMessage,
                "weather": weather
            ]
        )
    }
    
    private func generateContextualMessage(name: String, goal: String, currentTime: Date, weather: String?) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: currentTime)
        
        let weatherContext = weather != nil ? " It's \(weather!) outside." : ""
        
        return "Good morning \(name)! It's \(timeString) and time to wake up and \(goal).\(weatherContext) Let's prove you're conscious and ready to succeed today!"
    }
    
    func reset() {
        launchType = .manual
        contextualMessage = nil
    }
}

// MARK: - Supporting Types

enum AppLaunchType {
    case manual
    case alarmKit
    case notification
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let contextualMessageReady = Notification.Name("contextualMessageReady")
}

// MARK: - Location Manager for Weather

import CoreLocation

@available(iOS 15.0, *)
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            if let location = currentLocation {
                continuation.resume(returning: location)
            } else {
                // Request location update
                locationManager.requestLocation()
                // This is simplified - in production you'd need proper async handling
                continuation.resume(throwing: NSError(domain: "LocationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Location not available"]))
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DebugLogger.log("[LocationManager] Location error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
    }
}
