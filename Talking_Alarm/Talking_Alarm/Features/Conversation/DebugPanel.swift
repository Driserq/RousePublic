import SwiftUI

struct DebugPanel: View {
    let manager: ConversationManager
    let voiceProcessor: VoiceProcessor
    let config: AppBehaviorConfig
    
    @State private var isExpanded = false
    @State private var animationHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Debug toggle button
            Button(action: toggleDebug) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text("Debug Info")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(manager.debugLog.count) logs")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Expandable debug content
            if isExpanded {
                VStack(spacing: 16) {
                    // Current status section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Status")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                        
                        // Status items removed - they were the gray pills
                    }
                    .padding(.horizontal, 16)
                    
                    // Recording info section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recording Info")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                        
                        // Recording status items removed - they were the gray pills
                    }
                    .padding(.horizontal, 16)
                    
                    // Transcript section
                    if config.showTranscripts && !manager.lastTranscript.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last Transcript")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.8))
                                .textCase(.uppercase)
                            
                            Text(manager.lastTranscript)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Debug log section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Debug Log")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.8))
                            .textCase(.uppercase)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(manager.debugLog.enumerated()), id: \.offset) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(entry.offset + 1)")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.4))
                                            .frame(width: 20, alignment: .leading)
                                        
                                        Text(entry.element)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.6))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Computed Properties
    
    private var stateString: String {
        switch manager.state {
        case .idle: return "Idle"
        case .preparing: return "Preparing"
        case .speaking: return "Speaking"
        case .recording: return "Recording"
        case .evaluating: return "Evaluating"
        case .offlineFallback: return "Offline Fallback"
        case .playingGoodLuck: return "Good Luck"
        case .done: return "Done"
        }
    }
    
    private var stateColor: Color {
        switch manager.state {
        case .idle: return .gray
        case .preparing: return .orange
        case .speaking: return .blue
        case .recording: return .green
        case .evaluating: return .orange
        case .offlineFallback: return .orange
        case .playingGoodLuck: return .green
        case .done: return .purple
        }
    }
    
    private var confidenceColor: Color {
        if manager.lastConfidence >= 0.8 { return .green }
        if manager.lastConfidence >= 0.6 { return .yellow }
        return .red
    }
    
    private var recordingStateString: String {
        switch voiceProcessor.recordingState {
        case .listening: return "Listening"
        case .warning: return "Warning"
        case .autoStopping: return "Stopping"
        }
    }
    
    private var recordingStateColor: Color {
        switch voiceProcessor.recordingState {
        case .listening: return .green
        case .warning: return .orange
        case .autoStopping: return .red
        }
    }
    
    // MARK: - Actions
    
    private func toggleDebug() {
        withAnimation {
            isExpanded.toggle()
        }
    }
}

// MARK: - Status Item Component (Removed - was the gray pills)

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            DebugPanel(
                manager: ConversationManager(
                    backend: .shared,
                    tts: TextToSpeech(elevenLabs: ElevenLabsService()),
                    stt: AppleSpeechService()
                ),
                voiceProcessor: VoiceProcessor(),
                config: AppBehaviorConfig.default
            )
        }
    }
}

