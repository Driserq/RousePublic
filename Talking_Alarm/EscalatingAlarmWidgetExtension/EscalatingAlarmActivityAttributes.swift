import Foundation
import ActivityKit

struct EscalatingAlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentAttempt: Int
        var totalAttempts: Int
        var isActive: Bool
        var timeRemaining: TimeInterval?
        var lastUpdateTime: Date

        init(currentAttempt: Int = 1,
             totalAttempts: Int = 4,
             isActive: Bool = true,
             timeRemaining: TimeInterval? = nil) {
            self.currentAttempt = currentAttempt
            self.totalAttempts = totalAttempts
            self.isActive = isActive
            self.timeRemaining = timeRemaining
            self.lastUpdateTime = Date()
        }
    }

    var name: String
    var goal: String
    var alarmType: String

    init(name: String, goal: String, alarmType: String = "escalating_alarm") {
        self.name = name
        self.goal = goal
        self.alarmType = alarmType
    }
}
