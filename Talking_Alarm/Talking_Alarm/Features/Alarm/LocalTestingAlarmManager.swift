import Foundation
import UserNotifications
import AVFoundation

// MARK: - Local Testing Alarm Manager (No Apple ID Required)
final class LocalTestingAlarmManager: ObservableObject {
    static let shared = LocalTestingAlarmManager()
    
    @Published var isAuthorized = false
    @Published var scheduledAlarms: [String] = []
    
    private let personalWakeMessageFileName = "personal-wake-message.m4a"
    private let fallbackSoundFileName = "alarm-fallback-30s.caf"
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            DebugLogger.log("[LocalTestingAlarmManager] Authorization failed: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Personal Wake Message Generation
    
    func generatePersonalWakeMessage(name: String, goal: String) async throws {
        DebugLogger.log("[LocalTestingAlarmManager] Generating personal wake message for \(name)")
        
        // Generate personalized wake message using TTSService
        try await TTSService.shared.generatePersonalWakeMessage(name: name, goal: goal)
        
        DebugLogger.log("[LocalTestingAlarmManager] Personal wake message generated and saved")
    }
    
    // MARK: - Alarm Scheduling (Local Notifications)
    
    func scheduleImmediateAlarm(name: String, goal: String, delaySeconds: TimeInterval = 10) async throws {
        guard isAuthorized else {
            throw LocalAlarmError.notAuthorized
        }
        
        // Cancel any existing alarms first
        await cancelAllAlarms()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Talking Alarm - Time to Wake Up!"
        content.body = "Good morning \(name)! Time to wake up and \(goal). Let's prove you're conscious and ready to succeed!"
        
        // Try to use the personalized wake message sound, fallback to default
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let soundsPath = documentsPath.appendingPathComponent("Library/Sounds")
        let personalWakeMessageURL = soundsPath.appendingPathComponent(personalWakeMessageFileName)
        
        if FileManager.default.fileExists(atPath: personalWakeMessageURL.path) {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(personalWakeMessageFileName))
            DebugLogger.log("[LocalTestingAlarmManager] Using personalized wake message sound: \(personalWakeMessageFileName)")
        } else {
            content.sound = .default
            DebugLogger.log("[LocalTestingAlarmManager] Personalized wake message not found, using default sound")
        }
        
        content.categoryIdentifier = "TALKING_ALARM"
        
        // Add custom data
        content.userInfo = [
            "name": name,
            "goal": goal,
            "type": "talking_alarm_immediate"
        ]
        
        // Create trigger for immediate alarm (one-time)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
        
        // Create request
        let identifier = "talking_alarm_immediate_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule the notification
        try await UNUserNotificationCenter.current().add(request)
        
        await MainActor.run {
            self.scheduledAlarms.append(identifier)
        }
        
        DebugLogger.log("[LocalTestingAlarmManager] Immediate alarm scheduled for \(delaySeconds) seconds from now with identifier: \(identifier)")
    }
    
    func schedulePersonalizedAlarm(at date: Date, name: String, goal: String) async throws {
        guard isAuthorized else {
            throw LocalAlarmError.notAuthorized
        }
        
        // Cancel any existing alarms first
        await cancelAllAlarms()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Talking Alarm - Time to Wake Up!"
        content.body = "Good morning \(name)! Time to wake up and \(goal). Let's prove you're conscious and ready to succeed!"
        content.sound = .default
        content.categoryIdentifier = "TALKING_ALARM"
        
        // Add custom data
        content.userInfo = [
            "name": name,
            "goal": goal,
            "alarmTime": date.timeIntervalSince1970,
            "type": "talking_alarm"
        ]
        
        // Create trigger for daily recurrence - use only hour and minute
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        // Ensure we have valid components
        guard let hour = components.hour, let minute = components.minute else {
            throw LocalAlarmError.alarmSchedulingFailed
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute),
            repeats: true
        )
        
        // Create request
        let identifier = "talking_alarm_daily"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule the notification
        try await UNUserNotificationCenter.current().add(request)
        
        await MainActor.run {
            self.scheduledAlarms.append(identifier)
        }
        
        DebugLogger.log("[LocalTestingAlarmManager] Daily recurring alarm scheduled for \(hour):\(String(format: "%02d", minute)) with identifier: \(identifier)")
    }
    
    func cancelAllAlarms() async {
        guard isAuthorized else { return }
        
        // Cancel all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        await MainActor.run {
            self.scheduledAlarms.removeAll()
        }
        
        DebugLogger.log("[LocalTestingAlarmManager] All alarms cancelled")
    }
    
    // MARK: - Sound File Management
    
    private func getPersonalWakeMessageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let soundsDirectory = documentsPath.appendingPathComponent("Sounds")
        
        // Create Sounds directory if it doesn't exist
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        
        return soundsDirectory.appendingPathComponent(personalWakeMessageFileName)
    }
    
    
    private func generateTTSWithiOS(text: String) async throws {
        // For now, we'll just create a simple text file with the message
        // The actual TTS will be handled by the system when the notification fires
        let fileURL = getPersonalWakeMessageURL()
        
        // Create the directory if it doesn't exist
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Write the text to a file for now
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        
        DebugLogger.log("[LocalTestingAlarmManager] Personal wake message text saved to: \(fileURL.path)")
        DebugLogger.log("[LocalTestingAlarmManager] Message: \(text)")
    }
    
    // MARK: - Alarm Launch Detection
    
    func handleAlarmLaunch() async -> (name: String, goal: String)? {
        // For local testing, we'll simulate alarm launch detection
        guard let name = UserDefaults.standard.string(forKey: "user_name"),
              let goal = UserDefaults.standard.string(forKey: "user_goal") else {
            return nil
        }
        
        return (name, goal)
    }
    
    // MARK: - Contextual Message Generation
    
    func generateContextualMessage(name: String, goal: String, currentTime: Date, weather: String?) async -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: currentTime)
        
        let weatherContext = weather != nil ? " It's \(weather!) outside." : ""
        
        return "Good morning \(name)! It's \(timeString) and time to wake up and \(goal).\(weatherContext) Let's prove you're conscious and ready to succeed today!"
    }
}

// MARK: - Supporting Types

struct LocalAlarmUserData: Codable {
    let name: String
    let goal: String
    let alarmTime: Date
}

enum LocalAlarmError: Error, LocalizedError {
    case notAuthorized
    case alarmSchedulingFailed
    case soundGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification authorization not granted"
        case .alarmSchedulingFailed:
            return "Failed to schedule alarm"
        case .soundGenerationFailed:
            return "Failed to generate personalized wake message"
        }
    }
}
