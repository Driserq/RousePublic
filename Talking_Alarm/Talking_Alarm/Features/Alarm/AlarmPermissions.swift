import Foundation
import UserNotifications
import AVFoundation

// MARK: - Alarm Permissions for iOS 18.6 Compatibility
enum AlarmPermissions {
    static func requestNotificationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
    
    static func requestAlarmPermissions() async -> Bool {
        DebugLogger.log("[AlarmPermissions] Requesting alarm permissions...")
        
        // Request notification permissions (required for local notifications)
        let notificationGranted = await requestNotificationAuthorization()
        guard notificationGranted else {
            DebugLogger.log("[AlarmPermissions] Notification permission denied")
            return false
        }
        
        // Check if we can access notifications
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let canSchedule = settings.authorizationStatus == .authorized
        
        DebugLogger.log("[AlarmPermissions] Notification permissions: \(canSchedule)")
        
        // For iOS 18.6, we use local notifications instead of AlarmKit
        // AlarmKit requires iOS 26.0+ which is not available on your device
        DebugLogger.log("[AlarmPermissions] Using local notifications for iOS 18.6 compatibility")
        
        return canSchedule
    }
    
    static func checkCurrentPermissions() async -> (notifications: Bool, microphone: Bool) {
        // Check notification permissions
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        let notificationsGranted = notificationSettings.authorizationStatus == .authorized
        
        // Check microphone permissions using modern API
        let microphoneStatus = AVAudioApplication.shared.recordPermission
        let microphoneGranted = microphoneStatus == .granted
        
        DebugLogger.log("[AlarmPermissions] Current permissions - Notifications: \(notificationsGranted), Microphone: \(microphoneGranted)")
        
        return (notifications: notificationsGranted, microphone: microphoneGranted)
    }
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    static func requestAllPermissions() async -> (notifications: Bool, microphone: Bool) {
        DebugLogger.log("[AlarmPermissions] Requesting all permissions...")
        
        // Request notification permissions
        let notificationsGranted = await requestNotificationAuthorization()
        
        // Request microphone permissions
        let microphoneGranted = await requestMicrophonePermission()
        
        DebugLogger.log("[AlarmPermissions] All permissions requested - Notifications: \(notificationsGranted), Microphone: \(microphoneGranted)")
        
        return (notifications: notificationsGranted, microphone: microphoneGranted)
    }
}