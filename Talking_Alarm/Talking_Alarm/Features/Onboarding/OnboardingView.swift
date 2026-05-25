import SwiftUI
import UIKit
import AlarmKit

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @StateObject private var nameValidator = NameValidator()
    @State private var currentPage = 0
    @State private var isTTSGenerationComplete = false
    @State private var isAIConsentGiven = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ProgressBarView(
                progress: onboardingManager.progressPercentage,
                progressText: onboardingManager.progressText
            )
            
            // Page Content
            TabView(selection: $currentPage) {
                WelcomeScreenView()
                    .tag(0)
                
                NameCollectionView(
                    nameValidator: nameValidator,
                    userData: $onboardingManager.userData
                )
                .tag(1)
                
                GoalCollectionView(userData: $onboardingManager.userData)
                    .tag(2)
                
                AlarmSetupView(userData: $onboardingManager.userData)
                    .tag(3)
                
                PermissionsView(
                    onAllPermissionsGranted: {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                )
                .tag(4)
                
                AIConsentView(
                    isConsentGiven: $isAIConsentGiven,
                    onConsentGiven: {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                )
                .tag(5)
                
                TTSGenerationView(
                    userData: onboardingManager.userData,
                    isGenerationComplete: $isTTSGenerationComplete,
                    onComplete: {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                )
                .tag(6)
                
                CompletionView()
                    .tag(7)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Navigation Controls
            NavigationControlsView(
                currentPage: $currentPage,
                onboardingManager: onboardingManager,
                nameValidator: nameValidator,
                isTTSGenerationComplete: isTTSGenerationComplete,
                isAIConsentGiven: isAIConsentGiven
            )
        }
        .background(
            Brand.Colors.background
                .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
        .onChange(of: currentPage) { _, newPage in
            onboardingManager.currentScreen = OnboardingScreen(rawValue: newPage) ?? .welcome
        }
    }
}

// MARK: - Progress Bar View
struct ProgressBarView: View {
    let progress: Double
    let progressText: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(Int(progress))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Custom progress bar with glass-morphic styling
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track (inactive portion) - subtle white opacity
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    
                    // Progress (active portion) - brighter white
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: geometry.size.width * (progress / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

// MARK: - Welcome Screen
/// Welcome screen with consistent typography using OnboardingHeader component.
/// **Requirements: 3.1, 3.2, 3.3**
struct WelcomeScreenView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                
                OnboardingHeader(
                    title: "Welcome to Talking Alarm",
                    subtitle: "An AI-powered wake-up experience that ensures you're truly awake and ready to tackle your goals."
                )
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Name Collection View
/// Name collection screen with DarkTextField and consistent typography.
/// **Requirements: 3.3, 4.1, 4.2**
struct NameCollectionView: View {
    @ObservedObject var nameValidator: NameValidator
    @Binding var userData: OnboardingUserData
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            OnboardingHeader(
                title: "What's your name?",
                subtitle: "We'll use this to personalize your wake-up message."
            )
            .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                DarkTextField(
                    placeholder: "Enter your name",
                    text: $userData.name
                )
                .onChange(of: userData.name) { _, newValue in
                    nameValidator.validateName(newValue)
                }
                
                // Validation feedback
                HStack {
                    if nameValidator.isChecking {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                        Text("Checking...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: nameValidator.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(nameValidator.isValid ? .green : .red)
                        Text(nameValidator.validationMessage)
                            .font(.caption)
                            .foregroundStyle(nameValidator.isValid ? .green : .red)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Goal Collection View
/// Goal collection screen with DarkTextField and consistent typography.
/// **Requirements: 3.3, 4.1, 4.2**
struct GoalCollectionView: View {
    @Binding var userData: OnboardingUserData
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            OnboardingHeader(
                title: "What's your morning goal?",
                subtitle: "What do you want to accomplish each morning?"
            )
            .padding(.horizontal, 24)
            
            VStack(spacing: 16) {
                DarkTextField(
                    placeholder: "Enter your goal (3-50 characters)",
                    text: $userData.goal
                )
                
                HStack {
                    Text("\(userData.goal.count)/50 characters")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    
                    if userData.goal.count >= 3 && userData.goal.count <= 50 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Alarm Setup View
/// Alarm setup screen with glass-morphic day selection buttons.
/// **Requirements: 2.1, 3.3, 5.1, 5.2**
struct AlarmSetupView: View {
    @Binding var userData: OnboardingUserData
    @State private var selectedDays: Set<Int> = []
    
    let days = [
        (1, "S", "Sunday"),
        (2, "M", "Monday"),
        (3, "T", "Tuesday"),
        (4, "W", "Wednesday"),
        (5, "T", "Thursday"),
        (6, "F", "Friday"),
        (7, "S", "Saturday")
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            OnboardingHeader(
                title: "Set your alarm time",
                subtitle: "Choose when you want to wake up."
            )
            .padding(.horizontal, 24)
            
            DatePicker("Alarm Time", selection: $userData.alarmTime, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .colorScheme(.dark)
                .tint(.white)
                .scaleEffect(1.5)
                .padding(.bottom, 20)
            
            // Days Selection with glass-morphic styling
            VStack(spacing: 16) {
                Text("Repeat (Optional)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                
                HStack(spacing: 12) {
                    ForEach(days, id: \.0) { day in
                        Button {
                            toggleDay(day.0)
                        } label: {
                            Text(day.1)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedDays.contains(day.0) ? Color.white.opacity(0.3) : Color.white.opacity(0.08))
                                )
                                .foregroundStyle(.white)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding()
        .onChange(of: selectedDays) { _, newDays in
            // Save days immediately when changed
            LocalStore.saveAlarmDays(newDays)
        }
        .onChange(of: userData.alarmTime) { _, newTime in
            // Save alarm time immediately when changed
            LocalStore.saveAlarmDate(newTime)
        }
        .onAppear {
            // Load any previously saved days
            if let savedDays = LocalStore.loadAlarmDays() {
                selectedDays = savedDays
            }
        }
    }
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - TTS Generation View
/// TTS generation screen with consistent typography and progress styling.
/// **Requirements: 3.3**
struct TTSGenerationView: View {
    let userData: OnboardingUserData
    @Binding var isGenerationComplete: Bool
    let onComplete: () -> Void
    
    @State private var isGenerating = true
    @State private var progress: Double = 0
    @State private var statusMessage = "Preparing your escalating wake-up sequence..."
    @State private var currentAttempt = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            OnboardingHeader(
                title: "Generating your wake-up sequence",
                subtitle: "Creating 4 escalating personalized messages (plus an offline backup)..."
            )
            .padding(.horizontal, 24)
            
            VStack(spacing: 24) {
                if isGenerating {
                    // Custom progress bar with glass-morphic styling
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: geometry.size.width * (progress / 100), height: 8)
                        }
                    }
                    .frame(width: 200, height: 8)
                    
                    Text(statusMessage)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                    
                    if currentAttempt > 0 {
                        Text("Generated \(currentAttempt) of 4 messages")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text("Wake-up sequence ready!")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("4 escalating messages generated")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            generateEscalatingMessages()
        }
    }
    
    private func generateEscalatingMessages() {
        Task {
            do {
                DebugLogger.log("[OnboardingView] Generating escalating wake-up sequence for \(userData.name)")
                
                // Use consolidated generation logic
                let _ = try await TTSAudioManager.shared.generateConsolidatedWakeMessage(
                    userGoal: userData.goal,
                    personality: "motivational coach"
                )

                await MainActor.run {
                    statusMessage = "Generating offline fallback message..."
                    progress = 85
                }

                do {
                    let _ = try await TTSAudioManager.shared.generateOfflineFallbackMessage(
                        userGoal: userData.goal,
                        personality: "motivational coach"
                    )
                } catch {
                    DebugLogger.log("[OnboardingView] Failed to generate offline fallback message: \(error)")
                }
                
                await MainActor.run {
                    withAnimation {
                        progress = 100
                        // currentAttempt logic is less relevant now as it's one step, but we can set it to max for UI
                        currentAttempt = 4 
                        statusMessage = "All messages generated successfully!"
                        isGenerating = false
                        isGenerationComplete = true
                    }
                }
                
                DebugLogger.log("[OnboardingView] Generated consolidated message")
                
                // Proceed to completion
                await MainActor.run {
                    onComplete()
                }
                
            } catch {
                DebugLogger.log("[OnboardingView] Failed to generate escalating messages: \(error)")
                
                // Fallback to single message generation
                await MainActor.run {
                    statusMessage = "Generating fallback message..."
                    progress = 50
                }
                
                do {
                    // Try consolidated generation again or fallback logic?
                    // Let's stick to the existing fallback path which uses TTSService directly
                    // But we should ensure TTSService uses the same file path/logic if possible
                    // Actually, let's just use the same consolidated call but maybe with simpler params or retry
                    // For now, retaining the old fallback logic but aware it might need alignment.
                    // Ideally fallback should also produce 'personal-wake-message.m4a'
                    
                    try await TTSService.shared.generatePersonalWakeMessage(
                        name: userData.name,
                        goal: userData.goal
                    )

                    await MainActor.run {
                        statusMessage = "Generating offline fallback message..."
                        progress = 80
                    }

                    do {
                        let _ = try await TTSAudioManager.shared.generateOfflineFallbackMessage(
                            userGoal: userData.goal,
                            personality: "motivational coach"
                        )
                    } catch {
                        DebugLogger.log("[OnboardingView] Failed to generate offline fallback message (fallback path): \(error)")
                    }
                    
                    await MainActor.run {
                        withAnimation {
                            progress = 100
                            statusMessage = "Fallback message generated"
                            isGenerating = false
                            isGenerationComplete = true
                        }
                    }
                    
                    // Proceed to completion
                    await MainActor.run {
                        onComplete()
                    }
                    
                } catch {
                    await MainActor.run {
                        statusMessage = "Generation completed with fallback"
                        withAnimation {
                            progress = 100
                            isGenerating = false
                            isGenerationComplete = true
                        }
                    }

                    // Best-effort: still try to generate the offline fallback message.
                    do {
                        let _ = try await TTSAudioManager.shared.generateOfflineFallbackMessage(
                            userGoal: userData.goal,
                            personality: "motivational coach"
                        )
                    } catch {
                        DebugLogger.log("[OnboardingView] Failed to generate offline fallback message (double-fallback path): \(error)")
                    }
                    
                    // Still request AlarmKit permissions even if generation failed
                    // await requestAlarmPermissions() // NOW HANDLED IN PERMISSIONS VIEW
                    
                    // Proceed to completion
                    await MainActor.run {
                        onComplete()
                    }
                }
            }
        }
    }
    // REMOVED requestAlarmPermissions as it's now handled in PermissionsView step
    }


// MARK: - Completion View
/// Completion screen with consistent typography.
/// **Requirements: 3.1, 3.3**
struct CompletionView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
                
                OnboardingHeader(
                    title: "All set!",
                    subtitle: "Your personalized alarm is ready to go!"
                )
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Navigation Controls
/// Navigation controls with GlassButton styling.
/// **Requirements: 5.3, 10.1, 10.2, 10.3**
struct NavigationControlsView: View {
    @Binding var currentPage: Int
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var nameValidator: NameValidator
    var isTTSGenerationComplete: Bool
    var isAIConsentGiven: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button - only show after first page
            if currentPage > 0 {
                GlassButton(
                    title: "Back",
                    isEnabled: true,
                    isPrimary: false
                ) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    withAnimation {
                        currentPage -= 1
                    }
                }
            }
            
            // Continue/Get Started button
            GlassButton(
                title: currentPage == 7 ? "Get Started" : "Continue",
                isEnabled: canProceed,
                isPrimary: true
            ) {
                // Hide keyboard when moving to next page
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if currentPage == 7 {
                    // Final screen - complete onboarding
                    onboardingManager.completeOnboarding()
                } else {
                    withAnimation {
                        currentPage += 1
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var canProceed: Bool {
        switch currentPage {
        case 0: return true // Welcome
        case 1: return nameValidator.canProceed // Name collection
        case 2: return onboardingManager.userData.goal.isValid // Goal collection
        case 3: return true // Alarm setup
        case 4: return true // Permissions - view handles advancement
        case 5: return isAIConsentGiven // AI Consent - require checkbox
        case 6: return isTTSGenerationComplete // TTS generation - wait until complete
        case 7: return true // Completion
        default: return false
        }
    }
}

#Preview {
    OnboardingView()
}
