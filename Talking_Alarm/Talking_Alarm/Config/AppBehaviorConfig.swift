import Foundation

struct AppBehaviorConfig {
    // Conversation Flow
    let maxAttempts: Int
    let evaluationDelaySeconds: Double
    let autoContinueDelaySeconds: Double
    
    // Confidence Thresholds
    let confidenceThresholds: [Int: Double]
    let heuristicWeight: Double
    
    // Audio Settings
    let recordingSampleRate: Int
    let recordingChannels: Int
    let recordingBitDepth: Int
    
    // Auto-Stop Recording Settings
    let enableAutoStop: Bool
    let silenceThresholdSeconds: Double
    let maxRecordingDurationSeconds: Double
    let warningDurationSeconds: Double
    let volumeThreshold: Float
    
    // UI Behavior
    let debugModeEnabled: Bool
    let showConfidenceScores: Bool
    let showTranscripts: Bool
    
    // Default Configuration
    static let `default` = AppBehaviorConfig(
        maxAttempts: 5,
        evaluationDelaySeconds: 2.0,
        autoContinueDelaySeconds: 0.5,
        confidenceThresholds: [
            1: 0.85,  // First attempt: high threshold
            2: 0.75,  // Second attempt: medium-high
            3: 0.70,  // Third attempt: medium
            4: 0.65,  // Fourth attempt: medium-low
            5: 0.60   // Fifth attempt: low threshold
        ],
        heuristicWeight: 0.3,
        recordingSampleRate: 16000,
        recordingChannels: 1,
        recordingBitDepth: 16,
        enableAutoStop: true,
        silenceThresholdSeconds: 1.2,
        maxRecordingDurationSeconds: 20.0,
        warningDurationSeconds: 15.0,
        volumeThreshold: 0.015,
        debugModeEnabled: true,
        showConfidenceScores: true,
        showTranscripts: true
    )
    
    // Alternative configurations for different user preferences
    static let strict = AppBehaviorConfig(
        maxAttempts: 3,
        evaluationDelaySeconds: 3.0,
        autoContinueDelaySeconds: 1.0,
        confidenceThresholds: [
            1: 0.90,
            2: 0.85,
            3: 0.80
        ],
        heuristicWeight: 0.2,
        recordingSampleRate: 16000,
        recordingChannels: 1,
        recordingBitDepth: 16,
        enableAutoStop: true,
        silenceThresholdSeconds: 0.8,
        maxRecordingDurationSeconds: 15.0,
        warningDurationSeconds: 12.0,
        volumeThreshold: 0.02,
        debugModeEnabled: false,
        showConfidenceScores: false,
        showTranscripts: false
    )
    
    static let lenient = AppBehaviorConfig(
        maxAttempts: 7,
        evaluationDelaySeconds: 1.5,
        autoContinueDelaySeconds: 0.3,
        confidenceThresholds: [
            1: 0.75,
            2: 0.65,
            3: 0.55,
            4: 0.50,
            5: 0.45,
            6: 0.40,
            7: 0.35
        ],
        heuristicWeight: 0.4,
        recordingSampleRate: 16000,
        recordingChannels: 1,
        recordingBitDepth: 16,
        enableAutoStop: true,
        silenceThresholdSeconds: 1.8,
        maxRecordingDurationSeconds: 30.0,
        warningDurationSeconds: 25.0,
        volumeThreshold: 0.01,
        debugModeEnabled: true,
        showConfidenceScores: true,
        showTranscripts: true
    )
    
    static let quickStart = AppBehaviorConfig(
        maxAttempts: 3,
        evaluationDelaySeconds: 1.0,
        autoContinueDelaySeconds: 0.2,
        confidenceThresholds: [
            1: 0.80,
            2: 0.70,
            3: 0.60
        ],
        heuristicWeight: 0.25,
        recordingSampleRate: 8000,
        recordingChannels: 1,
        recordingBitDepth: 16,
        enableAutoStop: true,
        silenceThresholdSeconds: 1.0,
        maxRecordingDurationSeconds: 12.0,
        warningDurationSeconds: 10.0,
        volumeThreshold: 0.02,
        debugModeEnabled: false,
        showConfidenceScores: false,
        showTranscripts: false
    )
    
    // Helper method to get confidence threshold for attempt
    func confidenceThreshold(for attempt: Int) -> Double {
        return confidenceThresholds[attempt] ?? confidenceThresholds[maxAttempts] ?? 0.7
    }
}
