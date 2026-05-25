import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private init() {}

    func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func configureForPlayback() throws {
        // In the new unified session model, we don't switch categories. 
        // We just ensure we are in playAndRecord/defaultToSpeaker.
        DebugLogger.log("[AudioSessionManager] configureForPlayback requested -> routing to Unified Conversation Mode")
        try configureUnifiedConversationSession()
    }

    func configureForPlayAndRecord() throws {
        DebugLogger.log("[AudioSessionManager] configureForPlayAndRecord requested -> routing to Unified Conversation Mode")
        try configureUnifiedConversationSession()
    }
    
    // Unified Session Configuration: PlayAndRecord + DefaultToSpeaker
    // This supports both loud TTS and recording without category switching errors.
    func configureUnifiedConversationSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Optimization: If already in correct state, don't reconfigure aggressively
        if session.category == .playAndRecord && 
           session.categoryOptions.contains(.defaultToSpeaker) {
            DebugLogger.log("[AudioSessionManager] Session already in Unified Mode. Ensuring active state.")
            do {
                try session.setActive(true, options: [])
            } catch {
                let nsError = error as NSError
                // 561015905 = AVAudioSessionErrorCodeCannotStartPlaying / Session activation failed
                // If the session is already running (e.g. from Alarm sound), this error is harmless here
                if nsError.code == 561015905 {
                    DebugLogger.log("[AudioSessionManager] Session activation failed (potential race with AlarmKit): \(error.localizedDescription)")
                    // IMPORTANT: If we are about to use the microphone (which we are in Unified Mode),
                    // we CANNOT assume this is harmless if the input hardware is not available.
                    // However, we propagate the error up so VoiceProcessor can catch it and retry.
                    throw error
                } else {
                    throw error
                }
            }
            return
        }
        
        DebugLogger.log("[AudioSessionManager] Setting up Unified Conversation Session...")
        try session.setCategory(
            .playAndRecord,
            mode: .default, // Use .default instead of .voiceChat to avoid gating microphone input on some devices/simulators
            options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP]
        )
        try session.setActive(true, options: [])
        DebugLogger.log("[AudioSessionManager] Unified Session active")
    }

    func deactivate() {
        DebugLogger.log("[AudioSessionManager] Deactivating audio session...")
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        DebugLogger.log("[AudioSessionManager] Audio session deactivated")
    }
}


