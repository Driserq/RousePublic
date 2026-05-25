import UIKit
import UserNotifications
import AVFoundation
import AlarmKit

// MARK: - AlarmKit Integration (Device Only)

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Set up notification categories for local testing
        setupNotificationCategories()
        
        // Handle notification launches (remote notification launch option deprecated in iOS 26)
        
        DebugLogger.log("[AppDelegate] App launched with alarm system")
        
        return true
    }
    
    private func setupNotificationCategories() {
        // Create notification category with actions
        let startAction = UNNotificationAction(
            identifier: "START_CONVERSATION",
            title: "Start Challenge",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "TALKING_ALARM",
            actions: [startAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        DebugLogger.log("[AppDelegate] Notification categories set up")
    }
    
    // MARK: - Enhanced Notification Handling
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // If escalating alarm and app is foreground, present and also trigger in-app playback to avoid 6s cutoff
        if let type = notification.request.content.userInfo["type"] as? String,
           type == "escalating_alarm" {
            DebugLogger.log("[AppDelegate] Escalating alarm received in foreground - presenting and triggering in-app playback")
            if let name = notification.request.content.userInfo["name"] as? String,
               let goal = notification.request.content.userInfo["goal"] as? String {
                var userInfo: [String: Any] = [
                    "name": name,
                    "goal": goal,
                    "type": "escalating_alarm"
                ]

                if let alarmId = notification.request.content.userInfo["alarmId"] as? String {
                    userInfo["alarmId"] = alarmId
                }

                NotificationCenter.default.post(name: .alarmFired, object: nil, userInfo: userInfo)
            }
            // Show banner + sound to ensure lock-screen/foreground behavior
            return [.banner, .sound]
        }
        
        // Regular notifications
        return [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.actionIdentifier
        
        switch identifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            if let name = response.notification.request.content.userInfo["name"] as? String,
               let goal = response.notification.request.content.userInfo["goal"] as? String {
                
                // CRITICAL: Stop the alarm explicitly if this is an AlarmKit event
                // This releases the audio session lock held by the system alarm sound
                if let alarmIdString = response.notification.request.content.userInfo["alarmId"] as? String,
                   let alarmId = UUID(uuidString: alarmIdString) {
                    if #available(iOS 26.0, *) {
                        Task {
                            DebugLogger.log("[AppDelegate] Stopping AlarmKit alarm explicitly: \(alarmId)")
                            // AlarmManager.stop(id:) is synchronous (throws, not async throws)
                            try? AlarmManager.shared.stop(id: alarmId)
                            // We don't wait here because the NotificationCenter post below will trigger the UI,
                            // and StageManager has its own 0.5s delay which acts as the "Yield" time.
                        }
                    }
                }
                
                // Check if this is an escalating alarm
                if let attempt = response.notification.request.content.userInfo["attempt"] as? Int,
                   let type = response.notification.request.content.userInfo["type"] as? String,
                   type == "escalating_alarm" {
                    
                    DebugLogger.log("[AppDelegate] User tapped escalating alarm attempt \(attempt) for \(name)")
                    
                    // Update Live Activity to show current attempt
                    EscalatingAlarmManager.shared.updateLiveActivityForAttempt(attempt)
                    
                    // Cancel remaining escalating alarms
                    EscalatingAlarmManager.shared.cancelRemainingAlarms(currentAttempt: attempt)
                    
                    var userInfo: [String: Any] = [
                        "name": name,
                        "goal": goal,
                        "type": "escalating_alarm",
                        "attempt": attempt
                    ]
                    if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                        userInfo["alarmId"] = alarmId
                    }
                    NotificationCenter.default.post(name: .alarmFired, object: nil, userInfo: userInfo)
                } else {
                    // Regular notification
                    DebugLogger.log("[AppDelegate] User tapped notification for \(name) with goal: \(goal)")

                    // Don't post alarmFired unless we have an AlarmKit alarmId.
                    if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                        NotificationCenter.default.post(
                            name: .alarmFired,
                            object: nil,
                            userInfo: [
                                "alarmId": alarmId,
                                "name": name,
                                "goal": goal,
                                "type": "immediate_alarm"
                            ]
                        )
                    }
                }
            }
            
        case "START_CONVERSATION":
            // Extract name and goal and start conversation
            if let name = response.notification.request.content.userInfo["name"] as? String,
               let goal = response.notification.request.content.userInfo["goal"] as? String {
                DebugLogger.log("[AppDelegate] User tapped 'Start Challenge' for \(name) with goal: \(goal)")

                if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                    NotificationCenter.default.post(
                        name: .alarmFired,
                        object: nil,
                        userInfo: [
                            "alarmId": alarmId,
                            "name": name,
                            "goal": goal,
                            "type": "scheduled_alarm"
                        ]
                    )
                }
            }
            
        default:
            DebugLogger.log("[AppDelegate] Unknown notification action: \(identifier)")
        }
    }
    
    // MARK: - Remote Notifications (Optional)
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DebugLogger.log("[AppDelegate] Remote notifications registered")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DebugLogger.log("[AppDelegate] Failed to register for remote notifications: \(error)")
    }
}


