import Foundation
import ActivityKit

// MARK: - Live Activity Manager

class EscalatingAlarmActivityManager: ObservableObject {
    static let shared = EscalatingAlarmActivityManager()
    
    private init() {}
    
    /// Start a Live Activity for escalating alarms
    func startLiveActivity(name: String, goal: String) async -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            DebugLogger.log("[EscalatingAlarmActivityManager] Live Activities not enabled")
            return nil
        }
        
        let attributes = EscalatingAlarmActivityAttributes(name: name, goal: goal)
        let initialContentState = EscalatingAlarmActivityAttributes.ContentState(
            currentAttempt: 1,
            totalAttempts: 4,
            isActive: true,
            timeRemaining: nil
        )
        
        do {
            let activity = try Activity<EscalatingAlarmActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            
            DebugLogger.log("[EscalatingAlarmActivityManager] Live Activity started: \(activity.id)")
            return activity.id
        } catch {
            DebugLogger.log("[EscalatingAlarmActivityManager] Failed to start Live Activity: \(error)")
            return nil
        }
    }
    
    /// Update the Live Activity with current attempt
    func updateLiveActivity(activityId: String, currentAttempt: Int, timeRemaining: TimeInterval? = nil) async {
        guard let activity = Activity<EscalatingAlarmActivityAttributes>.activities.first(where: { $0.id == activityId }) else {
            DebugLogger.log("[EscalatingAlarmActivityManager] Live Activity not found: \(activityId)")
            return
        }
        
        let updatedContentState = EscalatingAlarmActivityAttributes.ContentState(
            currentAttempt: currentAttempt,
            totalAttempts: 4,
            isActive: true,
            timeRemaining: timeRemaining
        )
        
        // Activity.update() does not throw - it's an async non-throwing method
        await activity.update(
            .init(state: updatedContentState, staleDate: nil)
        )
        DebugLogger.log("[EscalatingAlarmActivityManager] Updated Live Activity attempt \(currentAttempt)")
    }
    
    /// End the Live Activity
    func endLiveActivity(activityId: String) async {
        guard let activity = Activity<EscalatingAlarmActivityAttributes>.activities.first(where: { $0.id == activityId }) else {
            DebugLogger.log("[EscalatingAlarmActivityManager] Live Activity not found: \(activityId)")
            return
        }
        
        let finalContentState = EscalatingAlarmActivityAttributes.ContentState(
            currentAttempt: 4,
            totalAttempts: 4,
            isActive: false,
            timeRemaining: nil
        )
        
        // Activity.end() does not throw - it's an async non-throwing method
        await activity.end(
            .init(state: finalContentState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        DebugLogger.log("[EscalatingAlarmActivityManager] Live Activity ended")
    }
    
    /// End all Live Activities
    func endAllLiveActivities() async {
        let activities = Activity<EscalatingAlarmActivityAttributes>.activities
        for activity in activities {
            await endLiveActivity(activityId: activity.id)
        }
    }
}

