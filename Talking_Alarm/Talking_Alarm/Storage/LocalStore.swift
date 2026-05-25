import Foundation

enum LocalStoreKeys {
	static let alarmDate = "alarmDate"
	static let goalText = "goalText"
    static let alarmDays = "alarmDays"
    static let alarmSchedule = "alarmSchedule"
    static let is24HourMode = "is24HourMode"

    static let nextAlarmOverride = "nextAlarmOverride"
    static let nextScheduledAlarmID = "nextScheduledAlarmID"

    static let suppressedScheduleKey = "suppressedScheduleKey"
    static let suppressedScheduleDate = "suppressedScheduleDate"

    static let dailyOverrideDate = "dailyOverrideDate"
    static let dailyOverrideTime = "dailyOverrideTime"
    static let lastScheduledDate = "lastScheduledDate"

    static let provisionalRetryAlarmIDs = "provisionalRetryAlarmIDs"

    static let currentRetryAlarmID = "currentRetryAlarmID"

    static let retryAttemptCount = "retryAttemptCount"

    static let pendingChallengeText = "pendingChallengeText"

    static let pendingChallengeAudioPath = "pendingChallengeAudioPath"

    static let napAlarmID = "napAlarmID"
    static let napAlarmDate = "napAlarmDate"
    static let napDurationMinutes = "napDurationMinutes"
    
    static let volumeGateRetryAlarmID = "volumeGateRetryAlarmID"
}

enum LocalStore {
	static func saveAlarmDate(_ date: Date) {
		UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.alarmDate)
	}

	static func loadAlarmDate() -> Date? {
		let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.alarmDate)
		guard interval > 0 else { return nil }
		return Date(timeIntervalSince1970: interval)
	}

	static func saveGoalText(_ text: String) {
		UserDefaults.standard.set(text, forKey: LocalStoreKeys.goalText)
	}

	static func loadGoalText() -> String? {
		UserDefaults.standard.string(forKey: LocalStoreKeys.goalText)
	}
    
    static func saveAlarmDays(_ days: Set<Int>) {
        UserDefaults.standard.set(Array(days), forKey: LocalStoreKeys.alarmDays)
    }
    
    static func loadAlarmDays() -> Set<Int>? {
        guard let array = UserDefaults.standard.array(forKey: LocalStoreKeys.alarmDays) as? [Int] else {
            return nil
        }
        return Set(array)
    }
    
    static func saveAlarmSchedule(_ schedule: [Int: Date]) {
        // Convert Date to TimeInterval (Double) for storage
        let storageDict = schedule.mapValues { $0.timeIntervalSince1970 }
        // Convert keys to String because UserDefaults dictionaries must have String keys
        let jsonDict = Dictionary(uniqueKeysWithValues: storageDict.map { (String($0.key), $0.value) })
        UserDefaults.standard.set(jsonDict, forKey: LocalStoreKeys.alarmSchedule)
    }
    
    static func loadAlarmSchedule() -> [Int: Date] {
        guard let jsonDict = UserDefaults.standard.dictionary(forKey: LocalStoreKeys.alarmSchedule) as? [String: Double] else {
            return [:]
        }
        
        var schedule: [Int: Date] = [:]
        for (key, value) in jsonDict {
            if let dayInt = Int(key) {
                schedule[dayInt] = Date(timeIntervalSince1970: value)
            }
        }
        return schedule
    }

    static func saveNextAlarmOverride(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.nextAlarmOverride)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.nextAlarmOverride)
        }
    }

    static func loadNextAlarmOverride() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.nextAlarmOverride)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveNextScheduledAlarmID(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: LocalStoreKeys.nextScheduledAlarmID)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.nextScheduledAlarmID)
        }
    }

    static func loadNextScheduledAlarmID() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.nextScheduledAlarmID)
    }

    static func saveSuppressedScheduleKey(_ key: String?) {
        if let key {
            UserDefaults.standard.set(key, forKey: LocalStoreKeys.suppressedScheduleKey)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.suppressedScheduleKey)
        }
    }

    static func loadSuppressedScheduleKey() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.suppressedScheduleKey)
    }

    static func saveSuppressedScheduleDate(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.suppressedScheduleDate)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.suppressedScheduleDate)
        }
    }

    static func loadSuppressedScheduleDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.suppressedScheduleDate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveDailyOverrideDate(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.dailyOverrideDate)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.dailyOverrideDate)
        }
    }

    static func loadDailyOverrideDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.dailyOverrideDate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveDailyOverrideTime(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.dailyOverrideTime)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.dailyOverrideTime)
        }
    }

    static func loadDailyOverrideTime() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.dailyOverrideTime)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveLastScheduledDate(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.lastScheduledDate)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.lastScheduledDate)
        }
    }

    static func loadLastScheduledDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.lastScheduledDate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveProvisionalRetryAlarmIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: LocalStoreKeys.provisionalRetryAlarmIDs)
    }

    static func loadProvisionalRetryAlarmIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: LocalStoreKeys.provisionalRetryAlarmIDs) ?? []
    }

    static func addProvisionalRetryAlarmID(_ id: String) {
        var ids = loadProvisionalRetryAlarmIDs()
        guard ids.contains(id) == false else { return }
        ids.append(id)
        saveProvisionalRetryAlarmIDs(ids)
    }

    static func removeProvisionalRetryAlarmID(_ id: String) {
        let ids = loadProvisionalRetryAlarmIDs().filter { $0 != id }
        saveProvisionalRetryAlarmIDs(ids)
    }

    static func clearProvisionalRetryAlarmIDs() {
        UserDefaults.standard.removeObject(forKey: LocalStoreKeys.provisionalRetryAlarmIDs)
    }

    static func saveCurrentRetryAlarmID(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: LocalStoreKeys.currentRetryAlarmID)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.currentRetryAlarmID)
        }
    }

    static func loadCurrentRetryAlarmID() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.currentRetryAlarmID)
    }

    static func saveRetryAttemptCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: LocalStoreKeys.retryAttemptCount)
    }

    static func loadRetryAttemptCount() -> Int {
        UserDefaults.standard.integer(forKey: LocalStoreKeys.retryAttemptCount)
    }

    static func savePendingChallengeText(_ text: String?) {
        if let text, !text.isEmpty {
            UserDefaults.standard.set(text, forKey: LocalStoreKeys.pendingChallengeText)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.pendingChallengeText)
        }
    }

    static func loadPendingChallengeText() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.pendingChallengeText)
    }

    static func savePendingChallengeAudioPath(_ path: String?) {
        if let path, !path.isEmpty {
            UserDefaults.standard.set(path, forKey: LocalStoreKeys.pendingChallengeAudioPath)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.pendingChallengeAudioPath)
        }
    }

    static func loadPendingChallengeAudioPath() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.pendingChallengeAudioPath)
    }

    static func saveNapAlarmID(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: LocalStoreKeys.napAlarmID)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.napAlarmID)
        }
    }

    static func loadNapAlarmID() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.napAlarmID)
    }

    static func saveNapAlarmDate(_ date: Date?) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalStoreKeys.napAlarmDate)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.napAlarmDate)
        }
    }

    static func loadNapAlarmDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalStoreKeys.napAlarmDate)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func saveNapDurationMinutes(_ minutes: Int?) {
        if let minutes {
            UserDefaults.standard.set(minutes, forKey: LocalStoreKeys.napDurationMinutes)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.napDurationMinutes)
        }
    }

    static func loadNapDurationMinutes() -> Int? {
        let minutes = UserDefaults.standard.integer(forKey: LocalStoreKeys.napDurationMinutes)
        return minutes > 0 ? minutes : nil
    }
    
    // MARK: - Volume Gate Retry
    
    /// Saves the ID of a pending volume-gate retry alarm.
    ///
    /// This is tracked separately from `currentRetryAlarmID` to avoid conflicts
    /// between volume-gate retries and conversation retries.
    ///
    /// **Validates: Requirements 5.8**
    static func saveVolumeGateRetryAlarmID(_ id: String?) {
        if let id {
            UserDefaults.standard.set(id, forKey: LocalStoreKeys.volumeGateRetryAlarmID)
        } else {
            UserDefaults.standard.removeObject(forKey: LocalStoreKeys.volumeGateRetryAlarmID)
        }
    }
    
    /// Loads the ID of a pending volume-gate retry alarm.
    ///
    /// **Validates: Requirements 5.8**
    static func loadVolumeGateRetryAlarmID() -> String? {
        UserDefaults.standard.string(forKey: LocalStoreKeys.volumeGateRetryAlarmID)
    }

    static func resetAll() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
    }
}


