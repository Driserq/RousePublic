import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // Local state to hold edits before saving
    @State private var name: String = ""
    @State private var goal: String = ""
    @State private var isSaving = false
    @State private var isRegenerating = false
    @State private var statusMessage = ""
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .disabled(isSaving || isRegenerating)
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveSettings()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                    .disabled(isSaving || isRegenerating)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PROFILE")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.leading, 8)
                            
                            VStack(spacing: 1) {
                                // Name Field
                                HStack {
                                    Text("Name")
                                        .foregroundColor(.white)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    TextField("Your Name", text: $name)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Goal Field
                                HStack {
                                    Text("Goal")
                                        .foregroundColor(.white)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    TextField("Your Main Goal", text: $goal)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                            }
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ABOUT")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Version")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("1.0.0")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                            }
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Text("Your goal helps the AI personalize your wake-up experience.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                        if isRegenerating {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                
                                Text(statusMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 20)
                            .transition(.opacity)
                        }
                    }
                }
            }
            
            // Loading Overlay (optional, but good for blocking interaction)
            if isRegenerating {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        // Load from UserDefaults
        name = UserDefaults.standard.string(forKey: "user_name") ?? ""
        
        // Load goal from AppState (which is already synced with UserDefaults)
        goal = appState.goalText
    }
    
    private func saveSettings() {
        // Dismiss keyboard immediately
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        isSaving = true
        
        // Check if regeneration is needed (if name or goal changed)
        let oldName = UserDefaults.standard.string(forKey: "user_name") ?? ""
        let oldGoal = appState.goalText
        
        let needsRegeneration = (name != oldName) || (goal != oldGoal)
        
        // Save to UserDefaults
        UserDefaults.standard.set(name, forKey: "user_name")
        
        // Update AppState (which handles its own persistence for goal)
        appState.goalText = goal
        appState.persist()
        
        if needsRegeneration {
            regenerateWakeMessage()
        } else {
            finishSaving()
        }
    }
    
    private func regenerateWakeMessage() {
        isRegenerating = true
        statusMessage = "Updating your wake-up experience..."
        
        Task {
            do {
                // Use the new consolidated generation
                let _ = try await TTSAudioManager.shared.generateConsolidatedWakeMessage(
                    userGoal: goal,
                    personality: "motivational coach" // Could be dynamic if we add personality settings later
                )
                
                await MainActor.run {
                    statusMessage = "Done!"
                    // Small delay to show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        finishSaving()
                    }
                }
            } catch {
                DebugLogger.log("[SettingsView] Regeneration failed: \(error)")
                await MainActor.run {
                    statusMessage = "Failed to update audio. Try again later."
                    // Wait a bit then dismiss anyway, or let user retry? 
                    // For now, dismiss after showing error briefly
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        finishSaving()
                    }
                }
            }
        }
    }
    
    private func finishSaving() {
        // Haptic feedback
        Haptics.success()
        
        // Dismiss
        isSaving = false
        isRegenerating = false
        dismiss()
    }
}

