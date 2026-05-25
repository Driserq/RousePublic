//
//  Talking_AlarmApp.swift
//  Talking_Alarm
//
//  Created by Jakub Szewczyk on 14/08/2025.
//

import SwiftUI

@main
struct Talking_AlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                DebugLogger.log("[App] App became active - checking for firing alarms...")
                Task {
                    // Force a check whenever we come to foreground
                    if #available(iOS 26.0, *) {
                        await AlarmKitManager.shared.checkForActiveAlarms()
                    }
                }
            }
        }
    }
}

