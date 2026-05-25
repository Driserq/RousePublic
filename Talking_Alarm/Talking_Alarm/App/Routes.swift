import SwiftUI
import AVFoundation
import AlarmKit
import UIKit

struct RootView: View {
    @StateObject var appState = AppState()
    @StateObject private var conversationManager: ConversationManager
    @State private var showOnboarding = !OnboardingManager.isOnboardingCompleted()
    @AppStorage("ai_consent_given") private var hasAIConsent = false
    
    init() {
        let stt = AppleSpeechService()
        let manager = ConversationManager(backend: .shared, tts: TextToSpeech(elevenLabs: ElevenLabsService()), stt: stt)
        self._conversationManager = StateObject(wrappedValue: manager)
    }
    
    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                    .animation(.easeInOut(duration: 0.5), value: showOnboarding)
                    .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showOnboarding = false
                        }
                        loadUserDataFromOnboarding()
                    }
            } else if !hasAIConsent {
                ConsentRequiredView(
                    onEnableAI: {
                        hasAIConsent = true
                    },
                    onDeleteAccount: {
                        Task { @MainActor in
                            deleteLocalAccountData()
                        }
                    }
                )
            } else {
                StageManagerView(appState: appState, conversationManager: conversationManager)
                    .transition(.opacity)
            }
        }
    }
        
    func loadUserDataFromOnboarding() {
        if let userData = OnboardingManager.loadUserData() {
            appState.goalText = userData.goal
            appState.alarmDate = userData.alarmTime
            
            // Load the days selected during onboarding
            let savedDays = LocalStore.loadAlarmDays() ?? Set<Int>()
            
            // Build the schedule from the selected days and time
            var schedule: [Int: Date] = [:]
            if savedDays.isEmpty {
                // No days selected - schedule as a one-time alarm for the next occurrence
                // Don't add to schedule, just set the override
                appState.nextAlarmOverride = userData.alarmTime
            } else {
                // Days were selected - create recurring schedule
                for day in savedDays {
                    schedule[day] = userData.alarmTime
                }
            }
            appState.alarmSchedule = schedule
            appState.persist()
            
            // Actually schedule the alarm with AlarmKit
            Task { @MainActor in
                if #available(iOS 26.0, *) {
                    await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .onboardingCompleted)
                }
            }
        }
    }

    @MainActor
    private func deleteLocalAccountData() {
        LocalStore.resetAll()
        appState.resetToDefaults()
        showOnboarding = true
    }
}
