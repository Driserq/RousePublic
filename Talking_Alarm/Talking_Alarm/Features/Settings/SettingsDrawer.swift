import SwiftUI

struct SettingsDrawer: View {
    @ObservedObject var appState: AppState
    var onClose: () -> Void
    
    @State private var currentPage: SettingsPage = .main
    @State private var slideOffset: CGFloat = 0
    
    enum SettingsPage {
        case main
        case personalization
        case account
        case about
    }
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack {
                // Header
                HStack {
                    if currentPage != .main {
                        Button(action: { navigate(to: .main) }) {
                            Image(systemName: "chevron.left")
                                .font(Brand.Icon.navigationFont)
                                .foregroundStyle(Brand.Colors.textPrimary)
                        }
                    } else {
                         Button(action: onClose) {
                             Image(systemName: "arrow.left")
                                 .font(Brand.Icon.navigationFont)
                                 .foregroundStyle(Brand.Colors.textSecondary)
                         }
                    }
                    
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(Brand.Typography.sectionHeader)
                        .tracking(Brand.Typography.headerTracking)
                        .foregroundStyle(Brand.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(Brand.Icon.navigationFont)
                        .opacity(0)
                }
                .padding(.horizontal, Brand.Spacing.horizontalLarge)
                .padding(.top, Brand.Spacing.safeAreaTop)
                
                Spacer()
                
                ZStack {
                    if currentPage == .main {
                        MainSettingsMenu(
                            appState: appState,
                            onSelect: { page in navigate(to: page) }
                        )
                        .transition(.move(edge: .leading))
                    } else if currentPage == .personalization {
                        PersonalizationSettings(appState: appState)
                            .transition(.move(edge: .trailing))
                    } else if currentPage == .account {
                        AccountSettings(appState: appState)
                            .transition(.move(edge: .trailing))
                    } else if currentPage == .about {
                        AboutSettings()
                            .transition(.move(edge: .trailing))
                    }
                }
                .animation(.spring(), value: currentPage)
                
                Spacer()
            }
        }
    }
    
    private func navigate(to page: SettingsPage) {
        withAnimation {
            self.currentPage = page
        }
    }
}

// MARK: - Main Settings Menu

struct MainSettingsMenu: View {
    @ObservedObject var appState: AppState
    let onSelect: (SettingsDrawer.SettingsPage) -> Void

    @State private var isCancelNextAlarmAlertPresented = false
    @State private var isReportIssueAlertPresented = false
    @State private var isReportResultAlertPresented = false
    @State private var reportResultMessage = ""
    @State private var isReportingIssue = false
    
    var body: some View {
        let nextScheduledDate = getNextScheduledDate()
        let nextAlarmInfo = TimeUtils.nextAlarmInfo(scheduledDate: nextScheduledDate, napDate: appState.napAlarmDate)
        let nextAlarmLabel = nextAlarmInfo.map { alarmDisplayText(for: $0.date, kind: $0.kind) }

        VStack(spacing: 24) {
            VStack(spacing: 20) {
                SettingsButton(title: "Personalization", icon: "person.fill") {
                    onSelect(.personalization)
                }

                SettingsButton(title: "Account", icon: "person.crop.circle.fill") {
                    onSelect(.account)
                }

                SettingsButton(title: "About", icon: "info.circle.fill") {
                    onSelect(.about)
                }

                Button {
                    isReportIssueAlertPresented = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .frame(width: Brand.Icon.frameWidth)
                        Text("Report Issue")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .bold()
                        Spacer()
                        if isReportingIssue {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(Brand.Button.backgroundOpacity))
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isReportingIssue)
                .alert("Report Issue", isPresented: $isReportIssueAlertPresented) {
                    Button("Send", role: .destructive) {
                        Task { @MainActor in
                            await reportIssue()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will send a report with logs to help improve AI responses.")
                }
                .alert("Report Sent", isPresented: $isReportResultAlertPresented) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(reportResultMessage)
                }
            }
            
            // Legal Section removed - now in About sub view

            Spacer()

            Button {
                if nextAlarmInfo != nil {
                    isCancelNextAlarmAlertPresented = true
                }
            } label: {
                Text("Cancel Next Alarm")
                    .foregroundStyle(Brand.Colors.textPrimary)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Brand.Colors.error.opacity(0.25))
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                            .stroke(Brand.Colors.error.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(nextAlarmInfo == nil)
            .opacity(nextAlarmInfo == nil ? Brand.Button.disabledOpacity : 1)
            .alert("Cancel Next Alarm", isPresented: $isCancelNextAlarmAlertPresented) {
                Button("Cancel Alarm", role: .destructive) {
                    Task { @MainActor in
                        await cancelNextAlarm(nextScheduledDate: nextScheduledDate)
                    }
                }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("Are you sure it's okay to skip this alarm?\n\n\(nextAlarmLabel ?? "No upcoming alarm.")")
            }
        }
        .padding(.horizontal, Brand.Spacing.horizontalLarge)
        .padding(.top, Brand.Spacing.bottomNavigation)
    }

    private func getNextScheduledDate() -> Date? {
        if let lastScheduled = appState.lastScheduledDate, lastScheduled > Date() {
            return lastScheduled
        }
        return NextAlarmScheduler.computeNextDate(appState: appState)
    }

    private func alarmDisplayText(for date: Date, kind: AlarmKind) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let typeLabel = kind == .nap ? "Nap" : "Wake up"
        return "\(dayFormatter.string(from: date)) \(timeFormatter.string(from: date)) · \(typeLabel)"
    }


    private func cancelNextAlarm(nextScheduledDate: Date?) async {
        guard #available(iOS 26.0, *) else { return }
        guard let info = TimeUtils.nextAlarmInfo(scheduledDate: nextScheduledDate, napDate: appState.napAlarmDate) else { return }

        switch info.kind {
        case .nap:
            if let napId = appState.napAlarmID {
                try? await AlarmKitManager.shared.cancelAlarm(idString: napId)
            }
            appState.napAlarmID = nil
            appState.napAlarmDate = nil
            appState.persist()

        case .scheduled:
            if let id = appState.nextScheduledAlarmID {
                try? await AlarmKitManager.shared.cancelAlarm(idString: id)
            } else if let closestId = await AlarmKitManager.shared.findClosestNonRetryAlarmId() {
                try? await AlarmKitManager.shared.cancelAlarm(idString: closestId)
            }

            if let entry = TimeUtils.nextScheduleEntry(from: appState.alarmSchedule),
               abs(entry.date.timeIntervalSince(info.date)) < 1 {
                appState.suppressedScheduleKey = entry.key
                appState.suppressedScheduleDate = entry.date
            }

            if let override = appState.nextAlarmOverride,
               abs(override.timeIntervalSince(info.date)) < 1 {
                appState.nextAlarmOverride = nil
            }

            if let dailyDate = appState.dailyOverrideDate,
               Calendar.current.isDate(dailyDate, inSameDayAs: info.date) {
                appState.dailyOverrideDate = nil
                appState.dailyOverrideTime = nil
            }

            appState.nextScheduledAlarmID = nil
            appState.lastScheduledDate = nil
            appState.persist()

            await NextAlarmScheduler(appState: appState).rescheduleNextScheduled(reason: .overrideChanged)
        }
    }

    private func reportIssue() async {
        isReportingIssue = true
        let report = BackendReportIssueRequest(
            message: "Flag bad AI response",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "iOS",
            goal: appState.goalText,
            lastPromptText: LocalStore.loadPendingChallengeText(),
            lastSSML: UserDefaults.standard.string(forKey: "lastWelcomeMessage"),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await BackendService.shared.reportIssue(report)
            reportResultMessage = "Thanks. We received your report."
        } catch let error as BackendServiceError {
            switch error {
            case .httpStatus(let status, _):
                if status == 404 {
                    reportResultMessage = "Report service is unavailable (404). Check BACKEND_BASE_URL."
                } else if status == 401 {
                    reportResultMessage = "Report service rejected the request (401). Check BACKEND_SHARED_KEY."
                } else {
                    reportResultMessage = "We couldn't send your report (\(status)). Please try again later."
                }
            default:
                reportResultMessage = "We couldn't send your report. Please try again later."
            }
        } catch {
            reportResultMessage = "We couldn't send your report. Please try again later."
        }

        isReportingIssue = false
        isReportResultAlertPresented = true
    }
}

// MARK: - Account Settings

struct AccountSettings: View {
    @ObservedObject var appState: AppState
    
    @State private var isRevokeConsentAlertPresented = false
    @State private var isRestorePurchasesAlertPresented = false
    @State private var isDeleteAccountAlertPresented = false
    @State private var isDeleteResultAlertPresented = false
    @State private var deleteResultMessage = ""
    @State private var isProcessingDelete = false
    @AppStorage("ai_consent_given") private var hasAIConsent = false
    
    var body: some View {
        VStack(spacing: 20) {
            // AI Consent
            Button {
                isRevokeConsentAlertPresented = true
            } label: {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .frame(width: Brand.Icon.frameWidth)
                    Text("Revoke AI Consent")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .bold()
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(Brand.Button.backgroundOpacity))
                .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasAIConsent)
            .opacity(hasAIConsent ? 1 : Brand.Button.disabledOpacity)
            .alert("Revoke AI Consent", isPresented: $isRevokeConsentAlertPresented) {
                Button("Revoke", role: .destructive) {
                    hasAIConsent = false
                }
                Button("Keep Enabled", role: .cancel) {}
            } message: {
                Text("Warning: The app will not function without AI calls. Alarms that rely on AI will be disabled until you re-enable consent.")
            }

            // Restore Purchases
            Button {
                isRestorePurchasesAlertPresented = true
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .frame(width: Brand.Icon.frameWidth)
                    Text("Restore Purchases")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .bold()
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(Brand.Button.backgroundOpacity))
                .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .alert("Restore Purchases", isPresented: $isRestorePurchasesAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Not wired yet. This will be connected once billing is set up.")
            }

            // Delete Account
            Button {
                isDeleteAccountAlertPresented = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .frame(width: Brand.Icon.frameWidth)
                    Text("Delete Account")
                        .foregroundStyle(Brand.Colors.textPrimary)
                        .bold()
                    Spacer()
                    if isProcessingDelete {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Brand.Colors.error.opacity(0.2))
                .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                        .stroke(Brand.Colors.error.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isProcessingDelete)
            .alert("Delete Account", isPresented: $isDeleteAccountAlertPresented) {
                Button("Delete", role: .destructive) {
                    Task { @MainActor in
                        await deleteAccount()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes local app data and clears alarms. This action cannot be undone.")
            }
            .alert("Account Deleted", isPresented: $isDeleteResultAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteResultMessage)
            }

            Spacer()
        }
        .padding(.horizontal, Brand.Spacing.horizontalLarge)
        .padding(.top, Brand.Spacing.bottomNavigation)
    }

    @MainActor
    private func deleteAccount() async {
        isProcessingDelete = true

        await cancelAllAlarms()
        clearAudioCache()

        LocalStore.resetAll()
        appState.resetToDefaults()

        deleteResultMessage = "Your local data has been deleted."
        isDeleteResultAlertPresented = true
        isProcessingDelete = false
    }

    private func cancelAllAlarms() async {
        guard #available(iOS 26.0, *) else { return }

        if let napId = appState.napAlarmID {
            try? await AlarmKitManager.shared.cancelAlarm(idString: napId)
        }

        if let scheduledId = appState.nextScheduledAlarmID {
            try? await AlarmKitManager.shared.cancelAlarm(idString: scheduledId)
        } else if let closestId = await AlarmKitManager.shared.findClosestNonRetryAlarmId() {
            try? await AlarmKitManager.shared.cancelAlarm(idString: closestId)
        }
    }

    private func clearAudioCache() {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appending(path: "Sounds")

        if FileManager.default.fileExists(atPath: soundsURL.path) {
            try? FileManager.default.removeItem(at: soundsURL)
        }

        if let pendingPath = LocalStore.loadPendingChallengeAudioPath() {
            let pendingURL = URL(fileURLWithPath: pendingPath)
            if FileManager.default.fileExists(atPath: pendingURL.path) {
                try? FileManager.default.removeItem(at: pendingURL)
            }
        }
    }
}

// MARK: - Personalization Settings

struct PersonalizationSettings: View {
    @ObservedObject var appState: AppState
    @State private var name: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @State private var goal: String = ""
    @State private var isRegenerating = false
    @State private var statusMessage = ""
    
    var body: some View {
        VStack(spacing: Brand.Spacing.gapLarge) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(Brand.Typography.caption)
                    .foregroundStyle(Brand.Colors.textTertiary)
                TextField("Name", text: $name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Brand.Colors.textPrimary)
                    .padding(.horizontal, Brand.Spacing.vertical)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("MORNING GOAL")
                    .font(Brand.Typography.caption)
                    .foregroundStyle(Brand.Colors.textTertiary)
                TextField("Goal", text: $goal)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Brand.Colors.textPrimary)
                    .padding(.horizontal, Brand.Spacing.vertical)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(Brand.Card.rowBackgroundOpacity))
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
                    )
            }
            
            if isRegenerating {
                HStack {
                    ProgressView().tint(.white)
                    Text(statusMessage)
                        .font(Brand.Typography.caption)
                        .foregroundStyle(Brand.Colors.textSecondary)
                }
            }
            
            Button(action: save) {
                Text("Save & Update AI")
                    .font(Brand.Button.font)
                    .foregroundStyle(Brand.Colors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Brand.Colors.accent)
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            }
            .disabled(isRegenerating)
            .opacity(isRegenerating ? Brand.Button.disabledOpacity : 1)
            
            Spacer()
        }
        .padding(.horizontal, Brand.Spacing.horizontalLarge)
        .padding(.top, Brand.Spacing.bottomNavigation)
        .onAppear {
            self.goal = appState.goalText
        }
    }
    
    private func save() {
        isRegenerating = true
        statusMessage = "Updating voice..."
        
        UserDefaults.standard.set(name, forKey: "user_name")
        appState.goalText = goal
        appState.persist()
        
        Task {
            do {
                _ = try await TTSAudioManager.shared.generateConsolidatedWakeMessage(
                    userGoal: goal,
                    personality: "motivational coach"
                )

                await MainActor.run {
                    statusMessage = "Generating offline backup..."
                }

                do {
                    _ = try await TTSAudioManager.shared.generateOfflineFallbackMessage(
                        userGoal: goal,
                        personality: "motivational coach"
                    )
                } catch {
                    DebugLogger.log("[PersonalizationSettings] Offline fallback regeneration failed: \(error)")
                }

                await MainActor.run {
                    statusMessage = "Done!"
                    isRegenerating = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error updating."
                    isRegenerating = false
                    Haptics.error()
                }
            }
        }
    }
}

// MARK: - About Settings

struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 24) {
            // App info
            VStack(spacing: 8) {
                Text("Talking Alarm v1.0")
                    .foregroundStyle(Brand.Colors.textPrimary)
                Text("Designed for those who need a push.")
                    .foregroundStyle(Brand.Colors.textSecondary)
            }
            
            // Legal Section - Requirements 9.1, 9.2, 9.3, 9.4
            legalSection
            
            Spacer()
        }
        .padding(.horizontal, Brand.Spacing.horizontalLarge)
        .padding(.top, Brand.Spacing.bottomNavigation)
    }
    
    // MARK: - Legal Section (Requirements 9.1, 9.2, 9.3, 9.4)
    
    /// Legal section with Terms of Service and Privacy Policy links.
    /// Uses glass-morphic styling consistent with other SettingsDrawer sections.
    private var legalSection: some View {
        VStack(spacing: 12) {
            Text("LEGAL")
                .font(Brand.Typography.caption)
                .tracking(Brand.Typography.captionTracking)
                .foregroundStyle(Brand.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                // Terms of Service - Requirement 9.2
                Link(destination: URL(string: "https://rousalarm.app/terms")!) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .frame(width: Brand.Icon.frameWidth)
                        Text("Terms of Service")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(Brand.Colors.textMuted)
                    }
                    .padding()
                }
                
                Divider()
                    .background(Color.white.opacity(Brand.Button.backgroundOpacity))
                
                // Privacy Policy - Requirement 9.3
                Link(destination: URL(string: "https://rousalarm.app/privacy")!) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .frame(width: Brand.Icon.frameWidth)
                        Text("Privacy Policy")
                            .foregroundStyle(Brand.Colors.textPrimary)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(Brand.Colors.textMuted)
                    }
                    .padding()
                }
            }
            .background(Color.white.opacity(Brand.Button.backgroundOpacity))
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(Brand.Button.strokeOpacity), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .frame(width: 30)
                Text(title)
                    .foregroundColor(.white)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
