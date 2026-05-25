import Foundation
import AVFoundation

enum RecordingState {
    case listening
    case warning
    case autoStopping
}

enum StopReason {
    case silence
    case maxDuration
    case userRequest
}

enum VoiceProcessorError: Error {
    case invalidInputFormat(String)
}

final class VoiceProcessor: NSObject, ObservableObject {
    private let engine = AVAudioEngine()
    private let config: AppBehaviorConfig
    
    // Stream for consumers
    private var streamContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    
    // Auto-stop monitoring
    private var silenceTimer: Timer?
    private var recordingTimer: Timer?
    private var gracePeriodTimer: Timer?
    private var isGracePeriodActive = false
    
    // Published state for UI updates
    @Published var recordingState: RecordingState = .listening
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentVolume: Float = 0
    
    // Callbacks
    var onAutoStop: ((StopReason) -> Void)?
    var onTimeWarning: (() -> Void)?
    
    var isRecording: Bool {
        return engine.isRunning
    }
    
    init(config: AppBehaviorConfig = UserConfig.current.behavior) {
        self.config = config
        super.init()
    }
    
    deinit {
        stopAllTimers()
    }
    
    /// Starts recording and returns an async stream of audio buffers
    func startRecording() throws -> AsyncStream<AVAudioPCMBuffer> {
        DebugLogger.log("[VoiceProcessor] startRecording called")
        
        // Reset state
        recordingState = .listening
        elapsedTime = 0
        currentVolume = 0
        stopAllTimers()
        
        // Ensure unified session is active (replaces configureForPlayAndRecord)
        DebugLogger.log("[VoiceProcessor] Ensuring unified audio session...")
        try AudioSessionManager.shared.configureUnifiedConversationSession()
        
        // Setup Stream
        let stream = AsyncStream<AVAudioPCMBuffer> { continuation in
            self.streamContinuation = continuation
        }
        
        // Setup Engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Strict Format Check: Validate format before installing tap
        if format.sampleRate == 0 || format.channelCount == 0 {
            let errorMsg = "Invalid input format: \(format.channelCount) ch, \(format.sampleRate) Hz"
            DebugLogger.log("[VoiceProcessor] CRITICAL: \(errorMsg)")
            // Abort immediately instead of crashing
            throw VoiceProcessorError.invalidInputFormat(errorMsg)
        }
        
        // Remove existing tap if any
        inputNode.removeTap(onBus: 0)
        
        DebugLogger.log("[VoiceProcessor] Installing tap on input node. Format: \(format)")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // 1. Yield to stream
            self.streamContinuation?.yield(buffer)
            
            // 2. Calculate volume for UI and silence detection
            self.processVolume(buffer: buffer)
        }
        
        DebugLogger.log("[VoiceProcessor] Starting engine...")
        try engine.start()
        DebugLogger.log("[VoiceProcessor] Engine started")
        
        if config.enableAutoStop {
            startDurationMonitoring()
            // Silence monitoring is triggered via processVolume, but we add a grace period first
            startGracePeriod()
        }
        
        return stream
    }
    
    func stopRecording() {
        DebugLogger.log("[VoiceProcessor] stopRecording called")
        stopAllTimers()
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset() // Reset engine to clear graph and avoid !pri errors on restart
        
        streamContinuation?.finish()
        streamContinuation = nil
        
        DebugLogger.log("[VoiceProcessor] Recording stopped")
    }
    
    // MARK: - Audio Processing
    
    private func processVolume(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let volume = max(0.0, rms) // Simple RMS volume
        
        DispatchQueue.main.async {
            self.currentVolume = volume
            
            // Log volume periodically if above zero to confirm input
            if volume > 0.01 && Int.random(in: 0...50) == 0 {
                DebugLogger.log("[VoiceProcessor] Input detected: vol=\(volume)")
            }
            
            if self.config.enableAutoStop && !self.isGracePeriodActive {
                if volume > self.config.volumeThreshold {
                    self.resetSilenceTimer()
                } else if self.silenceTimer == nil {
                     // Only start if not already running to avoid constant resetting on silence
                     self.startSilenceTimer()
                }
            }
        }
    }
    
    // MARK: - Auto-Stop Implementation
    
    private func startGracePeriod() {
        DebugLogger.log("[VoiceProcessor] Starting grace period (2.0s)")
        isGracePeriodActive = true
        
        DispatchQueue.main.async {
            self.gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                DebugLogger.log("[VoiceProcessor] Grace period ended, enabling silence detection")
                self?.isGracePeriodActive = false
                // Start silence timer immediately after grace period if silence persists
                // (or it will be started by next processVolume call)
            }
        }
    }
    
    private func startDurationMonitoring() {
        DebugLogger.log("[VoiceProcessor] Starting duration monitoring")
        
        DispatchQueue.main.async {
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                guard let self = self else { 
                    timer.invalidate()
                    return 
                }
                
                self.elapsedTime += 1.0
                
                if self.elapsedTime >= self.config.maxRecordingDurationSeconds {
                    DebugLogger.log("[VoiceProcessor] Max duration reached, auto-stopping")
                    self.autoStopRecording(reason: .maxDuration)
                } else if self.elapsedTime >= self.config.warningDurationSeconds && self.recordingState == .listening {
                    DebugLogger.log("[VoiceProcessor] Time warning threshold reached")
                    self.recordingState = .warning
                    self.onTimeWarning?()
                }
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil // Ensure we know it's stopped
    }
    
    private func startSilenceTimer() {
        if silenceTimer != nil { return } // Already counting down
        
        silenceTimer = Timer.scheduledTimer(withTimeInterval: config.silenceThresholdSeconds, repeats: false) { [weak self] _ in
            DebugLogger.log("[VoiceProcessor] Silence threshold reached, auto-stopping")
            self?.autoStopRecording(reason: .silence)
        }
    }
    
    private func autoStopRecording(reason: StopReason) {
        DebugLogger.log("[VoiceProcessor] Auto-stopping recording due to: \(reason)")
        recordingState = .autoStopping
        
        // Small delay to show the state change in UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.onAutoStop?(reason)
        }
    }
    
    private func stopAllTimers() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil
        isGracePeriodActive = false
    }
}
