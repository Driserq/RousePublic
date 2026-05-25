import Foundation
import AlarmKit

@MainActor
final class NextAlarmScheduler {
    enum Reason {
        case scheduleChanged
        case overrideChanged
        case alarmFiredChain
        case appLaunched
        case onboardingCompleted
        case foregroundCheck
    }

    private let appState: AppState

    private static var inFlightTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    func rescheduleNextScheduled(reason: Reason) async {
        guard #available(iOS 26.0, *) else { return }

        Self.inFlightTask?.cancel()
        let task = Task { @MainActor in
            await self.runReschedule(reason: reason)
        }
        Self.inFlightTask = task
        await task.value
    }

    static func computeNextDate(appState: AppState, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        
        var normalizedOverride: Date?
        if let overrideDate = appState.nextAlarmOverride {
            if overrideDate <= now {
                normalizedOverride = TimeUtils.getNextOccurrence(from: overrideDate, repeatingDays: [])
            } else {
                normalizedOverride = overrideDate
            }
        }

        if let overrideDate = normalizedOverride {
            return TimeUtils.nextOccurrenceFromTimeOnly(overrideDate, now: now)
        }

        if let overrideDate = appState.dailyOverrideDate,
           calendar.isDate(overrideDate, inSameDayAs: now),
           let overrideTime = appState.dailyOverrideTime,
           let candidate = TimeUtils.nextOccurrenceFromTimeOnly(overrideTime, now: now) {
            return candidate
        }

        if !appState.alarmSchedule.isEmpty {
            var best: Date?
            for (weekday, time) in appState.alarmSchedule {
                guard let key = TimeUtils.scheduleKey(weekday: weekday, time: time),
                      let candidate = TimeUtils.nextOccurrence(for: weekday, time: time, now: now) else {
                    continue
                }

                if let suppressedKey = appState.suppressedScheduleKey,
                   let suppressedDate = appState.suppressedScheduleDate,
                   key == suppressedKey,
                   calendar.isDate(candidate, inSameDayAs: suppressedDate),
                   abs(candidate.timeIntervalSince(suppressedDate)) < 1 {
                    continue
                }

                if best == nil || candidate < best! {
                    best = candidate
                }
            }
            return best
        }

        return TimeUtils.nextOccurrenceFromTimeOnly(appState.alarmDate, now: now)
    }

    private func runReschedule(reason: Reason) async {
        guard #available(iOS 26.0, *) else { return }

        func clearSuppression() {
            appState.suppressedScheduleKey = nil
            appState.suppressedScheduleDate = nil
            appState.persist()
        }

        if let suppressedDate = appState.suppressedScheduleDate, suppressedDate <= Date() {
            clearSuppression()
        }

        let now = Date()
        let nextDate = Self.computeNextDate(appState: appState, now: now)

        /*
        // PREVIOUS LOGIC (commented for easy revert)
        let nextDate = normalizedOverride
            ?? TimeUtils.getNextOccurrence(from: appState.alarmSchedule)
            ?? TimeUtils.getNextOccurrence(from: appState.alarmDate, repeatingDays: appState.alarmDays)
        */

        guard let nextDate else {
            await cancelCurrentScheduledAlarm()
            return
        }

        let hasStoredAlarm = hasStoredScheduledAlarm()
        DebugLogger.log("[NextAlarmScheduler] reschedule reason=\(reason) nextDate=\(nextDate) lastScheduled=\(String(describing: appState.lastScheduledDate)) storedId=\(appState.nextScheduledAlarmID ?? "nil") hasStoredAlarm=\(hasStoredAlarm)")

        if let lastScheduled = appState.lastScheduledDate,
           abs(lastScheduled.timeIntervalSince(nextDate)) < 1,
           hasStoredAlarm {
            return
        }

        await cancelCurrentScheduledAlarm()
        let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
        let goal = UserDefaults.standard.string(forKey: "user_goal") ?? (appState.goalText.isEmpty ? "Wake up" : appState.goalText)

        do {
            let authorized = await AlarmKitManager.shared.requestAuthorization()
            guard authorized else { return }

            let id = try await AlarmKitManager.shared.scheduleFixedAlarm(at: nextDate, name: name, goal: goal)
            appState.nextScheduledAlarmID = id
            appState.lastScheduledDate = nextDate
            appState.persist()
            AlarmKitManager.shared.logAlarmSnapshot(context: "after reschedule \(reason)")
        } catch {
            DebugLogger.log("[NextAlarmScheduler] Failed to reschedule next alarm (reason=\(reason)): \(error)")
        }
    }

    func verifyScheduledAlarmPresence(reason: Reason) async {
        guard #available(iOS 26.0, *) else { return }

        let now = Date()
        let nextDate = Self.computeNextDate(appState: appState, now: now)
        guard let nextDate else {
            DebugLogger.log("[NextAlarmScheduler] verify reason=\(reason) no nextDate; cancelling")
            await cancelCurrentScheduledAlarm()
            return
        }

        if hasStoredScheduledAlarm() {
            DebugLogger.log("[NextAlarmScheduler] verify ok reason=\(reason) nextDate=\(nextDate) id=\(appState.nextScheduledAlarmID ?? "nil")")
            return
        }

        DebugLogger.log("[NextAlarmScheduler] verify missing alarm; rescheduling reason=\(reason) nextDate=\(nextDate) id=\(appState.nextScheduledAlarmID ?? "nil")")
        AlarmKitManager.shared.logAlarmSnapshot(context: "verify missing pre-reschedule")
        await rescheduleNextScheduled(reason: reason)
    }

    private func cancelCurrentScheduledAlarm() async {
        guard #available(iOS 26.0, *) else { return }

        if let id = appState.nextScheduledAlarmID {
            try? await AlarmKitManager.shared.cancelAlarm(idString: id)
        } else if let closestId = await AlarmKitManager.shared.findClosestNonRetryAlarmId() {
            try? await AlarmKitManager.shared.cancelAlarm(idString: closestId)
        }

        appState.nextScheduledAlarmID = nil
        appState.lastScheduledDate = nil
        appState.persist()
    }

    private func hasStoredScheduledAlarm() -> Bool {
        guard let id = appState.nextScheduledAlarmID else { return false }
        do {
            let alarms = try AlarmManager.shared.alarms
            return alarms.contains { $0.id.uuidString == id }
        } catch {
            DebugLogger.log("[NextAlarmScheduler] Failed to fetch alarms for presence check: \(error)")
            return false
        }
    }
}
