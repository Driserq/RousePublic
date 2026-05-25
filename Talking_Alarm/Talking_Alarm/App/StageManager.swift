import SwiftUI

struct StageManagerView: View {
    @ObservedObject var appState: AppState
    @StateObject var conversationManager: ConversationManager

    @Environment(\.scenePhase) private var scenePhase
    
    // Navigation State
    @State private var offset: CGFloat = 0
    @State private var currentStage: Stage = .home
    
    // Zen Circle Logic
    @Namespace private var zenNamespace

    @State private var activeWakeAlarmID: String?
    @State private var activeWakeAlarmKind: AlarmKind = .scheduled
    @State private var wakeRetryCount: Int = 0
    @State private var isWakeSessionActive: Bool = false
    @State private var lastRetryScheduledAt: Date?
    @State private var scheduledRetryAlarmIDs: [String] = []
    
    // Volume Gate
    @State private var volumeGate = VolumeGateManager()

    private let maxRetryAttempts: Int = 15
    
    enum Stage {
        case scheduler
        case home
        case settings
        
        var offsetIndex: CGFloat {
            switch self {
            case .scheduler: return 1  // Scheduler is at -W, so we need offset +W to see it? No.
                                       // If we want to see Scheduler (left), we shift everything RIGHT (+W).
            case .home: return 0
            case .settings: return -1  // Settings is at +W, shift LEFT (-W) to see it.
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack(alignment: .leading) {
                // Background (Deep Space Blue)
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()
                
                // 1. LEFT DRAWER (Scheduler)
                SchedulerDrawer(appState: appState, onClose: {
                    withAnimation { currentStage = .home }
                })
                    .frame(width: width)
                    // Positioned at -Width
                    .offset(x: -width)
                    // Apply current Drag Offset
                    .offset(x: offset + (currentStage.offsetIndex * width))
                
                // 2. CENTER (Home)
                HomeView(
                    appState: appState,
                    conversationManager: conversationManager,
                    namespace: zenNamespace,
                    toScheduler: {
                        withAnimation { currentStage = .scheduler }
                    },
                    toSettings: { withAnimation { currentStage = .settings } }
                )
                .frame(width: width)
                // Positioned at 0
                .offset(x: 0)
                // Apply current Drag Offset
                .offset(x: offset + (currentStage.offsetIndex * width))
                // FADE OUT HOME WHEN ALARM ACTIVE
                .opacity(conversationManager.state != .idle ? 0 : 1)
                
                // 3. RIGHT DRAWER (Settings)
                SettingsDrawer(appState: appState, onClose: {
                    withAnimation { currentStage = .home }
                })
                    .frame(width: width)
                    // Positioned at +Width
                    .offset(x: width)
                    // Apply current Drag Offset
                    .offset(x: offset + (currentStage.offsetIndex * width))
                
                // 4. ALARM OVERLAY (Modal)
                if conversationManager.state != .idle {
                     AlarmOverlay(
                         manager: conversationManager,
                         namespace: zenNamespace
                     )
                     .zIndex(100)
                     .transition(.opacity.animation(.easeInOut))
                }
                
                // 5. VOLUME NAG OVERLAY (Above alarm overlay)
                if case .blocked = volumeGate.state {
                    VolumeNagOverlay(
                        volumeGate: volumeGate,
                        onDismiss: {
                            // This is called when volume crosses threshold
                            handleVolumeThresholdCrossed()
                        }
                    )
                    .zIndex(101)
                    .transition(.opacity.animation(.easeInOut))
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        self.offset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = width * 0.25
                        let dragAmount = value.translation.width
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if currentStage == .home {
                                if dragAmount > threshold {
                                    currentStage = .scheduler // Drag Right -> Go Left (Show Scheduler)
                                } else if dragAmount < -threshold {
                                    currentStage = .settings // Drag Left -> Go Right (Show Settings)
                                }
                            } else if currentStage == .scheduler {
                                if dragAmount < -threshold {
                                    currentStage = .home // Drag Left -> Go Back Home
                                }
                            } else if currentStage == .settings {
                                if dragAmount > threshold {
                                    currentStage = .home // Drag Right -> Go Back Home
                                }
                            }
                            self.offset = 0
                        }
                    }
            )
            .onReceive(NotificationCenter.default.publisher(for: .alarmFired)) { notification in
                DebugLogger.log("[StageManager] Alarm Fired Notification Received")
                Task {
                    if conversationManager.state != .idle {
                        DebugLogger.log("[StageManager] alarmFired while conversation active; stopping alarm silently")
                        if let alarmId = notification.userInfo?["alarmId"] as? String {
                            await AlarmKitManager.shared.stopAlarm(idString: alarmId)
                            try? await AlarmKitManager.shared.cancelAlarm(idString: alarmId)
                            if LocalStore.loadCurrentRetryAlarmID() == alarmId {
                                LocalStore.saveCurrentRetryAlarmID(nil)
                            }
                        }
                        return
                    }

                    if let alarmId = notification.userInfo?["alarmId"] as? String {
                        let alarmKind = resolveAlarmKind(alarmId: alarmId)
                        activeWakeAlarmKind = alarmKind
                        activeWakeAlarmID = alarmId
                        DebugLogger.log("[\(alarmKind.logLabel)] Alarm fired id=\(alarmId)")
                        
                        // Cancel any pending volume gate retry
                        await volumeGate.cancelPendingRetry()
                        
                        // Stop the alarm to release AlarmKit's audio session
                        await AlarmKitManager.shared.stopAlarm(idString: alarmId)
                        
                        // IMMEDIATELY show conversation overlay and start preloading message
                        conversationManager.beginWakeUI()
                        conversationManager.preloadMessage(goal: appState.goalText, alarmKind: alarmKind)
                        
                        // Brief delay for AlarmKit to release audio session
                        try? await Task.sleep(for: .milliseconds(200))
                        
                        // Configure audio session (includes forcing speaker output)
                        volumeGate.configureAudioSession()
                        
                        // Check volume - message is loading in parallel
                        let volumePasses = volumeGate.checkVolume()
                        
                        if !volumePasses {
                            // Volume too low - show nag overlay and start haptics
                            // Message continues loading in background
                            DebugLogger.log("[StageManager] Volume too low, showing volume nag overlay (message loading in background)")
                            
                            // Set up callback BEFORE starting blocking
                            volumeGate.onVolumeThresholdCrossed = {
                                Task { @MainActor in
                                    handleVolumeThresholdCrossed()
                                }
                            }
                            
                            volumeGate.startBlocking(alarmId: alarmId, alarmKind: alarmKind)
                            volumeGate.startHapticLoop()
                            return
                        }
                        
                        // Volume is OK - proceed with alarm flow (will use preloaded message)
                        await proceedWithAlarmFlow(alarmId: alarmId, alarmKind: alarmKind, notification: notification)
                    } else {
                        DebugLogger.log("[StageManager] Missing alarmId in alarmFired notification")
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Volume gate escape detection
                if case let .blocked(_, alarmKind) = volumeGate.state {
                    if newPhase == .background {
                        DebugLogger.log("[StageManager] User backgrounded app while volume gate active - scheduling retry")
                        Task { @MainActor in
                            volumeGate.stopHapticLoop()
                            volumeGate.stopBlocking()
                            _ = await volumeGate.scheduleVolumeGateRetry(alarmKind: alarmKind)
                        }
                        return
                    }
                }

                if newPhase == .active {
                    Task { @MainActor in
                        await NextAlarmScheduler(appState: appState).verifyScheduledAlarmPresence(reason: .foregroundCheck)
                    }
                }
                
                guard newPhase != .active else { return }
                guard isWakeSessionActive else { return }

                // If the user leaves the app without completing the conversation successfully,
                // schedule a retry alarm for +60s (max 5 attempts). This avoids snooze UI.
                guard activeWakeAlarmID != nil else { return }

                // If the user backgrounds mid-conversation, hard-reset the conversation so returning
                // doesn't resume a half-broken state.
                if newPhase == .background, conversationManager.state != .idle {
                    if case let .speaking(text) = conversationManager.state {
                        LocalStore.savePendingChallengeText(text)
                    }
                    conversationManager.cancelCurrentWork()
                    conversationManager.reset()
                }

                // If the app is backgrounded (user swiped up / minimized / lock), treat it as
                // abandonment and schedule a retry even if we were mid-playback.
                if newPhase != .background {
                    guard conversationManager.state == .idle else { return }
                }

                if case .done(let success) = conversationManager.state, success {
                    return
                }

                let attempts = LocalStore.loadRetryAttemptCount()
                guard attempts < maxRetryAttempts else { return }

                if let lastRetryScheduledAt, Date().timeIntervalSince(lastRetryScheduledAt) < 5 {
                    return
                }

                Task { @MainActor in
                    guard #available(iOS 26.0, *) else { return }

                    // Single-retry-alarm lock: if one exists, do not schedule another.
                    if LocalStore.loadCurrentRetryAlarmID() != nil {
                        return
                    }

                    let authorized = await AlarmKitManager.shared.requestAuthorization()
                    guard authorized else { return }

                    let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
                    let goal = UserDefaults.standard.string(forKey: "user_goal") ?? (appState.goalText.isEmpty ? "Wake up" : appState.goalText)

                    let retryDate = Date().addingTimeInterval(60)
                    if let id = try? await AlarmKitManager.shared.scheduleFixedAlarm(at: retryDate, name: name, goal: goal, kind: activeWakeAlarmKind) {
                        scheduledRetryAlarmIDs.append(id)
                        LocalStore.saveCurrentRetryAlarmID(id)
                        LocalStore.addProvisionalRetryAlarmID(id)
                        LocalStore.saveRetryAttemptCount(attempts + 1)
                        wakeRetryCount = attempts + 1
                    }
                    lastRetryScheduledAt = Date()
                    DebugLogger.log("[StageManager] Scheduled wake retry \(wakeRetryCount)/\(maxRetryAttempts) at \(retryDate) kind=\(activeWakeAlarmKind.logLabel)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                guard isWakeSessionActive else { return }
                guard activeWakeAlarmID != nil else { return }
                let attempts = LocalStore.loadRetryAttemptCount()
                guard attempts < maxRetryAttempts else { return }

                Task { @MainActor in
                    guard #available(iOS 26.0, *) else { return }
                    if LocalStore.loadCurrentRetryAlarmID() != nil { return }

                    let authorized = await AlarmKitManager.shared.requestAuthorization()
                    guard authorized else { return }

                    let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
                    let goal = UserDefaults.standard.string(forKey: "user_goal") ?? (appState.goalText.isEmpty ? "Wake up" : appState.goalText)

                    let retryDate = Date().addingTimeInterval(60)
                    if let id = try? await AlarmKitManager.shared.scheduleFixedAlarm(at: retryDate, name: name, goal: goal, kind: activeWakeAlarmKind) {
                        scheduledRetryAlarmIDs.append(id)
                        LocalStore.saveCurrentRetryAlarmID(id)
                        LocalStore.addProvisionalRetryAlarmID(id)
                        LocalStore.saveRetryAttemptCount(attempts + 1)
                        wakeRetryCount = attempts + 1
                        lastRetryScheduledAt = Date()
                        DebugLogger.log("[StageManager] Scheduled wake retry (terminate) \(wakeRetryCount)/\(maxRetryAttempts) at \(retryDate) kind=\(activeWakeAlarmKind.logLabel)")
                    }
                }
            }
            .onChange(of: conversationManager.state) { _, newState in
                guard case let .done(success) = newState else { return }

                Task { @MainActor in
                    guard let activeId = activeWakeAlarmID else {
                        if !success {
                            conversationManager.reset()
                        }
                        return
                    }

                    guard #available(iOS 26.0, *) else {
                        activeWakeAlarmID = nil
                        wakeRetryCount = 0
                        return
                    }

                    if success {
                        wakeRetryCount = 0
                        try? await AlarmKitManager.shared.cancelAlarm(idString: activeId)
                        for id in scheduledRetryAlarmIDs {
                            try? await AlarmKitManager.shared.cancelAlarm(idString: id)
                        }
                        scheduledRetryAlarmIDs.removeAll()
                        LocalStore.saveCurrentRetryAlarmID(nil)
                        LocalStore.saveRetryAttemptCount(0)
                        LocalStore.savePendingChallengeText(nil)
                        LocalStore.savePendingChallengeAudioPath(nil)
                        LocalStore.clearProvisionalRetryAlarmIDs()
                        if activeWakeAlarmKind == .nap {
                            clearNapAlarm()
                        }
                        activeWakeAlarmID = nil
                        isWakeSessionActive = false
                        return
                    }

                    defer { conversationManager.reset() }

                    wakeRetryCount += 1
                    if LocalStore.loadRetryAttemptCount() >= maxRetryAttempts {
                        wakeRetryCount = 0
                        try? await AlarmKitManager.shared.cancelAlarm(idString: activeId)
                        for id in scheduledRetryAlarmIDs {
                            try? await AlarmKitManager.shared.cancelAlarm(idString: id)
                        }
                        scheduledRetryAlarmIDs.removeAll()
                        LocalStore.saveCurrentRetryAlarmID(nil)
                        LocalStore.saveRetryAttemptCount(0)
                        LocalStore.savePendingChallengeText(nil)
                        LocalStore.savePendingChallengeAudioPath(nil)
                        LocalStore.clearProvisionalRetryAlarmIDs()
                        if activeWakeAlarmKind == .nap {
                            clearNapAlarm()
                        }
                        activeWakeAlarmID = nil
                        isWakeSessionActive = false
                    }
                }
            }
            .onAppear {
                Task { @MainActor in
                    await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .appLaunched)
                }
            }
            // Phone lock detection for volume gate escape
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                // User is locking the phone
                if case let .blocked(_, alarmKind) = volumeGate.state {
                    DebugLogger.log("[StageManager] User locked phone while volume gate active - scheduling retry")
                    Task { @MainActor in
                        volumeGate.stopHapticLoop()
                        volumeGate.stopBlocking()
                        _ = await volumeGate.scheduleVolumeGateRetry(alarmKind: alarmKind)
                    }
                }
            }
        }
    }

    private func resolveAlarmKind(alarmId: String) -> AlarmKind {
        if appState.napAlarmID == alarmId {
            return .nap
        }
        return .scheduled
    }

    private func clearNapAlarm() {
        appState.napAlarmID = nil
        appState.napAlarmDate = nil
        appState.persist()
        LocalStore.saveNapAlarmID(nil)
        LocalStore.saveNapAlarmDate(nil)
        let soundsDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sounds")
        let napSoundURL = soundsDirectory.appendingPathComponent("personal-nap-message.m4a")
        let soundExists = FileManager.default.fileExists(atPath: napSoundURL.path)
        DebugLogger.log("[NapAlarm] Cleared nap alarm after completion. napSoundExists=\(soundExists) path=\(napSoundURL.path)")
        DebugLogger.log("[NapAlarm] Cached prompt cleared. pendingText=\(LocalStore.loadPendingChallengeText() != nil) pendingAudio=\(LocalStore.loadPendingChallengeAudioPath() != nil)")
    }
    
    // MARK: - Volume Gate Helpers
    
    /// Called when volume crosses the threshold while the nag overlay is showing.
    private func handleVolumeThresholdCrossed() {
        DebugLogger.log("[StageManager] Volume threshold crossed - proceeding with alarm flow")
        
        // Stop haptics and blocking state
        volumeGate.stopHapticLoop()
        volumeGate.stopBlocking()
        
        // Proceed with the alarm flow
        guard let alarmId = activeWakeAlarmID else {
            DebugLogger.log("[StageManager] No active alarm ID when volume threshold crossed")
            return
        }
        
        Task { @MainActor in
            await proceedWithAlarmFlow(alarmId: alarmId, alarmKind: activeWakeAlarmKind, notification: nil)
        }
    }
    
    /// Proceeds with the normal alarm flow after volume check passes.
    private func proceedWithAlarmFlow(alarmId: String, alarmKind: AlarmKind, notification: Notification?) async {
        // Conversation overlay should already be showing from beginWakeUI()
        // If not, show it now
        if conversationManager.state == .idle {
            conversationManager.beginWakeUI()
        }
        
        let notifiedIsRetry = (notification?.userInfo?["isRetry"] as? Bool) ?? false
        let storedIsRetry = LocalStore.loadProvisionalRetryAlarmIDs().contains(alarmId)
        let isRetry = notifiedIsRetry || storedIsRetry
        
        // This alarm has now fired; remove from retry-id set (if present).
        if storedIsRetry {
            LocalStore.removeProvisionalRetryAlarmID(alarmId)
        }
        
        isWakeSessionActive = true
        
        if !isRetry {
            LocalStore.saveRetryAttemptCount(0)
        }
        
        // If we managed to open the app and begin the conversation flow, cancel any
        // provisional retry scheduled to cover the "app open failed" case.
        if #available(iOS 26.0, *) {
            if let retryId = LocalStore.loadCurrentRetryAlarmID() {
                try? await AlarmKitManager.shared.cancelAlarm(idString: retryId)
                LocalStore.saveCurrentRetryAlarmID(nil)
                LocalStore.removeProvisionalRetryAlarmID(retryId)
                DebugLogger.log("[StageManager] Cancelled current retry alarm: \(retryId)")
            }
        }
        
        // Wake session has started; retries count from here.
        wakeRetryCount = LocalStore.loadRetryAttemptCount()
        
        // Once we're entering a wake conversation, ensure no pending retry alarm remains.
        if #available(iOS 26.0, *) {
            if let retryId = LocalStore.loadCurrentRetryAlarmID() {
                try? await AlarmKitManager.shared.cancelAlarm(idString: retryId)
                LocalStore.saveCurrentRetryAlarmID(nil)
                LocalStore.removeProvisionalRetryAlarmID(retryId)
            }
        }
        
        // If this firing corresponds to an override, clear it now (wake-session start).
        if let overrideDate = appState.nextAlarmOverride {
            if overrideDate <= Date() {
                appState.nextAlarmOverride = nil
                appState.persist()
            }
        }
        
        if let overrideDate = appState.dailyOverrideDate,
           Calendar.current.isDateInToday(overrideDate) {
            appState.dailyOverrideDate = nil
            appState.dailyOverrideTime = nil
            appState.persist()
        }
        
        // Chain the next scheduled alarm immediately.
        await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .alarmFiredChain)
        
        let shouldReplay = (LocalStore.loadRetryAttemptCount() > 0) && (LocalStore.loadPendingChallengeText() != nil)
        
        if (isRetry || shouldReplay), let pending = LocalStore.loadPendingChallengeText() {
            // Retry flow - use existing prompt
            await conversationManager.startWithExistingPrompt(goal: appState.goalText, prompt: pending, alarmKind: alarmKind)
        } else {
            // Normal flow - use preloaded message (or fall back to loading)
            await conversationManager.startWithPreloadedMessage()
        }
        
        // Safety: if something prevented the conversation from actually starting,
        // retry once after a short delay.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if case .preparing = conversationManager.state {
                await conversationManager.start(goal: appState.goalText, alarmKind: alarmKind)
            }
        }
    }
}
