import SwiftUI

struct AlarmOverlay: View {
    @ObservedObject var manager: ConversationManager
    var namespace: Namespace.ID
    
    // Environment
    @Environment(\.scenePhase) var scenePhase
    
    // Voice Processor for audio levels - initialized same way as ConversationView
    @StateObject private var voiceProcessor = VoiceProcessor(config: UserConfig.current.behavior)
    
    // Success Animation
    @State private var scaleEffect: CGFloat = 1.0
    @State private var opacityEffect: Double = 1.0
    
    // Error Handling State
    @State private var isRetryPending = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
                .opacity(opacityEffect) // Fade out background on success
            
            VStack(spacing: 32) {
                Spacer()
                
                // Reuse ZenBlobView with matched geometry
                ZenBlobView(
                    state: mapState(manager.state),
                    audioLevel: audioLevelForState(manager.state),
                    namespace: namespace
                )
                .scaleEffect(scaleEffect) // Expand on success
                
                // Transcripts (Fade out on success)
                if scaleEffect == 1.0 {
                    VStack(spacing: 16) {
                        // Offline Fallback Mode
                        if case .offlineFallback(let instructions) = manager.state {
                            VStack(spacing: 6) {
                                Text("OFFLINE MODE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                    .tracking(1)

                                Text(instructions)
                                    .font(.callout)
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .transition(.opacity)
                            }
                        }

                        // AI Message (when speaking)
                        if case .speaking(let message) = manager.state {
                             VStack(spacing: 4) {
                                 Text("AI MESSAGE")
                                     .font(.caption2)
                                     .fontWeight(.bold)
                                     .foregroundColor(.blue)
                                     .tracking(1)
                                 
                                 Text(message)
                                     .font(.body)
                                     .foregroundColor(.white)
                                     .multilineTextAlignment(.center)
                                     .lineLimit(4)
                                     .transition(.opacity)
                             }
                        }
                        
                        // User Transcript (hide system messages)
                        if !manager.lastTranscript.isEmpty && !manager.lastTranscript.hasPrefix("[SYSTEM:") {
                            VStack(spacing: 4) {
                                Text("YOU")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1)
                                
                                Text(manager.lastTranscript)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .transition(.opacity)
                            }
                        }
                        
                        // Retry Status
                        if isRetryPending {
                             Text("Waiting for audio access...")
                                 .font(.caption)
                                 .foregroundColor(.orange)
                                 .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 30)
                    .frame(height: 150) // Reserve space
                    .transition(.opacity)
                }
                
                // Stop Button (Manual Interaction)
                if case .offlineFallback = manager.state, scaleEffect == 1.0 {
                    TwoWaySwipeToEndView {
                        manager.endOfflineFallback()
                    }
                    .padding(.horizontal, 30)
                } else if manager.state == .recording && scaleEffect == 1.0 {
                    Button(action: stopRecording) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop & Send")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .padding(.horizontal, 20)
                        .background(Color.white)
                        .cornerRadius(30)
                    }
                } else {
                    // Invisible placeholder to keep layout stable
                    Text("Placeholder")
                        .padding()
                        .opacity(0)
                }
                
                Spacer()
            }
        }
        .onAppear {
            setupVoiceProcessor()
            // Check initial state in case we missed the transition
            handleStateChange(manager.state)
        }
        .onChange(of: manager.state) { _, newState in
             handleStateChange(newState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isRetryPending {
                DebugLogger.log("[AlarmOverlay] App became active, retrying recording...")
                // Trigger state change handler again
                handleStateChange(manager.state)
            }
        }
    }
    
    private func mapState(_ state: ConversationManager.State) -> BlobState {
        switch state {
        case .idle: return .idle
        case .preparing: return .thinking
        case .speaking: return .speaking
        case .recording: return .listening
        case .evaluating: return .thinking
        case .offlineFallback: return .speaking
        case .playingGoodLuck: return .success
        case .done: return .success
        }
    }
    
    private func audioLevelForState(_ state: ConversationManager.State) -> Float {
        switch state {
        case .speaking: return manager.currentAILevel
        case .playingGoodLuck: return manager.currentAILevel
        case .recording: return voiceProcessor.currentVolume
        case .offlineFallback: return manager.currentAILevel
        default: return 0
        }
    }
    
    private func setupVoiceProcessor() {
        DebugLogger.log("[AlarmOverlay] Setting up VoiceProcessor")
        voiceProcessor.onAutoStop = { reason in
            DebugLogger.log("[AlarmOverlay] VoiceProcessor AutoStop: \(reason)")
            stopRecording()
        }
    }
    
    private func handleStateChange(_ newState: ConversationManager.State) {
        if case .done(let success) = newState, success {
             // Trigger Success Animation
             withAnimation(.easeInOut(duration: 1.5)) {
                 scaleEffect = 5.0 // Fill screen
                 opacityEffect = 0.0 // Fade out elements
             }
             
             // After animation, StageManager will detect idle state and switch view?
             // Wait, StageManager checks `manager.state != .idle`. 
             // We need to set state to idle AFTER animation.
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                 manager.reset() // Reset manager to .idle
             }
             return
        }
        
        if case .recording = newState {
            DebugLogger.log("[AlarmOverlay] State -> Recording. Starting VoiceProcessor.")
            
            // Safety: Check application state
            if UIApplication.shared.applicationState != .active {
                DebugLogger.log("[AlarmOverlay] App not active, deferring recording until foreground...")
                withAnimation { isRetryPending = true }
                return
            }
            
            Task {
                do {
                     let config = UserConfig.current.behavior
                     if config.autoContinueDelaySeconds > 0 {
                         try await Task.sleep(nanoseconds: UInt64(config.autoContinueDelaySeconds * 1_000_000_000))
                     }
                    
                    DebugLogger.log("[AlarmOverlay] Starting recording stream...")
                    let stream = try voiceProcessor.startRecording()
                    withAnimation { isRetryPending = false }
                    await manager.startListening(stream: stream) 
                } catch {
                    DebugLogger.log("[AlarmOverlay] Failed to start recording: \(error)")
                    // If session failed, schedule retry
                    let nsError = error as NSError
                    if nsError.domain == NSOSStatusErrorDomain && nsError.code == 561015905 {
                        DebugLogger.log("[AlarmOverlay] Session activation failed. Scheduling retry on foreground.")
                        withAnimation { isRetryPending = true }
                    }
                }
            }
        } else if case .offlineFallback = newState {
            if voiceProcessor.isRecording {
                voiceProcessor.stopRecording()
            }
            withAnimation { isRetryPending = false }
        } else if case .evaluating = newState {
            // Stop recording visual if we moved to thinking
             if voiceProcessor.isRecording {
                 voiceProcessor.stopRecording()
             }
        }
    }
    
    private func stopRecording() {
        DebugLogger.log("[AlarmOverlay] Stopping recording manually.")
        voiceProcessor.stopRecording()
        manager.stopListening()
    }
}
