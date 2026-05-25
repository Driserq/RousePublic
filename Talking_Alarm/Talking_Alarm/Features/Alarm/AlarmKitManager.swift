import Foundation
import AlarmKit
import AppIntents
import ActivityKit
import AVFoundation
import UserNotifications
import UIKit

@available(iOS 26.0, *)
class AlarmKitManager: NSObject, ObservableObject {
    static let shared = AlarmKitManager()
    
    private let alarmManager = AlarmManager.shared
    private var currentAlarm: Alarm?
    private var alarmUpdatesTask: Task<Void, Never>?

    private struct AlarmData: AlarmMetadata {
        let name: String
        let goal: String
        let kind: String
    }

    private let pendingAlarmIdKey = "pendingAlarmId"
    private let pendingAlarmWasRetryKey = "pendingAlarmWasRetry"
    private let retryDelaySeconds: TimeInterval = 60

    private let maxRetryAttempts: Int = 15

    // Prevent double-scheduling when AlarmKit emits multiple `.alerting` updates while the first
    // schedule call is still awaiting.
    @MainActor private var isSchedulingProvisionalRetry: Bool = false
    
    override init() {
        super.init()
        // Start listening for AlarmKit updates when available
        startAlarmUpdatesListener()
    }

    deinit {
        alarmUpdatesTask?.cancel()
    }
    
    // MARK: - Authorization
    
    /// Check current authorization state without prompting the user
    func checkAuthorizationState() -> Bool {
        let currentState = alarmManager.authorizationState
        DebugLogger.log("[AlarmKitManager] Current authorization state: \(currentState)")
        return currentState == .authorized
    }
    
    func requestAuthorization() async -> Bool {
        do {
            // Check current authorization state first
            let currentState = alarmManager.authorizationState
            DebugLogger.log("[AlarmKitManager] Current authorization state: \(currentState)")
            
            // Only request if not already determined
            if currentState == .notDetermined {
                let status = try await alarmManager.requestAuthorization()
                DebugLogger.log("[AlarmKitManager] Authorization request result: \(status)")
                return status == .authorized
            } else {
                DebugLogger.log("[AlarmKitManager] Authorization already determined: \(currentState)")
                return currentState == .authorized
            }
        } catch {
            DebugLogger.log("[AlarmKitManager] Authorization failed: \(error)")
            DebugLogger.log("[AlarmKitManager] Error domain: \(error._domain)")
            DebugLogger.log("[AlarmKitManager] Error code: \(error._code)")
            DebugLogger.log("[AlarmKitManager] Error userInfo: \(String(describing: error._userInfo))")
            return false
        }
    }

    // MARK: - Alarm Updates Listener

    private func startAlarmUpdatesListener() {
        guard alarmUpdatesTask == nil else { return }

        alarmUpdatesTask = Task.detached { [weak self] in
            guard let self else { return }
            for await alarms in self.alarmManager.alarmUpdates {
                // Look for any alerting alarm
                for alarm in alarms where alarm.state == .alerting {
                    DebugLogger.log("[AlarmKitManager] Alarm is alerting: \(alarm.id)")

                    let alarmId = alarm.id.uuidString
                    
                    // ALWAYS persist the alerting alarm ID for foreground recovery.
                    // This ensures we can recover even if the app state changes rapidly.
                    let retryIds = LocalStore.loadProvisionalRetryAlarmIDs()
                    let computedWasRetry = retryIds.contains(alarmId) || (LocalStore.loadCurrentRetryAlarmID() == alarmId)

                    let existingPendingId = UserDefaults.standard.string(forKey: self.pendingAlarmIdKey)
                    let existingWasRetry = UserDefaults.standard.bool(forKey: self.pendingAlarmWasRetryKey)

                    if existingPendingId != alarmId {
                        UserDefaults.standard.set(alarmId, forKey: self.pendingAlarmIdKey)
                        UserDefaults.standard.set(computedWasRetry, forKey: self.pendingAlarmWasRetryKey)
                        DebugLogger.log("[AlarmKitManager] Persisted pending alarm id: \(alarmId)")
                    } else if existingWasRetry == false, computedWasRetry == true {
                        UserDefaults.standard.set(true, forKey: self.pendingAlarmWasRetryKey)
                    }

                    if computedWasRetry {
                        // The retry alarm has now fired; remove it from the retry-id set.
                        LocalStore.removeProvisionalRetryAlarmID(alarmId)
                    }

                    // If this alerting alarm is the currently-tracked retry alarm, it has now
                    // "fired". Clear the lock so we can schedule the next retry if the system
                    // can't open the app.
                    if LocalStore.loadCurrentRetryAlarmID() == alarm.id.uuidString {
                        LocalStore.saveCurrentRetryAlarmID(nil)
                    }

                    // Schedule provisional retry only when app is not active
                    let shouldScheduleRetry = await MainActor.run {
                        UIApplication.shared.applicationState != .active
                    }
                    
                    if shouldScheduleRetry {
                        // If the system fails to open the app (common when user locks the phone),
                        // schedule a provisional retry so the user is re-alerted.
                        let attempts = LocalStore.loadRetryAttemptCount()
                        let existingRetryId = LocalStore.loadCurrentRetryAlarmID()
                        if existingRetryId == nil, attempts < self.maxRetryAttempts {
                            Task { @MainActor in
                                guard self.isSchedulingProvisionalRetry == false else { return }
                                self.isSchedulingProvisionalRetry = true
                                defer { self.isSchedulingProvisionalRetry = false }

                                let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
                                let goal = UserDefaults.standard.string(forKey: "user_goal") ?? "Wake up"
                                let alarmKind: AlarmKind = LocalStore.loadNapAlarmID() == alarmId ? .nap : .scheduled
                                let retryDate = Date().addingTimeInterval(self.retryDelaySeconds)
                                if let id = try? await self.scheduleFixedAlarm(at: retryDate, name: name, goal: goal, kind: alarmKind) {
                                    LocalStore.saveCurrentRetryAlarmID(id)
                                    LocalStore.addProvisionalRetryAlarmID(id)
                                    LocalStore.saveRetryAttemptCount(attempts + 1)
                                    DebugLogger.log("[AlarmKitManager] Provisional retry scheduled at \(retryDate) id=\(id) kind=\(alarmKind.logLabel)")
                                }
                            }
                        }
                    }
                    
                    // Post notification if app is active
                    Task { @MainActor in
                        // Check for active state to avoid killing alarm from background
                        // (which would silence it for the user if they haven't picked up the phone yet)
                        if UIApplication.shared.applicationState == .active {
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                            
                            let name = UserDefaults.standard.string(forKey: "user_name")
                            let goal = UserDefaults.standard.string(forKey: "user_goal")
                            
                            NotificationCenter.default.post(
                                name: .alarmFired,
                                object: nil,
                                userInfo: [
                                    "alarmId": alarm.id.uuidString,
                                    "name": name as Any,
                                    "goal": goal as Any,
                                    "source": "alarmkit"
                                ].compactMapValues { $0 }
                            )
                        } else {
                            DebugLogger.log("[AlarmKitManager] Alarm alerting in background - waiting for user interaction")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Foreground Check (The "Manual Open" Fix)
    
    func checkForActiveAlarms() async {
        let name = UserDefaults.standard.string(forKey: "user_name")
        let goal = UserDefaults.standard.string(forKey: "user_goal")

        // If an alarm fired while we were backgrounded, we may already have the id.
        if let pending = UserDefaults.standard.string(forKey: pendingAlarmIdKey),
           UUID(uuidString: pending) != nil {
            UserDefaults.standard.removeObject(forKey: pendingAlarmIdKey)
            let wasRetry = UserDefaults.standard.bool(forKey: pendingAlarmWasRetryKey)
            UserDefaults.standard.removeObject(forKey: pendingAlarmWasRetryKey)
            DebugLogger.log("[AlarmKitManager] Foreground recovery using pending alarm id: \(pending)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .alarmFired,
                    object: nil,
                    userInfo: [
                        "alarmId": pending,
                        "isRetry": wasRetry,
                        "name": name as Any,
                        "goal": goal as Any,
                        "source": "pending_id"
                    ].compactMapValues { $0 }
                )
            }
            return
        }
        
        // Check System Alarms
        do {
            // Ask system: "Is anything ringing right now?"
            let alarms = try alarmManager.alarms
            if let alertingAlarm = alarms.first(where: { $0.state == .alerting }) {
                DebugLogger.log("[AlarmKitManager] Found alerting alarm on foreground: \(alertingAlarm.id)")
                
                // IMPORTANT: Stop the alarm NOW to release audio focus for the app
                try alarmManager.stop(id: alertingAlarm.id)
                DebugLogger.log("[AlarmKitManager] Stopped alerting alarm to clear audio session.")
                
                // RE-FIRE the notification because we likely missed the original event
                // while in background or via the silent intent.
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .alarmFired,
                        object: nil,
                        userInfo: [
                            "alarmId": alertingAlarm.id.uuidString,
                            "isRetry": LocalStore.loadRetryAttemptCount() > 0,
                            "name": name as Any,
                            "goal": goal as Any,
                            "source": "foreground_check"
                        ].compactMapValues { $0 }
                    )
                }
            } else {
                DebugLogger.log("[AlarmKitManager] No alerting alarms found on foreground check.")
            }
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to check for active alarms: \(error)")
        }
    }
    
    // MARK: - Alarm Scheduling
    
    func cancelAllAlarms() async throws {
        do {
            let existingAlarms = try alarmManager.alarms
            DebugLogger.log("[AlarmKitManager] Found \(existingAlarms.count) existing alarms. Cancelling all...")
            for alarm in existingAlarms {
                try alarmManager.cancel(id: alarm.id)
            }
            currentAlarm = nil
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to fetch or cancel existing alarms: \(error)")
            throw error
        }
    }

    func cancelNonRetryAlarms() async {
        do {
            let existingAlarms = try alarmManager.alarms
            let retryIds = Set(LocalStore.loadProvisionalRetryAlarmIDs())
            let currentRetryId = LocalStore.loadCurrentRetryAlarmID()

            for alarm in existingAlarms {
                let alarmId = alarm.id.uuidString
                if retryIds.contains(alarmId) || alarmId == currentRetryId {
                    continue
                }
                try alarmManager.cancel(id: alarm.id)
            }
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to cancel non-retry alarms: \(error)")
        }
    }

    func findClosestNonRetryAlarmId(now: Date = Date()) async -> String? {
        do {
            let existingAlarms = try alarmManager.alarms
            let retryIds = Set(LocalStore.loadProvisionalRetryAlarmIDs())
            let currentRetryId = LocalStore.loadCurrentRetryAlarmID()

            let candidates = existingAlarms.filter { alarm in
                let alarmId = alarm.id.uuidString
                return !retryIds.contains(alarmId) && alarmId != currentRetryId
            }

            let datedCandidates: [(id: String, date: Date)] = candidates.compactMap { alarm in
                guard let triggerDate = nextTriggerDate(for: alarm, now: now) else { return nil }
                return (alarm.id.uuidString, triggerDate)
            }

            if let closest = datedCandidates.sorted(by: { $0.date < $1.date }).first {
                return closest.id
            }

            return candidates.first?.id.uuidString
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to fetch alarms for closest alarm lookup: \(error)")
            return nil
        }
    }

    private func nextTriggerDate(for alarm: Alarm, now: Date) -> Date? {
        guard let schedule = alarm.schedule else { return nil }
        let calendar = Calendar.current

        switch schedule {
        case .fixed(let date):
            return date
        case .relative(let relative):
            guard let timeDate = calendar.date(bySettingHour: relative.time.hour, minute: relative.time.minute, second: 0, of: now) else {
                return nil
            }

            switch relative.repeats {
            case .never:
                return TimeUtils.nextOccurrenceFromTimeOnly(timeDate, now: now)
            case .weekly(let days):
                var best: Date?
                for day in days {
                    let weekday = calendarWeekday(from: day)
                    guard let candidate = TimeUtils.nextOccurrence(for: weekday, time: timeDate, now: now) else { continue }
                    if best == nil || candidate < best! {
                        best = candidate
                    }
                }
                return best
            @unknown default:
                return nil
            }
        @unknown default:
            return nil
        }
    }

    private func calendarWeekday(from weekday: Locale.Weekday) -> Int {
        switch weekday {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        @unknown default: return 1
        }
    }

    func cancelAlarm(idString: String) async throws {
        guard let uuid = UUID(uuidString: idString) else { return }
        try alarmManager.cancel(id: uuid)
        if currentAlarm?.id == uuid {
            currentAlarm = nil
        }
    }
    
    func updateSchedule(_ schedule: [Int: Date]) async throws {
        // 1. Cancel all existing
        try await cancelAllAlarms()
        
        guard !schedule.isEmpty else { return }
        
        // 2. Group by Time (Hour:Minute)
        var timeGroups: [String: [Locale.Weekday]] = [:]
        var groupDates: [String: Date] = [:]
        let calendar = Calendar.current
        
        for (dayInt, date) in schedule {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let timeKey = String(format: "%02d:%02d", hour, minute)
            
            var weekday: Locale.Weekday?
            switch dayInt {
            case 1: weekday = .sunday
            case 2: weekday = .monday
            case 3: weekday = .tuesday
            case 4: weekday = .wednesday
            case 5: weekday = .thursday
            case 6: weekday = .friday
            case 7: weekday = .saturday
            default: break
            }
            
            if let wd = weekday {
                timeGroups[timeKey, default: []].append(wd)
                groupDates[timeKey] = date
            }
        }
        
        // 3. Schedule alarms
        let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
        let goal = UserDefaults.standard.string(forKey: "user_goal") ?? "Wake up"
        
        for (key, days) in timeGroups {
            if let date = groupDates[key] {
                _ = try await schedulePersonalizedAlarm(at: date, name: name, goal: goal, days: days, clearExisting: false)
            }
        }
    }
    
    func schedulePersonalizedAlarm(at date: Date, name: String, goal: String, kind: AlarmKind = .scheduled, days: [Locale.Weekday]? = nil, clearExisting: Bool = true) async throws -> String {
        // Cancel existing if requested
        if clearExisting {
            try? await cancelAllAlarms()
        }
        
        // Ensure the personalized wake sound exists in Library/Sounds
        let soundFileName = kind == .nap ? "personal-nap-message.m4a" : "personal-wake-message.m4a"
        let soundsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        let soundFileURL = soundsDirectory.appendingPathComponent(soundFileName)

        if !FileManager.default.fileExists(atPath: soundFileURL.path) {
            do {
                let _ = kind == .nap
                    ? try await TTSAudioManager.shared.generateConsolidatedNapMessage(userGoal: goal, personality: "motivational coach")
                    : try await TTSAudioManager.shared.generateConsolidatedWakeMessage(userGoal: goal, personality: "motivational coach")
            } catch {
                DebugLogger.log("[AlarmKitManager] Failed to generate personal \(kind.logLabel) message for custom sound: \(error)")
            }
        }

        // Create alarm attributes
        let stopButton = AlarmButton(
            text: "Stop",
            textColor: .red,
            systemImageName: "stop.circle"
        )

        let alertContent = AlarmPresentation.Alert(
            title: "Talking Alarm - \(name)",
            stopButton: stopButton
        )
        
        let presentation = AlarmPresentation(alert: alertContent)
        
        let metadata = AlarmData(name: name, goal: goal, kind: kind.rawValue)
        
        // Create alarm attributes
        let attributes = AlarmAttributes<AlarmData>(
            presentation: presentation,
            metadata: metadata,
            tintColor: .blue
        )
        
        // Traditional alarm: no snooze/repeat button.
        let alertSound: ActivityKit.AlertConfiguration.AlertSound = FileManager.default.fileExists(atPath: soundFileURL.path)
            ? .named(soundFileName)
            : .default
        
        let id = Alarm.ID()
        let stopIntent = AlarmScreenIntent()
        // Intent restored to original state (no parameters)
        // stopIntent.alarmID = id.uuidString

        let schedule: Alarm.Schedule
        let scheduledDate: Date
        if let days = days, !days.isEmpty {
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            guard let hour = components.hour, let minute = components.minute else {
                throw NSError(domain: "AlarmKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid date components"])
            }
            
            let time = Alarm.Schedule.Relative.Time(hour: hour, minute: minute)
            // Schedule for specified days
            schedule = .relative(.init(time: time, repeats: .weekly(days)))
            scheduledDate = date
        } else {
            // One-time alarm
            // Check if the date is in the past
            if date < Date() {
                // If the time is in the past for today, schedule it for tomorrow
                // But if the user selected a specific date (e.g. from date picker), we might want to respect it
                // However, since we are using .fixed(date), it requires an exact date
                // If the user selected 5 minutes from now, 'date' should be correct
                // If the user picked a time earlier today, we should probably move it to tomorrow
                
                // Let's check if the difference is huge (like > 1 day in the past) or just "earlier today"
                // For "Start Now", we pass Date() + 10s, so it's always future
                
                // For non-repeating alarms set via picker (which just gives us time components merged with current date usually):
                // If it's earlier today, add 24 hours.
                // But wait, if the user explicitly picked "5 minutes from now", `date` will be `Date() + 300`.
                // If they picked "8:00 AM" and it is currently "10:00 AM", the date picker usually returns "Today at 8:00 AM".
                // In that case, we want tomorrow at 8:00 AM.
                
                if Calendar.current.isDateInToday(date) {
                    if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date) {
                        schedule = .fixed(nextDay)
                        scheduledDate = nextDay
                        DebugLogger.log("[AlarmKitManager] Adjusted past time today to tomorrow: \(nextDay)")
                    } else {
                        schedule = .fixed(date)
                        scheduledDate = date
                    }
                } else {
                    schedule = .fixed(date)
                    scheduledDate = date
                }
            } else {
                schedule = .fixed(date)
                scheduledDate = date
            }
        }

        let configuration: AlarmManager.AlarmConfiguration<AlarmData> = .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: nil,
            sound: alertSound
        )
        
        // Create the alarm
        let alarm = try await alarmManager.schedule(
            id: id,
            configuration: configuration
        )
        currentAlarm = alarm
        
        DebugLogger.log("[AlarmKitManager] Personalized alarm scheduled for \(scheduledDate) (days: \(String(describing: days))) kind=\(kind.logLabel)")
        logAlarmSnapshot(context: "after schedule")
        return alarm.id.uuidString
    }

    func scheduleImmediateAlarm(name: String, goal: String, delaySeconds: Int = 10) async throws {
        let fireDate = Date().addingTimeInterval(TimeInterval(delaySeconds))
        _ = try await schedulePersonalizedAlarm(at: fireDate, name: name, goal: goal, kind: .scheduled, clearExisting: false)
        DebugLogger.log("[AlarmKitManager] Immediate alarm scheduled to fire in \(delaySeconds) seconds")
    }

    func scheduleFixedAlarm(at date: Date, name: String, goal: String, kind: AlarmKind = .scheduled) async throws -> String {
        try await schedulePersonalizedAlarm(at: date, name: name, goal: goal, kind: kind, days: nil, clearExisting: false)
    }
    
    // MARK: - Audio File Management
    
    private func getPersonalWakeMessageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let soundsPath = documentsPath.appendingPathComponent("Library/Sounds")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: soundsPath, withIntermediateDirectories: true)
        
        return soundsPath.appendingPathComponent("personal-wake-message.m4a")
    }
    
    func generatePersonalWakeMessage(name: String, goal: String) async throws {
        // Use consolidated generation logic for consistency
        // This ensures even if called explicitly, it generates the correct consolidated format
        let _ = try await TTSAudioManager.shared.generateConsolidatedWakeMessage(userGoal: goal, personality: "motivational coach")
        DebugLogger.log("[AlarmKitManager] Personal wake message generated (consolidated) and saved")
    }
    
    // MARK: - Contextual Message Generation
    
    func generateContextualMessage(name: String, goal: String) async -> String {
        let currentTime = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        let weather = await getCurrentWeather()
        
        let contextualMessage = "Good morning \(name)! It's \(currentTime) and \(weather). Time to wake up and \(goal). Let's prove you're conscious and ready to succeed!"
        
        // Store the contextual message for the app to use
        UserDefaults.standard.set(contextualMessage, forKey: "contextual_wake_message")
        
        return contextualMessage
    }
    
    private func getCurrentWeather() async -> String {
        return await WeatherService.shared.getCurrentWeather()
    }
    
    // MARK: - Alarm Management
    
    func cancelCurrentAlarm() async throws {
        if let alarm = currentAlarm {
            try alarmManager.cancel(id: alarm.id)
            currentAlarm = nil
            DebugLogger.log("[AlarmKitManager] Current alarm cancelled")
        }
    }
    
    func stopAlarm(idString: String) async {
        guard let uuid = UUID(uuidString: idString) else { return }
        do {
            try alarmManager.stop(id: uuid)
            DebugLogger.log("[AlarmKitManager] Stopped alarm: \(uuid)")
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to stop alarm: \(error)")
        }
    }
    
    func stopAnyAlertingAlarm() async {
        do {
            let alarms = try alarmManager.alarms
            for alarm in alarms where alarm.state == .alerting {
                try alarmManager.stop(id: alarm.id)
                DebugLogger.log("[AlarmKitManager] Stopped alerting alarm: \(alarm.id)")
            }
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to stop any alerting alarm: \(error)")
        }
    }
    
    func isAlarmScheduled() -> Bool {
        return currentAlarm != nil
    }

    // MARK: - Diagnostics

    func logAlarmSnapshot(context: String) {
        do {
            let alarms = try alarmManager.alarms
            guard !alarms.isEmpty else {
                DebugLogger.log("[AlarmKitManager] \(context) alarms=0")
                return
            }

            let now = Date()
            for alarm in alarms {
                let trigger = nextTriggerDate(for: alarm, now: now)
                DebugLogger.log("[AlarmKitManager] \(context) id=\(alarm.id) state=\(alarm.state) trigger=\(String(describing: trigger)) schedule=\(String(describing: alarm.schedule))")
            }
        } catch {
            DebugLogger.log("[AlarmKitManager] \(context) failed to fetch alarms: \(error)")
        }
    }

    func hasAlarm(idString: String) -> Bool {
        guard let uuid = UUID(uuidString: idString) else { return false }
        do {
            let alarms = try alarmManager.alarms
            return alarms.contains { $0.id == uuid }
        } catch {
            DebugLogger.log("[AlarmKitManager] Failed to check alarm presence for id=\(idString): \(error)")
            return false
        }
    }
    
    // MARK: - Alarm Event Handling
    
    func handleAlarmFired(_ alarm: Alarm) {
        DebugLogger.log("[AlarmKitManager] Alarm fired: \(alarm)")
        
        // Post notification to trigger app launch
        NotificationCenter.default.post(
            name: .alarmFired,
            object: nil,
            userInfo: [
                "alarmId": alarm.id.uuidString
            ]
        )
    }
}
