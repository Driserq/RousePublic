import SwiftUI

struct ConversationView: View {
    @ObservedObject var manager: ConversationManager
    @State private var voiceProcessor: VoiceProcessor
    private let config: AppBehaviorConfig

    let goal: String
    let sleepSeconds: Int

    init(manager: ConversationManager, goal: String, sleepSeconds: Int, config: AppBehaviorConfig = UserConfig.current.behavior) {
        self.manager = manager
        self.goal = goal
        self.sleepSeconds = sleepSeconds
        self.config = config
        self._voiceProcessor = State(initialValue: VoiceProcessor(config: config))
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content area with circular visualizer
                VStack(spacing: 24) {
                    // Goal display
                    VStack(spacing: 8) {
                        Text("Goal")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        Text(goal.isEmpty ? "Not set" : goal)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Circular sound visualizer
                    CircularSoundVisualizer(
                        state: manager.state,
                        attempt: manager.attempt,
                        currentVolume: voiceProcessor.currentVolume,
                        isRecording: manager.state == .recording,
                        isSpeaking: {
                            if case .speaking = manager.state { return true }
                            return false
                        }()
                    )
                    
                    // Subtitles below the circle
                    VStack(spacing: 8) {
                        // AI Message (when speaking)
                        if case .speaking(let message) = manager.state {
                            VStack(spacing: 4) {
                                Text("AI Message")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // User Transcript (when available, hide system messages)
                        if config.showTranscripts && !manager.lastTranscript.isEmpty && !manager.lastTranscript.hasPrefix("[SYSTEM:") {
                            VStack(spacing: 4) {
                                Text("Your Response")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                
                                Text(manager.lastTranscript)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Manual stop button (only show during recording)
                    if manager.state == .recording {
                        Button(action: stopAndEvaluate) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.title2)
                                
                                Text("Stop Recording")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 0)
                }
                
                // Debug panel at the bottom
                DebugPanel(
                    manager: manager,
                    voiceProcessor: voiceProcessor,
                    config: config
                )
            }
        }
        .task {
            _ = await AudioSessionManager.shared.requestMicrophonePermission()
            await manager.start(goal: goal)
        }
        .onChange(of: manager.state) { _, newState in
            DebugLogger.log("[ConversationView] State changed to: \(newState)")
            // Start recording immediately when state changes to .recording
            if case .recording = newState {
                DebugLogger.log("[ConversationView] Starting recording...")
                Task {
                    try? await Task.sleep(for: .seconds(config.autoContinueDelaySeconds))
                    DebugLogger.log("[ConversationView] Delay completed, calling startRecording...")
                    do {
                        let stream = try voiceProcessor.startRecording()
                        DebugLogger.log("[ConversationView] startRecording completed successfully")
                        await manager.startListening(stream: stream)
                    } catch {
                        DebugLogger.log("[ConversationView] startRecording failed with error: \(error)")
                    }
                }
            }
        }
        .onAppear {
            setupVoiceProcessorCallbacks()
        }
    }
    
    // MARK: - Voice Processor Setup
    
    private func setupVoiceProcessorCallbacks() {
        voiceProcessor.onAutoStop = { reason in
            DebugLogger.log("[ConversationView] Auto-stop triggered: \(reason)")
            self.handleAutoStop(reason: reason)
        }
        
        voiceProcessor.onTimeWarning = {
            DebugLogger.log("[ConversationView] Time warning triggered")
            Haptics.warning()
        }
    }
    
    private func handleAutoStop(reason: StopReason) {
        DebugLogger.log("[ConversationView] Handling auto-stop for reason: \(reason)")
        
        // Small delay to ensure UI shows the stopping state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.voiceProcessor.stopRecording()
            self.manager.stopListening()
        }
    }

    private func stopAndEvaluate() {
        DebugLogger.log("[ConversationView] Manual stop recording")
        voiceProcessor.stopRecording()
        manager.stopListening()
    }
}

#Preview {
    let manager = ConversationManager(
        backend: .shared,
        tts: TextToSpeech(elevenLabs: ElevenLabsService()),
        stt: AppleSpeechService()
    )
    return ConversationView(manager: manager, goal: "Run 5k", sleepSeconds: 7 * 3600)
}


