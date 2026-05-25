import Foundation

enum TimeUtils {
	static func secondsUntil(_ date: Date, from now: Date = Date()) -> TimeInterval {
		max(0, date.timeIntervalSince(now))
	}

	static func formattedCountdown(until target: Date, now: Date = Date()) -> String {
		let interval = max(0, Int(target.timeIntervalSince(now)))
		let hours = interval / 3600
		let minutes = (interval % 3600) / 60
		let seconds = interval % 60
		if hours > 0 {
			return String(format: "%dh %dm %ds", hours, minutes, seconds)
		} else if minutes > 0 {
			return String(format: "%dm %ds", minutes, seconds)
		} else {
			return String(format: "%ds", seconds)
		}
	}

    static func getNextOccurrence(from date: Date, repeatingDays: Set<Int>) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else { return nil }
        
        // If no days selected, assume one-time alarm
        if repeatingDays.isEmpty {
            // Create date for today with the alarm time
            guard let todayAlarm = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
            
            // If it's in the past, move to tomorrow
            if todayAlarm <= now {
                return calendar.date(byAdding: .day, value: 1, to: todayAlarm)
            } else {
                return todayAlarm
            }
        }
        
        // Find the next matching day
        // Day mapping: 1=Sun, ..., 7=Sat (matches Calendar.component(.weekday))
        
        // Check repeat schedule for the next 7 days
        for i in 0...7 {
            guard let checkDate = calendar.date(byAdding: .day, value: i, to: now),
                  let potentialAlarm = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: checkDate) else { continue }
            
            let weekday = calendar.component(.weekday, from: checkDate)
            
            // If this weekday is in our list
            if repeatingDays.contains(weekday) {
                // If it's today, it must be in the future
                if i == 0 && potentialAlarm <= now {
                    continue
                }
                return potentialAlarm
            }
        }
        
        return nil
    }
    
    static func getNextOccurrence(from schedule: [Int: Date]) -> Date? {
        guard !schedule.isEmpty else { return nil }
        let calendar = Calendar.current
        let now = Date()
        
        // Check next 7 days
        for i in 0...7 {
            guard let checkDate = calendar.date(byAdding: .day, value: i, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if let timeDate = schedule[weekday] {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                guard let hour = timeComponents.hour, let minute = timeComponents.minute,
                      let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: checkDate) else { continue }
                
                if i == 0 && candidate <= now {
                    continue
                }
                
                return candidate
            }
        }
        return nil
    }

    // TEST MODE: Next occurrence using only hour/minute from date (ignores stored day).
    static func nextOccurrenceFromTimeOnly(_ date: Date, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }

        guard let todayTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }

        if todayTime <= now {
            return calendar.date(byAdding: .day, value: 1, to: todayTime)
        }

        return todayTime
    }
    
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func scheduleKey(weekday: Int, time: Date, calendar: Calendar = .current) -> String? {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return String(format: "%d:%02d:%02d", weekday, hour, minute)
    }

    static func parseScheduleKey(_ key: String) -> (weekday: Int, hour: Int, minute: Int)? {
        let parts = key.split(separator: ":")
        guard parts.count == 3,
              let weekday = Int(parts[0]),
              let hour = Int(parts[1]),
              let minute = Int(parts[2]) else {
            return nil
        }
        return (weekday, hour, minute)
    }

    static func nextOccurrence(for weekday: Int, time: Date, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else { return nil }

        for i in 0...7 {
            guard let checkDate = calendar.date(byAdding: .day, value: i, to: now),
                  calendar.component(.weekday, from: checkDate) == weekday,
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: checkDate) else {
                continue
            }

            if i == 0 && candidate <= now {
                continue
            }

            return candidate
        }

        return nil
    }

    static func nextScheduleEntry(from schedule: [Int: Date], now: Date = Date()) -> (date: Date, key: String)? {
        var best: (date: Date, key: String)?
        for (weekday, time) in schedule {
            guard let key = scheduleKey(weekday: weekday, time: time),
                  let candidate = nextOccurrence(for: weekday, time: time, now: now) else {
                continue
            }

            if best == nil || candidate < best!.date {
                best = (candidate, key)
            }
        }

        return best
    }

    static func nextAlarmInfo(scheduledDate: Date?, napDate: Date?, now: Date = Date()) -> (date: Date, kind: AlarmKind)? {
        let validScheduled = scheduledDate.flatMap { $0 > now ? $0 : nil }
        let validNap = napDate.flatMap { $0 > now ? $0 : nil }

        switch (validScheduled, validNap) {
        case (nil, nil):
            return nil
        case (let scheduled?, nil):
            return (scheduled, .scheduled)
        case (nil, let nap?):
            return (nap, .nap)
        case (let scheduled?, let nap?):
            if nap < scheduled {
                return (nap, .nap)
            }
            return (scheduled, .scheduled)
        }
    }
}


