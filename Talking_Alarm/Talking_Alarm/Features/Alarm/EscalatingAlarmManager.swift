import Foundation
import UserNotifications
import AVFoundation
import ActivityKit

// MARK: - Escalating Alarm Manager

class EscalatingAlarmManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = EscalatingAlarmManager()
    
    // MARK: - Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private let ttsAudioManager = TTSAudioManager.shared
    private let activityManager = EscalatingAlarmActivityManager.shared
    private var isAudioPlaying = false
    private var currentLiveActivityId: String?
    
    // MARK: - Notification Intervals (in seconds)
    private let intervals: [TimeInterval] = [0, 45, 90, 135] // Production intervals
    private let testIntervals: [TimeInterval] = [0, 20, 40, 65] // Slightly longer gaps to prevent overlap
    
    // MARK: - Public Methods
    
    /// Check if we can request notification permissions (not previously denied)
    func canRequestPermissions() async -> Bool {
        let currentSettings = await notificationCenter.notificationSettings()
        return currentSettings.authorizationStatus != .denied
    }
    
    /// Request notification permissions and Live Activity permissions
    func requestAuthorization() async -> Bool {
        DebugLogger.log("[EscalatingAlarmManager] Starting authorization request...")
        
        // Check current authorization status first
        let currentSettings = await notificationCenter.notificationSettings()
        DebugLogger.log("[EscalatingAlarmManager] Current authorization status: \(currentSettings.authorizationStatus.rawValue)")
        DebugLogger.log("[EscalatingAlarmManager] Current alert setting: \(currentSettings.alertSetting.rawValue)")
        DebugLogger.log("[EscalatingAlarmManager] Current sound setting: \(currentSettings.soundSetting.rawValue)")
        
        // Check Live Activity authorization
        let liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        DebugLogger.log("[EscalatingAlarmManager] Live Activities enabled: \(liveActivitiesEnabled)")
        
        // If already authorized, return true
        if currentSettings.authorizationStatus == .authorized {
            DebugLogger.log("[EscalatingAlarmManager] Notifications already authorized")
            return true
        }
        
        // If denied, we can't request again
        if currentSettings.authorizationStatus == .denied {
            DebugLogger.log("[EscalatingAlarmManager] Authorization was previously denied - user must go to Settings")
            return false
        }
        
        // If not determined, request authorization
        if currentSettings.authorizationStatus == .notDetermined {
            DebugLogger.log("[EscalatingAlarmManager] Authorization not determined, requesting permissions...")
            
            // Request authorization with critical alerts
            do {
                DebugLogger.log("[EscalatingAlarmManager] Calling requestAuthorization with options: [.alert, .sound, .badge, .criticalAlert]")
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
                DebugLogger.log("[EscalatingAlarmManager] Notification authorization request result: \(granted)")
                
                // Double-check the status after request
                let newSettings = await notificationCenter.notificationSettings()
                DebugLogger.log("[EscalatingAlarmManager] New authorization status: \(newSettings.authorizationStatus.rawValue)")
                DebugLogger.log("[EscalatingAlarmManager] New alert setting: \(newSettings.alertSetting.rawValue)")
                DebugLogger.log("[EscalatingAlarmManager] New sound setting: \(newSettings.soundSetting.rawValue)")
                DebugLogger.log("[EscalatingAlarmManager] Critical alert setting: \(newSettings.criticalAlertSetting.rawValue)")
                
                return granted
            } catch {
                DebugLogger.log("[EscalatingAlarmManager] Authorization request failed: \(error)")
                return false
            }
        }
        
        // For any other status, return false
        DebugLogger.log("[EscalatingAlarmManager] Unexpected authorization status: \(currentSettings.authorizationStatus.rawValue)")
        return false
    }
    
    /// Schedule escalating alarm sequence
    func scheduleEscalatingAlarm(at date: Date, name: String, goal: String, useTestIntervals: Bool = false) async throws {
        DebugLogger.log("[EscalatingAlarmManager] Scheduling escalating alarm for \(name) at \(date)")
        
        // Check if escalating messages are ready
        guard await ttsAudioManager.areEscalatingMessagesReady() else {
            DebugLogger.log("[EscalatingAlarmManager] Escalating messages not ready, falling back to single notification")
            try await scheduleFallbackAlarm(at: date, name: name, goal: goal)
            return
        }
        
        // Cancel any existing alarms
        await cancelAllAlarms()
        
        // Start Live Activity for better Focus mode override
        currentLiveActivityId = await activityManager.startLiveActivity(name: name, goal: goal)
        
        // Get intervals (test or production)
        let alarmIntervals = useTestIntervals ? testIntervals : intervals
        
        // Schedule all 4 notifications
        for (index, interval) in alarmIntervals.enumerated() {
            let attempt = index + 1
            let triggerDate = date.addingTimeInterval(interval)
            
            try await scheduleNotification(
                attempt: attempt,
                triggerDate: triggerDate,
                name: name,
                goal: goal
            )
        }
        
        DebugLogger.log("[EscalatingAlarmManager] Scheduled \(alarmIntervals.count) escalating notifications")
    }
    
    /// Schedule immediate escalating alarm (for testing)
    func scheduleImmediateEscalatingAlarm(name: String, goal: String, delaySeconds: Int = 10, useTestIntervals: Bool = true) async throws {
        // First check if we have authorization
        let settings = await notificationCenter.notificationSettings()
        DebugLogger.log("[EscalatingAlarmManager] Current notification settings - Authorization: \(settings.authorizationStatus.rawValue), Alert: \(settings.alertSetting.rawValue), Sound: \(settings.soundSetting.rawValue)")
        
        // If not authorized, try to request authorization first
        if settings.authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            if !authorized {
                throw EscalatingAlarmError.authorizationDenied
            }
        }
        
        let fireDate = Date().addingTimeInterval(TimeInterval(delaySeconds))
        try await scheduleEscalatingAlarm(at: fireDate, name: name, goal: goal, useTestIntervals: useTestIntervals)
        DebugLogger.log("[EscalatingAlarmManager] Immediate escalating alarm scheduled to fire in \(delaySeconds) seconds")
    }
    
    /// Cancel remaining alarms when user responds
    func cancelRemainingAlarms(currentAttempt: Int) {
        // Only cancel remaining alarms if there are any
        guard currentAttempt < 4 else {
            DebugLogger.log("[EscalatingAlarmManager] No remaining alarms to cancel (current attempt: \(currentAttempt))")
            return
        }
        
        let remainingAttempts = (currentAttempt + 1)...4
        let identifiers = remainingAttempts.map { "escalating_alarm_\($0)" }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        DebugLogger.log("[EscalatingAlarmManager] Cancelled remaining alarms: \(identifiers)")
        
        // End Live Activity when user responds
        if let activityId = currentLiveActivityId {
            Task {
                await activityManager.endLiveActivity(activityId: activityId)
                currentLiveActivityId = nil
            }
        }
    }
    
    /// Cancel all escalating alarms
    func cancelAllAlarms() async {
        let allIdentifiers = (1...4).map { "escalating_alarm_\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        DebugLogger.log("[EscalatingAlarmManager] Cancelled all escalating alarms")
        
        // End Live Activity
        if let activityId = currentLiveActivityId {
            await activityManager.endLiveActivity(activityId: activityId)
            currentLiveActivityId = nil
        }
    }
    
    /// Check if audio is currently playing to prevent overlap
    func isCurrentlyPlayingAudio() -> Bool {
        return isAudioPlaying
    }
    
    /// Set audio playing state
    func setAudioPlayingState(_ playing: Bool) {
        isAudioPlaying = playing
    }
    
    /// Update Live Activity for current attempt
    func updateLiveActivityForAttempt(_ attempt: Int, timeRemaining: TimeInterval? = nil) {
        guard let activityId = currentLiveActivityId else { return }
        
        Task {
            await activityManager.updateLiveActivity(
                activityId: activityId,
                currentAttempt: attempt,
                timeRemaining: timeRemaining
            )
        }
    }
    
    /// Stop Live Activity
    func stopLiveActivity() {
        guard let activityId = currentLiveActivityId else { return }
        
        Task {
            await activityManager.endLiveActivity(activityId: activityId)
            currentLiveActivityId = nil
        }
    }
    
    
    // MARK: - Private Methods
    
    private func scheduleNotification(attempt: Int, triggerDate: Date, name: String, goal: String) async throws {
        guard let audioFile = await ttsAudioManager.getAudioFile(for: attempt) else {
            throw EscalatingAlarmError.audioFileNotFound(attempt)
        }
        
        // Get the audio file URL for the notification sound
        guard let soundURL = ttsAudioManager.getEscalatingAlarmSoundURL(forAttempt: attempt) else {
            throw EscalatingAlarmError.audioFileNotFound(attempt)
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = audioFile.template.notificationTitle
        content.body = audioFile.template.notificationBody
        content.categoryIdentifier = "TALKING_ALARM"
        
        // Use the custom audio file for the notification sound
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundURL.lastPathComponent))
        content.userInfo = [
            "name": name,
            "goal": goal,
            "attempt": attempt,
            "type": "escalating_alarm"
        ]
        
        // Set interruption level for better visibility (iOS 15+)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .critical
        }
        
        DebugLogger.log("[EscalatingAlarmManager] Using custom audio file: \(soundURL.lastPathComponent) for attempt \(attempt)")
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0, triggerDate.timeIntervalSinceNow),
            repeats: false
        )
        
        // Create request
        let identifier = "escalating_alarm_\(attempt)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        try await notificationCenter.add(request)
        DebugLogger.log("[EscalatingAlarmManager] Scheduled attempt \(attempt) for \(triggerDate)")
    }
    
    private func scheduleFallbackAlarm(at date: Date, name: String, goal: String) async throws {
        // Fallback to single notification with default sound
        let content = UNMutableNotificationContent()
        content.title = "Talking Alarm"
        content.body = "Time to wake up and work on your goal!"
        content.sound = .default
        content.userInfo = [
            "name": name,
            "goal": goal,
            "type": "fallback_alarm"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0, date.timeIntervalSinceNow),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "fallback_alarm",
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
        DebugLogger.log("[EscalatingAlarmManager] Scheduled fallback alarm")
    }
}

// MARK: - Error Types

enum EscalatingAlarmError: Error, LocalizedError {
    case audioFileNotFound(Int)
    case schedulingFailed
    case authorizationDenied
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound(let attempt):
            return "Audio file not found for attempt \(attempt)"
        case .schedulingFailed:
            return "Failed to schedule escalating alarm"
        case .authorizationDenied:
            return "Notification authorization denied"
        }
    }
}

