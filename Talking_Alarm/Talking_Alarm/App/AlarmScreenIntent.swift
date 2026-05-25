import AppIntents
import Foundation
import AlarmKit

/// App Intent invoked from AlarmKit stop/secondary button to foreground the app and show the in-app alarm screen.
@available(iOS 16.0, *)
struct AlarmScreenIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open Alarm Screen"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // No-op: alarm routing relies on AlarmKitManager.checkForActiveAlarms() / pendingAlarmId bridge
        // so we always have a real alarmId.
        return .result()
    }
}
