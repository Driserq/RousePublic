import SwiftUI
import AlarmKit

struct HomeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var conversationManager: ConversationManager
    var namespace: Namespace.ID
    
    var toScheduler: () -> Void
    var toSettings: () -> Void
    
    @State private var isSchedulingAlarm = false
    @State private var isAdjustNextAlarmSheetPresented = false
    @State private var adjustMode: AdjustMode?
    @State private var adjustTimeDraft: Date = Date()
    @State private var isNapSheetPresented = false
    @State private var napDurationMinutes: Int = 20
    @State private var isSchedulingNap = false
    #if DEBUG
    @State private var isLogViewerPresented = false
    #endif
    @State private var isFeedbackSheetPresented = false
    @State private var feedbackText = ""
    @State private var feedbackValidationMessage = ""
    @State private var isFeedbackResultPresented = false
    @State private var feedbackResultMessage = ""
    @State private var isSendingFeedback = false
    private let feedbackMaxLength = 3000

    private enum AdjustMode {
        case oneOff
    }
    
    var body: some View {
        GeometryReader { geometry in
            let circleSize = min(geometry.size.width, geometry.size.height) * 0.91
            let nextScheduledDate = getNextScheduledDate()
            let napDate = appState.napAlarmDate
            let nextAlarmInfo = TimeUtils.nextAlarmInfo(scheduledDate: nextScheduledDate, napDate: napDate)
            let nextAlarmDate = nextAlarmInfo?.date
            let nextAlarmTimeAndDayText = nextAlarmDate.map { formatTimeAndDay(for: $0) }
            let nextScheduledTimeAndDayText = nextScheduledDate.map { formatTimeAndDay(for: $0) }
            let isNapNext = nextAlarmInfo?.kind == .nap
            
            ZStack {
                // Background is handled by StageManager
                Color.clear
                
                VStack(spacing: 0) {
                    // Header (Navigation)
                    HStack(alignment: .center, spacing: Brand.Spacing.gap) {
                        Button(action: toScheduler) {
                            Image(systemName: "clock.fill")
                                .font(Brand.Icon.navigationFont)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Spacer()

                        HStack(spacing: Brand.Spacing.gap) {
                            #if DEBUG
                            Button("Logs", systemImage: "doc.text.magnifyingglass") {
                                isLogViewerPresented = true
                            }
                            .labelStyle(.iconOnly)
                            .font(Brand.Icon.navigationFont)
                            .foregroundStyle(.white.opacity(0.8))
                            #endif

                            Button(action: toSettings) {
                                Image(systemName: "gearshape.fill")
                                    .font(Brand.Icon.navigationFont)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, Brand.Spacing.horizontalLarge)
                    .padding(.top, geometry.safeAreaInsets.top)

                    Spacer(minLength: geometry.size.height * 0.08)

                    // MAIN INTERFACE (Centered with slight downward bias)
                    VStack(spacing: 32) {
                        // ZEN CIRCLE
                        ZStack {
                            ZenBlobView(
                                state: .idle,
                                audioLevel: 0,
                                namespace: namespace
                            )
                            .frame(width: circleSize, height: circleSize)
                            .onTapGesture {
                                Task {
                                    await triggerImmediateAlarmTest()
                                }
                            }

                            // Countdown inside
                            VStack(spacing: 6) {
                                Text(isNapNext ? "ENDING NAP IN" : "ALARM IN")
                                    .font(Brand.Typography.caption)
                                    .tracking(1.2)
                                    .foregroundStyle(Brand.Colors.textSecondary)

                                if let next = nextAlarmDate {
                                    CountdownText(targetDate: next)
                                    if isNapNext, let scheduledLabel = nextScheduledTimeAndDayText {
                                        Text("Next scheduled alarm at \(scheduledLabel)")
                                            .font(Brand.Typography.caption)
                                            .foregroundStyle(Brand.Colors.textSecondary)
                                    } else if let nextAlarmLabel = nextAlarmTimeAndDayText {
                                        Text(nextAlarmLabel)
                                            .font(Brand.Typography.caption)
                                            .foregroundStyle(Brand.Colors.textSecondary)
                                    }
                                } else {
                                    Text("OFF")
                                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Brand.Colors.textPrimary)
                                }
                            }
                            .frame(width: circleSize, height: circleSize, alignment: .center)
                        }

                        Button {
                            if nextScheduledDate != nil {
                                beginAdjustNextAlarm(mode: .oneOff, nextAlarmDate: nextScheduledDate)
                            } else {
                                toScheduler()
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text("Adjust Next Alarm")
                                    .font(Brand.Button.font)
                                    .foregroundStyle(Brand.Colors.textPrimary)
                                
                                if let nextAlarmLabel = nextScheduledTimeAndDayText {
                                    Text(nextAlarmLabel)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Brand.Colors.textSecondary)
                                } else {
                                    Text("No alarm scheduled")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Brand.Colors.textTertiary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: Brand.Button.cornerRadiusLarge, style: .continuous)
                                    .fill(Color.white.opacity(Brand.Button.backgroundOpacity))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Brand.Button.cornerRadiusLarge, style: .continuous)
                                    .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Brand.Spacing.horizontalLarge)
                        .disabled(nextScheduledDate == nil)
                        .opacity(nextScheduledDate == nil ? Brand.Button.disabledOpacity : 1)

                        Button {
                            napDurationMinutes = 5
                            isNapSheetPresented = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bed.double.fill")
                                Text("Start Nap")
                            }
                            .font(.headline)
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
                            .clipShape(.rect(cornerRadius: Brand.Button.cornerRadiusLarge))
                            .overlay(
                                RoundedRectangle(cornerRadius: Brand.Button.cornerRadiusLarge, style: .continuous)
                                    .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Brand.Spacing.horizontalLarge)
                    }

                    Spacer(minLength: geometry.size.height * 0.07)
                    
                    // Footer / Hint
                    Text("Swipe for menu")
                        .font(Brand.Typography.caption2)
                        .foregroundStyle(Brand.Colors.textMuted)
                        .padding(.bottom, Brand.Spacing.bottomNavigation + Brand.Spacing.gap)
                }
            }
            .overlay(alignment: .bottom) {
                Button("FEEDBACK PLEASE") {
                    feedbackValidationMessage = ""
                    feedbackText = ""
                    isFeedbackSheetPresented = true
                }
                .font(Brand.Typography.caption2)
                .foregroundStyle(Brand.Colors.textSecondary)
                .buttonStyle(.plain)
                .disabled(isSendingFeedback)
                .opacity(isSendingFeedback ? Brand.Button.disabledOpacity : 1)
                .padding(.bottom, Brand.Spacing.bottomNavigation)
            }
            .sheet(isPresented: $isFeedbackSheetPresented) {
                FeedbackSheetView(
                    text: $feedbackText,
                    helperText: feedbackAlertMessage,
                    maxLength: feedbackMaxLength,
                    isSending: isSendingFeedback,
                    isValid: isFeedbackValid,
                    onSend: {
                        Task { @MainActor in
                            await submitFeedback()
                        }
                    },
                    onCancel: {
                        isFeedbackSheetPresented = false
                    }
                )
            }
            .alert("Feedback", isPresented: $isFeedbackResultPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackResultMessage)
            }
            .sheet(isPresented: $isAdjustNextAlarmSheetPresented) {
                AdjustNextAlarmSheet(time: $adjustTimeDraft) {
                    Task { @MainActor in
                        await commitAdjustNextAlarm(mode: adjustMode, nextAlarmDate: nextAlarmDate)
                        isAdjustNextAlarmSheetPresented = false
                        adjustMode = nil
                    }
                } onCancel: {
                    isAdjustNextAlarmSheetPresented = false
                    adjustMode = nil
                }
            }
            .sheet(isPresented: $isNapSheetPresented) {
                NapAlarmSheet(durationMinutes: $napDurationMinutes) {
                    Task { @MainActor in
                        await scheduleNapAlarm()
                        isNapSheetPresented = false
                    }
                } onCancel: {
                    isNapSheetPresented = false
                }
            }
            #if DEBUG
            .sheet(isPresented: $isLogViewerPresented) {
                DebugLogViewer()
            }
            #endif
        }
    }
    
    // MARK: - Helpers
    
    private func getNextScheduledDate() -> Date? {
        if let lastScheduled = appState.lastScheduledDate, lastScheduled > Date() {
            return lastScheduled
        }
        return NextAlarmScheduler.computeNextDate(appState: appState)
    }
    
    private func formatTimeAndDay(for date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        
        return "\(timeFormatter.string(from: date)) · \(dayFormatter.string(from: date))"
    }

    private var trimmedFeedback: String {
        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFeedbackValid: Bool {
        !trimmedFeedback.isEmpty && trimmedFeedback.count <= feedbackMaxLength
    }

    private var feedbackAlertMessage: String {
        if isSendingFeedback {
            return "Sending feedback..."
        }

        if !feedbackValidationMessage.isEmpty {
            return feedbackValidationMessage
        }

        if trimmedFeedback.isEmpty {
            return "Share what worked, what didn't, or what you'd like to see."
        }

        if trimmedFeedback.count > feedbackMaxLength {
            return "Please keep feedback under \(feedbackMaxLength) characters."
        }

        return "Your feedback helps improve the experience."
    }
    
    private func beginAdjustNextAlarm(mode: AdjustMode, nextAlarmDate: Date?) {
        guard let nextAlarmDate else { return }
        adjustMode = mode
        adjustTimeDraft = nextAlarmDate
        isAdjustNextAlarmSheetPresented = true
    }

    private func submitFeedback() async {
        let trimmed = trimmedFeedback

        guard !isSendingFeedback else { return }
        guard !trimmed.isEmpty else {
            feedbackValidationMessage = "Feedback can't be empty."
            return
        }
        guard trimmed.count <= feedbackMaxLength else {
            feedbackValidationMessage = "Please keep feedback under \(feedbackMaxLength) characters."
            return
        }

        isSendingFeedback = true
        defer { isSendingFeedback = false }

        let report = BackendReportIssueRequest(
            message: trimmed,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "iOS",
            goal: "",
            lastPromptText: nil,
            lastSSML: nil,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await BackendService.shared.reportIssue(report)
            feedbackResultMessage = "Thanks for the feedback."
        } catch let error as BackendServiceError {
            switch error {
            case .httpStatus(let status, _):
                if status == 404 {
                    feedbackResultMessage = "Feedback service is unavailable (404). Check BACKEND_BASE_URL."
                } else if status == 401 {
                    feedbackResultMessage = "Feedback service rejected the request (401). Check BACKEND_SHARED_KEY."
                } else {
                    feedbackResultMessage = "We couldn't send your feedback (\(status)). Please try again later."
                }
            default:
                feedbackResultMessage = "We couldn't send your feedback. Please try again later."
            }
        } catch {
            feedbackResultMessage = "We couldn't send your feedback. Please try again later."
        }

        isFeedbackSheetPresented = false
        feedbackText = ""
        isFeedbackResultPresented = true
    }

    private func commitAdjustNextAlarm(mode: AdjustMode?, nextAlarmDate: Date?) async {
        guard let mode else { return }

        switch mode {
        case .oneOff:
            if #available(iOS 26.0, *) {
                if let id = appState.nextScheduledAlarmID {
                    try? await AlarmKitManager.shared.cancelAlarm(idString: id)
                } else if let closestId = await AlarmKitManager.shared.findClosestNonRetryAlarmId() {
                    try? await AlarmKitManager.shared.cancelAlarm(idString: closestId)
                }

                appState.nextScheduledAlarmID = nil
                appState.lastScheduledDate = nil
                appState.persist()
            }
            let todayStart = TimeUtils.startOfDay(Date())
            appState.dailyOverrideDate = todayStart
            appState.dailyOverrideTime = adjustTimeDraft
            appState.nextAlarmOverride = nil

            if let entry = TimeUtils.nextScheduleEntry(from: appState.alarmSchedule),
               Calendar.current.isDateInToday(entry.date) {
                appState.suppressedScheduleKey = entry.key
                appState.suppressedScheduleDate = entry.date  // Store actual scheduled time, not start of day
            } else {
                appState.suppressedScheduleKey = nil
                appState.suppressedScheduleDate = nil
            }

            /*
            // PREVIOUS LOGIC (commented for easy revert)
            appState.nextAlarmOverride = adjustTimeDraft
            */
            appState.persist()
            await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .overrideChanged)
        }
    }
    
    private func triggerImmediateAlarmTest() async {
        guard !isSchedulingAlarm else { return }
        isSchedulingAlarm = true
        defer { isSchedulingAlarm = false }
        
        // Reuse logic
         guard let name = UserDefaults.standard.string(forKey: "user_name"),
               let goal = UserDefaults.standard.string(forKey: "user_goal") else {
             return
         }
        
         if #available(iOS 26.0, *) {
             do {
                 let authorized = await AlarmKitManager.shared.requestAuthorization()
                 if authorized {
                     try await AlarmKitManager.shared.scheduleImmediateAlarm(name: name, goal: goal, delaySeconds: 5)
                     Haptics.success()
                 }
             } catch {
                 Haptics.error()
             }
         }
    }

    private func scheduleNapAlarm() async {
        guard !isSchedulingNap else { return }
        isSchedulingNap = true
        defer { isSchedulingNap = false }

        let duration = max(5, min(240, napDurationMinutes))
        let napDate = Date().addingTimeInterval(TimeInterval(duration * 60))

        guard let name = UserDefaults.standard.string(forKey: "user_name"),
              let goal = UserDefaults.standard.string(forKey: "user_goal") else {
            return
        }

        if #available(iOS 26.0, *) {
            do {
                if let existingId = appState.napAlarmID {
                    try? await AlarmKitManager.shared.cancelAlarm(idString: existingId)
                }

                let authorized = await AlarmKitManager.shared.requestAuthorization()
                guard authorized else { return }

                let id = try await AlarmKitManager.shared.scheduleFixedAlarm(at: napDate, name: name, goal: goal, kind: .nap)
                appState.napAlarmID = id
                appState.napAlarmDate = napDate
                appState.napDurationMinutes = duration
                appState.persist()
                DebugLogger.log("[NapAlarm] Scheduled nap alarm at \(napDate) for \(duration)m id=\(id)")
                Haptics.success()
            } catch {
                DebugLogger.log("[NapAlarm] Failed to schedule nap alarm: \(error)")
                Haptics.error()
            }
        }
    }
}

// Simple Countdown Text Component
struct CountdownText: View {
    let targetDate: Date
    @State private var timeString: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(Brand.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .onReceive(timer) { _ in
                updateTime()
            }
            .onAppear { updateTime() }
    }
    
    private func updateTime() {
        let remaining = targetDate.timeIntervalSinceNow
        if remaining > 0 {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            timeString = String(format: "%02dh %02dm", hours, minutes)
        } else {
            timeString = "00h 00m"
        }
    }
}

private struct AdjustNextAlarmSheet: View {
    @Binding var time: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()

                Spacer()
            }
            .navigationTitle("Adjust Next Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}
