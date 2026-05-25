import Foundation
import Combine

final class AppState: ObservableObject {
	@Published var alarmDate: Date
	@Published var goalText: String
	@Published var isAlarmScheduled: Bool
    @Published var alarmDays: Set<Int>
    @Published var alarmSchedule: [Int: Date]

    @Published var nextAlarmOverride: Date?
    @Published var nextScheduledAlarmID: String?
    @Published var suppressedScheduleKey: String?
    @Published var suppressedScheduleDate: Date?
    @Published var dailyOverrideDate: Date?
    @Published var dailyOverrideTime: Date?
    @Published var lastScheduledDate: Date?

    @Published var napAlarmID: String?
    @Published var napAlarmDate: Date?
    @Published var napDurationMinutes: Int

	init(
		initialAlarmDate: Date = LocalStore.loadAlarmDate() ?? Date().addingTimeInterval(60 * 60 * 8),
		initialGoalText: String = LocalStore.loadGoalText() ?? "",
        initialAlarmDays: Set<Int> = LocalStore.loadAlarmDays() ?? [],
		initialAlarmSchedule: [Int: Date] = LocalStore.loadAlarmSchedule(),
		initialNextAlarmOverride: Date? = LocalStore.loadNextAlarmOverride(),
		initialNextScheduledAlarmID: String? = LocalStore.loadNextScheduledAlarmID(),
		initialSuppressedScheduleKey: String? = LocalStore.loadSuppressedScheduleKey(),
		initialSuppressedScheduleDate: Date? = LocalStore.loadSuppressedScheduleDate(),
		initialDailyOverrideDate: Date? = LocalStore.loadDailyOverrideDate(),
		initialDailyOverrideTime: Date? = LocalStore.loadDailyOverrideTime(),
		initialLastScheduledDate: Date? = LocalStore.loadLastScheduledDate(),
        initialNapAlarmID: String? = LocalStore.loadNapAlarmID(),
        initialNapAlarmDate: Date? = LocalStore.loadNapAlarmDate(),
        initialNapDurationMinutes: Int = LocalStore.loadNapDurationMinutes() ?? 20
	) {
		self.alarmDate = initialAlarmDate
		self.goalText = initialGoalText
		self.isAlarmScheduled = false
        self.alarmDays = initialAlarmDays
        self.alarmSchedule = initialAlarmSchedule
		self.nextAlarmOverride = initialNextAlarmOverride
		self.nextScheduledAlarmID = initialNextScheduledAlarmID
		self.suppressedScheduleKey = initialSuppressedScheduleKey
		self.suppressedScheduleDate = initialSuppressedScheduleDate
		self.dailyOverrideDate = initialDailyOverrideDate
		self.dailyOverrideTime = initialDailyOverrideTime
		self.lastScheduledDate = initialLastScheduledDate

        self.napAlarmID = initialNapAlarmID
        self.napAlarmDate = initialNapAlarmDate
        self.napDurationMinutes = initialNapDurationMinutes
	}

	func persist() {
		LocalStore.saveAlarmDate(alarmDate)
		LocalStore.saveGoalText(goalText)
        LocalStore.saveAlarmDays(alarmDays)
        LocalStore.saveAlarmSchedule(alarmSchedule)
		LocalStore.saveNextAlarmOverride(nextAlarmOverride)
		LocalStore.saveNextScheduledAlarmID(nextScheduledAlarmID)
		LocalStore.saveSuppressedScheduleKey(suppressedScheduleKey)
		LocalStore.saveSuppressedScheduleDate(suppressedScheduleDate)
		LocalStore.saveDailyOverrideDate(dailyOverrideDate)
		LocalStore.saveDailyOverrideTime(dailyOverrideTime)
		LocalStore.saveLastScheduledDate(lastScheduledDate)

        LocalStore.saveNapAlarmID(napAlarmID)
        LocalStore.saveNapAlarmDate(napAlarmDate)
        LocalStore.saveNapDurationMinutes(napDurationMinutes)
	}

    func resetToDefaults() {
        alarmDate = Date().addingTimeInterval(60 * 60 * 8)
        goalText = ""
        isAlarmScheduled = false
        alarmDays = []
        alarmSchedule = [:]
        nextAlarmOverride = nil
        nextScheduledAlarmID = nil
        suppressedScheduleKey = nil
        suppressedScheduleDate = nil
        dailyOverrideDate = nil
        dailyOverrideTime = nil
        lastScheduledDate = nil
        napAlarmID = nil
        napAlarmDate = nil
        napDurationMinutes = 20

        persist()
    }
}


