import Foundation

enum AlarmKind: String, Codable {
    case scheduled
    case nap

    var logLabel: String {
        switch self {
        case .scheduled:
            return "WakeAlarm"
        case .nap:
            return "NapAlarm"
        }
    }
}
