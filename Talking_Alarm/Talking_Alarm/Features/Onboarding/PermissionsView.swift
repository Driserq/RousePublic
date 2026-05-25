import SwiftUI
import AVFoundation
import Speech

/// Permissions view for system permissions only (no AI consent).
/// AI consent is handled on a separate screen after permissions.
/// **Requirements: 5.1, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3**
struct PermissionsView: View {
    @State private var microphoneStatus: AVAuthorizationStatus = .notDetermined
    @State private var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var alarmStatus: String = "Not Determined"
    @State private var isRequestingMic = false
    @State private var isRequestingSpeech = false
    @State private var isRequestingAlarm = false
    
    var onAllPermissionsGranted: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                VStack(spacing: 16) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "Required to hear your response when you wake up.",
                        buttonTitle: microphoneButtonTitle,
                        buttonAction: requestMicrophonePermission,
                        isGranted: microphoneStatus == .authorized,
                        isDenied: microphoneStatus == .denied,
                        isLoading: isRequestingMic
                    )

                    PermissionRow(
                        icon: "waveform.circle.fill",
                        title: "Speech Recognition",
                        description: "Required to transcribe your words locally on device.",
                        buttonTitle: speechButtonTitle,
                        buttonAction: requestSpeechPermission,
                        isGranted: speechStatus == .authorized,
                        isDenied: speechStatus == .denied || speechStatus == .restricted,
                        isLoading: isRequestingSpeech
                    )

                    PermissionRow(
                        icon: "alarm.fill",
                        title: "Alarm Access",
                        description: "Required to schedule your wake-up calls.",
                        buttonTitle: alarmButtonTitle,
                        buttonAction: requestAlarmPermission,
                        isGranted: alarmStatus == "Authorized",
                        isDenied: alarmStatus == "Denied",
                        isLoading: isRequestingAlarm
                    )
                }
                .padding(.horizontal, 20)

                if showSettingsButton {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            checkPermissions()
        }
        .onChange(of: microphoneStatus) { _, _ in checkAllGranted() }
        .onChange(of: speechStatus) { _, _ in checkAllGranted() }
        .onChange(of: alarmStatus) { _, _ in checkAllGranted() }
    }
    
    // MARK: - Logic
    
    private var microphoneButtonTitle: String {
        switch microphoneStatus {
        case .authorized: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Allow Access"
        @unknown default: return "Allow Access"
        }
    }
    
    private var speechButtonTitle: String {
        switch speechStatus {
        case .authorized: return "Granted"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Allow Access"
        @unknown default: return "Allow Access"
        }
    }
    
    private var alarmButtonTitle: String {
        switch alarmStatus {
        case "Authorized": return "Granted"
        case "Denied": return "Denied"
        default: return "Allow Access"
        }
    }
    
    private var showSettingsButton: Bool {
        return microphoneStatus == .denied || speechStatus == .denied || speechStatus == .restricted || alarmStatus == "Denied"
    }
    
    private func checkPermissions() {
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Check alarm authorization state without prompting
        if #available(iOS 26.0, *) {
            let isAuthorized = AlarmKitManager.shared.checkAuthorizationState()
            alarmStatus = isAuthorized ? "Authorized" : "Not Determined"
        }
    }
    
    private func requestMicrophonePermission() {
        guard microphoneStatus == .notDetermined else { return }
        isRequestingMic = true
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                isRequestingMic = false
                microphoneStatus = granted ? .authorized : .denied
            }
        }
    }
    
    private func requestSpeechPermission() {
        guard speechStatus == .notDetermined else { return }
        isRequestingSpeech = true
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                isRequestingSpeech = false
                speechStatus = status
            }
        }
    }
    
    private func requestAlarmPermission() {
        guard alarmStatus != "Authorized" else { return }
        isRequestingAlarm = true
        Task {
            if #available(iOS 26.0, *) {
                let granted = await AlarmKitManager.shared.requestAuthorization()
                await MainActor.run {
                    isRequestingAlarm = false
                    alarmStatus = granted ? "Authorized" : "Denied"
                }
            } else {
                await MainActor.run {
                    isRequestingAlarm = false
                    alarmStatus = "Denied"
                }
            }
        }
    }
    
    /// Auto-advance when all system permissions are granted
    private func checkAllGranted() {
        if microphoneStatus == .authorized && speechStatus == .authorized && alarmStatus == "Authorized" {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onAllPermissionsGranted()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("We need a few permissions")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("To make sure Talking Alarm works perfectly, we need access to your microphone, speech recognition, and alarms.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - AI Consent View

/// Separate AI consent screen shown after system permissions.
/// **Requirements: 6.1, 6.2, 7.3**
struct AIConsentView: View {
    @Binding var isConsentGiven: Bool
    @State private var isAIConsentChecked = false
    @AppStorage("ai_consent_given") private var hasAIConsent = false
    
    var onConsentGiven: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
                
                OnboardingHeader(
                    title: "AI Processing Consent",
                    subtitle: "Talking Alarm uses AI to create personalized wake-up conversations."
                )
                .padding(.horizontal, 24)
            }
            
            // Consent checkbox section
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        isAIConsentChecked.toggle()
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isAIConsentChecked ? Color.green : Color.white.opacity(0.1))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Group {
                                    if isAIConsentChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isAIConsentChecked ? Color.green : Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I consent to AI processing")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text("Only your transcript is sent to AI services. Your actual voice recording stays private on your device.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                
                // Disclaimer
                Text("Not medical advice. AI is for motivation only.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
        .onChange(of: isAIConsentChecked) { _, newValue in
            isConsentGiven = newValue
            if newValue {
                hasAIConsent = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    onConsentGiven()
                }
            }
        }
    }
}

/// Permission row with glass-morphic styling.
/// **Requirements: 2.1, 5.1**
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let buttonAction: () -> Void
    let isGranted: Bool
    let isDenied: Bool
    let isLoading: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(.circle)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            PermissionActionButton(
                title: buttonTitle,
                isGranted: isGranted,
                isDenied: isDenied,
                isLoading: isLoading,
                action: buttonAction
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Permission action button with glass-morphic styling.
/// **Requirements: 2.1, 5.1**
private struct PermissionActionButton: View {
    let title: String
    let isGranted: Bool
    let isDenied: Bool
    let isLoading: Bool
    let action: () -> Void
    
    private var backgroundColor: Color {
        if isGranted {
            return Color.green.opacity(0.2)
        } else if isDenied {
            return Color.red.opacity(0.15)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var strokeColor: Color {
        if isGranted {
            return Color.green.opacity(0.3)
        } else if isDenied {
            return Color.red.opacity(0.3)
        } else {
            return Color.white.opacity(0.12)
        }
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if isGranted {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Text(isDenied ? "Settings" : title)
                        .foregroundStyle(isDenied ? .red : .white)
                }
            }
            .font(.subheadline)
            .bold()
            .frame(minWidth: 76)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: Brand.Card.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Card.cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGranted || isLoading)
    }
}
