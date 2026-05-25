import Foundation
import AVFoundation
import Combine

// MARK: - TTS Service for Personalized Wake Messages
final class TTSService: ObservableObject {
    static let shared = TTSService()
    
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0
    @Published var statusMessage = ""
    
    private let personalWakeMessageFileName = "personal-wake-message.m4a"
    private let fallbackSoundFileName = "alarm-fallback-30s.caf"
    
    private init() {}
    
    // MARK: - Main TTS Generation
    
    func generatePersonalWakeMessage(name: String, goal: String) async throws {
        await MainActor.run {
            isGenerating = true
            generationProgress = 0
            statusMessage = "Preparing your personalized message..."
        }
        
        // Generate personalized message with ChatGPT
        await MainActor.run {
            statusMessage = "Generating personalized message with AI..."
            generationProgress = 20
        }
        
        let config = UserConfig.openAI
        var prompt = config.userPromptTemplate
        prompt = prompt.replacingOccurrences(of: "{name}", with: name)
        prompt = prompt.replacingOccurrences(of: "{goal}", with: goal)
        prompt = prompt.replacingOccurrences(of: "{tone}", with: "motivational")
        prompt = prompt.replacingOccurrences(of: "{hours}", with: "8")
        let fullPrompt = "\(config.systemPrompt)\n\n\(prompt)"
        
        do {
            // Use backend for message + audio
            await MainActor.run {
                statusMessage = "Generating with OpenAI TTS..."
                generationProgress = 25
            }

            let result = try await BackendService.shared.generatePersonalMessage(
                systemMessage: config.systemPrompt,
                userMessage: fullPrompt,
                llmConfig: config,
                voice: UserConfig.current.elevenLabs
            )
            let message = result.messageText
            let audioData = try BackendService.shared.decodeBase64Audio(result.audioBase64)

            DebugLogger.log("[TTSService] Generated personalized wake message: '\(message)'")

            await MainActor.run {
                statusMessage = "Converting audio..."
                generationProgress = 60
            }

            let m4aData = try await convertMP3ToM4A(audioData)

            await MainActor.run {
                statusMessage = "Saving audio file..."
                generationProgress = 75
            }

            let fileURL = getPersonalWakeMessageURL()
            try m4aData.write(to: fileURL)
            
            await MainActor.run {
                statusMessage = "Testing audio playback..."
                generationProgress = 90
            }
            
            // Test audio playback
            try await testAudioPlayback(url: fileURL)
            
            await MainActor.run {
                statusMessage = "Personal wake message ready!"
                generationProgress = 100
                isGenerating = false
            }
            
        } catch {
            DebugLogger.log("[TTSService] TTS generation failed: \(error)")
            
            await MainActor.run {
                statusMessage = "Generation failed"
                isGenerating = false
            }
            
            // Re-throw the error instead of falling back to iOS TTS
            throw error
        }
    }
    
    // MARK: - Personalized Message Generation
    
    /// Convert ElevenLabs MP3 data to M4A (<30s) for AlarmKit compatibility
    private func convertMP3ToM4A(_ mp3Data: Data) async throws -> Data {
        let tempMP3URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp3")
        try mp3Data.write(to: tempMP3URL)

        defer { try? FileManager.default.removeItem(at: tempMP3URL) }

        let asset = AVURLAsset(url: tempMP3URL)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TTSAudioError.conversionFailed
        }

        let tempM4AURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        export.outputURL = tempM4AURL
        export.outputFileType = .m4a

        // Clamp to <30 seconds to avoid fallback to default sound
        let maxSeconds = 29.0
        let durationSeconds: Double
        if #available(iOS 16.0, *) {
            durationSeconds = (try? await asset.load(.duration).seconds) ?? 0
        } else {
            durationSeconds = CMTimeGetSeconds(asset.duration)
        }
        let clamped = min(durationSeconds, maxSeconds)
        export.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: clamped, preferredTimescale: 600))

        // Use modern export API on iOS 18+
        if #available(iOS 18.0, *) {
            try await export.export(to: tempM4AURL, as: .m4a)
        } else {
            await export.export()
            if let error = export.error {
                throw error
            }
        }

        let data = try Data(contentsOf: tempM4AURL)
        try? FileManager.default.removeItem(at: tempM4AURL)
        return data
    }
    
    private func createPlaceholderAudioData() -> Data {
        // Create a simple WAV file header for a short silent audio
        // This is a placeholder - the actual audio will be played by ElevenLabs
        let sampleRate = 44100
        let duration = 0.1 // 100ms
        let numSamples = Int(Double(sampleRate) * duration)
        let numChannels = 1
        let bitsPerSample = 16
        
        let dataSize = numSamples * numChannels * (bitsPerSample / 8)
        let fileSize = 44 + dataSize
        
        var wavData = Data()
        
        // WAV header
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(fileSize - 8).littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt32(sampleRate * numChannels * (bitsPerSample / 8)).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(numChannels * (bitsPerSample / 8)).littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })
        wavData.append("data".data(using: .ascii)!)
        wavData.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        
        // Add silent audio data
        wavData.append(Data(count: dataSize))
        
        return wavData
    }
    
    // MARK: - iOS TTS Fallback
    
    // Fallback logic removed
    
    // MARK: - File Management
    
    private func getPersonalWakeMessageURL() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = libraryPath.appendingPathComponent("Sounds")
        
        // Create Sounds directory if it doesn't exist
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        
        return soundsDirectory.appendingPathComponent(personalWakeMessageFileName)
    }
    
    private func getFallbackSoundURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let soundsDirectory = documentsPath.appendingPathComponent("Sounds")
        
        // Create Sounds directory if it doesn't exist
        try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        
        return soundsDirectory.appendingPathComponent(fallbackSoundFileName)
    }
    
    // MARK: - Audio Testing
    
    private func testAudioPlayback(url: URL) async throws {
        let audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer.prepareToPlay()
        
        // Play a short test (first 2 seconds)
        audioPlayer.currentTime = 0
        audioPlayer.play()
        
        // Wait for 2 seconds
        try await Task.sleep(for: .seconds(2))
        
        audioPlayer.stop()
    }
    
    // MARK: - Regeneration
    
    func regenerateMessage(name: String, goal: String) async throws {
        // Always overwrite existing file
        let fileURL = getPersonalWakeMessageURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        
        try await generatePersonalWakeMessage(name: name, goal: goal)
    }
    
    // MARK: - File Status
    
    func hasPersonalWakeMessage() -> Bool {
        let fileURL = getPersonalWakeMessageURL()
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func getPersonalWakeMessageFileURL() -> URL {
        return getPersonalWakeMessageURL()
    }
    
    // MARK: - Fallback Sound Setup
    
    func setupFallbackSound() async throws {
        let fallbackURL = getFallbackSoundURL()
        
        // If fallback doesn't exist, create a simple 30-second tone
        if !FileManager.default.fileExists(atPath: fallbackURL.path) {
            try await createFallbackSound(at: fallbackURL)
        }
    }
    
    private func createFallbackSound(at url: URL) async throws {
        // Create a simple 30-second alarm tone
        let duration: Double = 30.0
        let sampleRate: Double = 44100
        let frequency: Double = 800 // Hz
        
        let frameCount = UInt32(duration * sampleRate)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        let audioFile = try AVAudioFile(forWriting: url, settings: audioFormat.settings)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let samples = buffer.floatChannelData![0]
        
        for i in 0..<Int(frameCount) {
            let time = Double(i) / sampleRate
            samples[i] = Float(sin(2.0 * Double.pi * frequency * time) * 0.3)
        }
        
        try audioFile.write(from: buffer)
    }
}

// MARK: - TTS Error Types

enum TTSError: Error, LocalizedError {
    case openAIFailed
    case iOSTTSFailed
    case fileWriteFailed
    case audioTestFailed
    
    var errorDescription: String? {
        switch self {
        case .openAIFailed:
            return "OpenAI TTS generation failed"
        case .iOSTTSFailed:
            return "iOS TTS generation failed"
        case .fileWriteFailed:
            return "Failed to write audio file"
        case .audioTestFailed:
            return "Audio playback test failed"
        }
    }
}
