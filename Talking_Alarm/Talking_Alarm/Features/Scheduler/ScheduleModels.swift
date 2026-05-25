import SwiftUI

struct ScheduleGroup: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isActive: Bool
    var color: Color
    var time: Date
    var days: Set<Int> // 1=Sun, 7=Sat
    
    init(id: UUID = UUID(), name: String, isActive: Bool = true, color: Color = .blue, time: Date = Date(), days: Set<Int> = []) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.color = color
        self.time = time
        self.days = days
    }
    
    var summary: String {
        if days.isEmpty { return "No days set" }
        if days.count == 7 { return "Every day" }
        // Simple summary logic - can be expanded
        let sortedDays = days.sorted()
        let dayNames = sortedDays.map { dayIndexToString($0) }.joined(separator: ", ")
        return dayNames
    }
    
    private func dayIndexToString(_ day: Int) -> String {
        switch day {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return ""
        }
    }
}
