import Foundation

struct ElevenLabsConfig {
    // API Configuration
    let apiKey: String
    let baseURL: String
    let voiceId: String
    let modelId: String
    
    // Voice Settings
    let stability: Double
    let similarityBoost: Double
    let style: Double
    let useSpeakerBoost: Bool
    
    // Audio Quality
    let sampleRate: Int
    let bitDepth: Int
    let channels: Int
    
    // Default Configuration
    static let `default` = ElevenLabsConfig(
        apiKey: AppConfig.shared.elevenLabsKey,
        baseURL: "https://api.elevenlabs.io/v1",
        voiceId: "a4CnuaYbALRvW39mDitg",
        modelId: "eleven_turbo_v2_5",
        stability: 0.3,
        similarityBoost: 0.9,
        style: 0.3,
        useSpeakerBoost: true,
        sampleRate: 44100,
        bitDepth: 16,
        channels: 1
    )
    
    // Alternative configurations for different voice styles
    static let energeticWakeUp = ElevenLabsConfig(
        apiKey: AppConfig.shared.elevenLabsKey,
        baseURL: "https://api.elevenlabs.io/v1",
        voiceId: "a4CnuaYbALRvW39mDitg",
        modelId: "eleven_turbo_v2_5",
        stability: 0.2,        // Lower for more variation/excitement
        similarityBoost: 0.95, // Higher to maintain voice character
        style: 0.9,            // Higher for more expressive/energetic
        useSpeakerBoost: true, // Boost for clarity
        sampleRate: 44100,
        bitDepth: 16,
        channels: 1
    )
    
    static let calmMotivational = ElevenLabsConfig(
        apiKey: AppConfig.shared.elevenLabsKey,
        baseURL: "https://api.elevenlabs.io/v1",
        voiceId: "a4CnuaYbALRvW39mDitg",
        modelId: "eleven_turbo_v2_5",
        stability: 0.7,        // Higher for more consistent tone
        similarityBoost: 0.8,  // Balanced similarity
        style: 0.4,            // Lower for calmer delivery
        useSpeakerBoost: false, // No boost for softer sound
        sampleRate: 44100,
        bitDepth: 16,
        channels: 1
    )
    
    static let fastResponse = ElevenLabsConfig(
        apiKey: AppConfig.shared.elevenLabsKey,
        baseURL: "https://api.elevenlabs.io/v1",
        voiceId: "a4CnuaYbALRvW39mDitg",
        modelId: "eleven_turbo_v2_5",
        stability: 0.4,        // Balanced stability
        similarityBoost: 0.85, // Good voice consistency
        style: 0.3,            // Moderate expressiveness
        useSpeakerBoost: true, // Boost for clarity
        sampleRate: 22050,     // Lower sample rate for faster processing
        bitDepth: 16,
        channels: 1
    )
}

