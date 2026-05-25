import Foundation
import AVFoundation
import UserNotifications

// MARK: - TTS Audio Manager for Escalating Notifications

class TTSAudioManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = TTSAudioManager()
    
    // MARK: - Properties
    private let backend = BackendService.shared
    private let fileManager = FileManager.default
    
    // MARK: - File Storage
    private var soundsDirectory: URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsURL = libraryURL.appendingPathComponent("Sounds")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: soundsURL.path) {
            try? fileManager.createDirectory(at: soundsURL, withIntermediateDirectories: true)
        }
        
        return soundsURL
    }
    
    // MARK: - Audio File Structure
    struct AudioFile {
        let attempt: Int
        let fileName: String
        let filePath: URL
        let duration: TimeInterval
        let template: MessageTemplate
    }
    
    // MARK: - Public Methods
    
    /// Generate all 4 escalating TTS messages during onboarding in a SINGLE file
    /// with SSML breaks for AlarmKit
    func generateConsolidatedWakeMessage(userGoal: String, personality: String) async throws -> URL {
        DebugLogger.log("[TTSAudioManager] Starting consolidated generation for goal: \(userGoal)")
        
        // 1. Generate consolidated prompt from AlarmMessageTemplates
        let consolidatedPrompt = createConsolidatedPrompt(userGoal: userGoal, personality: personality, isNap: false)
        
        DebugLogger.log("[TTSAudioManager] Generated consolidated prompt: \(consolidatedPrompt.prefix(100))...")
        
        let result = try await backend.generateConsolidatedWakeMessage(
            goal: userGoal,
            personality: personality,
            isNap: false,
            llmConfig: UserConfig.current.openAI,
            voice: UserConfig.current.elevenLabs
        )
        let generatedText = result.ssmlText
        DebugLogger.log("[TTSAudioManager] OpenAI generated text (raw): \(generatedText.prefix(100))...")

        UserDefaults.standard.set(generatedText, forKey: "lastWelcomeMessage")

        DebugLogger.log("[TTSAudioManager] Received audio from backend")
        let audioData = try backend.decodeBase64Audio(result.audioBase64)
        
        // 4. Convert to M4A (allowing long duration for this specific file)
        let m4aData = try await convertToWAV(audioData: audioData, allowLongDuration: true)
        
        // 5. Save to Library/Sounds/personal-wake-message.m4a
        let finalURL = getPersonalWakeMessageURL()
        
        // Remove existing if any
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        
        try m4aData.write(to: finalURL)
        DebugLogger.log("[TTSAudioManager] Saved consolidated audio to: \(finalURL.path)")
        
        return finalURL
    }

    func generateConsolidatedNapMessage(userGoal: String, personality: String) async throws -> URL {
        DebugLogger.log("[TTSAudioManager] Starting nap generation for goal: \(userGoal)")

        let consolidatedPrompt = createConsolidatedPrompt(userGoal: userGoal, personality: personality, isNap: true)

        DebugLogger.log("[TTSAudioManager] Generated nap prompt: \(consolidatedPrompt.prefix(100))...")

        let result = try await backend.generateConsolidatedWakeMessage(
            goal: userGoal,
            personality: personality,
            isNap: true,
            llmConfig: UserConfig.current.openAI,
            voice: UserConfig.current.elevenLabs
        )
        let generatedText = result.ssmlText
        DebugLogger.log("[TTSAudioManager] OpenAI generated nap text (raw): \(generatedText.prefix(100))...")

        UserDefaults.standard.set(generatedText, forKey: "lastNapWelcomeMessage")

        DebugLogger.log("[TTSAudioManager] Received nap audio from backend")
        let audioData = try backend.decodeBase64Audio(result.audioBase64)

        let m4aData = try await convertToWAV(audioData: audioData, allowLongDuration: true)

        let finalURL = getPersonalNapMessageURL()

        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }

        try m4aData.write(to: finalURL)
        DebugLogger.log("[TTSAudioManager] Saved nap audio to: \(finalURL.path)")

        return finalURL
    }

    /// Generate a single offline fallback message during onboarding.
    ///
    /// This is used when the device has no internet and we can't run the wake conversation.
    /// The generated audio is saved locally and can be replayed without network access.
    func generateOfflineFallbackMessage(userGoal: String, personality: String) async throws -> URL {
        DebugLogger.log("[TTSAudioManager] Starting offline fallback message generation for goal: \(userGoal)")

        let prompt = createOfflineFallbackPrompt(userGoal: userGoal)

        let result = try await backend.generatePersonalMessage(
            systemMessage: "You are \(personality).",
            userMessage: prompt,
            llmConfig: UserConfig.current.openAI,
            voice: UserConfig.current.elevenLabs
        )

        let ssmlText = result.messageText
        UserDefaults.standard.set(ssmlText, forKey: "lastOfflineFallbackMessage")
        DebugLogger.log("[TTSAudioManager] Generated offline fallback SSML (raw): \(ssmlText.prefix(120))...")

        let audioData = try backend.decodeBase64Audio(result.audioBase64)
        let m4aData = try await convertToWAV(audioData: audioData, allowLongDuration: true)

        let finalURL = getOfflineFallbackMessageURL()
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        try m4aData.write(to: finalURL)
        DebugLogger.log("[TTSAudioManager] Saved offline fallback audio to: \(finalURL.path)")

        return finalURL
    }
    
    // MARK: - Private Methods
    
    private func createConsolidatedPrompt(userGoal: String, personality: String, isNap: Bool) -> String {
        var prompt = "You are \(personality). Generate a sequence of 4 escalating wake-up messages.\n"
        prompt += "Output ONLY the raw text for the TTS engine. Do not include labels like 'Attempt 1' or 'Message:'.\n"
        prompt += "Separate each message EXACTLY with this tag: <break time=\"6.0s\" />\n"
        prompt += "Ensure the output is clean text and SSML tags only.\n\n"
        
        for i in 1...4 {
            let template = isNap ? AlarmMessageTemplates.getNapTemplate(for: i) : AlarmMessageTemplates.getTemplate(for: i)
            if let template {
                // Strip the generic persona instruction to avoid repetition, keep the specific tone/content instructions
                let specificInstruction = template.prompt
                    .replacingOccurrences(of: "You are [PERSONALITY_TYPE]. ", with: "")
                    .replacingOccurrences(of: "Generate a ", with: "Message \(i): Generate a ")
                
                prompt += "\(specificInstruction)\n"
            }
        }
        
        prompt += "\nExample output format:\n"
        prompt += "Good morning [goal]... <break time=\"6.0s\" /> Come on, wake up... <break time=\"6.0s\" /> ...\n"
        prompt += "Replace [USER_GOAL] with: \(userGoal)"
        
        return prompt
    }

    private func createOfflineFallbackPrompt(userGoal: String) -> String {
        var prompt = "Create ONE short wake-up fallback message to play when the app cannot reach the internet to run the normal wake conversation.\n\n"
        prompt += "User goal: \(userGoal)\n\n"
        prompt += "Hard requirements:\n"
        prompt += "- Output ONLY SSML text (no JSON, no markdown, no quotes, no labels).\n"
        prompt += "- Do NOT wrap in <speak>.\n"
        prompt += "- Include exactly one <break time=\"3.0s\" />.\n"
        prompt += "- Keep it light, self-aware, and motivating; do not be mean.\n"
        prompt += "- Mention you're offline and can't run the usual conversation/verification.\n"
        prompt += "- Optionally include a playful line about wishing you could check the front camera, but do not imply you actually can.\n"
        prompt += "- Spoken length: ~15–25 seconds.\n"
        prompt += "- End with a clear command to get up and start moving toward the goal.\n"
        return prompt
    }
    
    private func getPersonalWakeMessageURL() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = libraryPath.appendingPathComponent("Sounds")
        
        if !FileManager.default.fileExists(atPath: soundsDirectory.path) {
            try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        }
        
        return soundsDirectory.appendingPathComponent("personal-wake-message.m4a")
    }

    private func getPersonalNapMessageURL() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = libraryPath.appendingPathComponent("Sounds")

        if !FileManager.default.fileExists(atPath: soundsDirectory.path) {
            try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        }

        return soundsDirectory.appendingPathComponent("personal-nap-message.m4a")
    }

    private func getOfflineFallbackMessageURL() -> URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = libraryPath.appendingPathComponent("Sounds")

        if !FileManager.default.fileExists(atPath: soundsDirectory.path) {
            try? FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        }

        return soundsDirectory.appendingPathComponent("offline-fallback-message.m4a")
    }

    /// Generate all 4 escalating TTS messages during onboarding (DEPRECATED - Use generateConsolidatedWakeMessage)
    func generateEscalatingMessages(userGoal: String, personality: String) async -> [AudioFile] {
        DebugLogger.log("[TTSAudioManager] Starting generation of escalating messages for goal: \(userGoal)")
        
        var generatedFiles: [AudioFile] = []
        
        for attempt in 1...4 {
            do {
                let audioFile = try await generateMessage(for: attempt, userGoal: userGoal, personality: personality)
                generatedFiles.append(audioFile)
                DebugLogger.log("[TTSAudioManager] Generated attempt \(attempt): \(audioFile.fileName)")
            } catch {
                DebugLogger.log("[TTSAudioManager] Failed to generate attempt \(attempt): \(error)")
                // Continue with other attempts even if one fails
            }
        }
        
        DebugLogger.log("[TTSAudioManager] Generated \(generatedFiles.count)/4 escalating messages")
        return generatedFiles
    }
    
    /// Get existing audio file for a specific attempt
    func getAudioFile(for attempt: Int) async -> AudioFile? {
        guard let template = AlarmMessageTemplates.getTemplate(for: attempt) else { return nil }
        
        let filePath = soundsDirectory.appendingPathComponent(template.fileName)
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            DebugLogger.log("[TTSAudioManager] Audio file not found for attempt \(attempt)")
            return nil
        }
        
        // Get file duration
        let duration = await getAudioDuration(filePath: filePath)
        
        return AudioFile(
            attempt: attempt,
            fileName: template.fileName,
            filePath: filePath,
            duration: duration,
            template: template
        )
    }
    
    /// Check if all escalating messages are generated
    func areEscalatingMessagesReady() async -> Bool {
        for attempt in 1...4 {
            if await getAudioFile(for: attempt) == nil {
                return false
            }
        }
        return true
    }
    
    /// Get the audio file URL for a specific attempt (for notifications)
    func getEscalatingAlarmSoundURL(forAttempt attempt: Int) -> URL? {
        guard let template = AlarmMessageTemplates.getTemplate(for: attempt) else { return nil }
        let filePath = soundsDirectory.appendingPathComponent(template.fileName)
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            DebugLogger.log("[TTSAudioManager] Audio file not found for attempt \(attempt) at \(filePath.path)")
            return nil
        }
        
        return filePath
    }
    
    // MARK: - Private Methods
    
    private func generateMessage(for attempt: Int, userGoal: String, personality: String) async throws -> AudioFile {
        guard let template = AlarmMessageTemplates.getTemplate(for: attempt) else {
            throw TTSAudioError.invalidAttempt(attempt)
        }
        
        // Generate prompt with user data
        guard let prompt = AlarmMessageTemplates.generatePrompt(for: attempt, userGoal: userGoal, personality: personality) else {
            throw TTSAudioError.promptGenerationFailed
        }
        
        DebugLogger.log("[TTSAudioManager] Generating attempt \(attempt) with prompt: \(prompt.prefix(100))...")
        
        let systemPrompt = "You are a motivational accountability partner. Generate a personalized wake-up message that is engaging, direct, and motivating. Keep it conversational and natural."
        let fullPrompt = "\(systemPrompt)\n\n\(prompt)"
        let result = try await backend.generatePersonalMessage(
            systemMessage: systemPrompt,
            userMessage: fullPrompt,
            llmConfig: UserConfig.current.openAI,
            voice: UserConfig.current.elevenLabs
        )
        let generatedText = result.messageText
        DebugLogger.log("[TTSAudioManager] Generated text for attempt \(attempt): \(generatedText.prefix(100))...")

        let audioData = try backend.decodeBase64Audio(result.audioBase64)
        DebugLogger.log("[TTSAudioManager] Generated audio data: \(audioData.count) bytes")
        
        // Convert MP3 to M4A for iOS notifications (better compatibility)
        let m4aData = try await convertToWAV(audioData: audioData)
        DebugLogger.log("[TTSAudioManager] Converted to M4A: \(m4aData.count) bytes")
        
        // Save to file
        let filePath = soundsDirectory.appendingPathComponent(template.fileName)
        try m4aData.write(to: filePath)
        DebugLogger.log("[TTSAudioManager] Saved audio file: \(filePath.path)")
        
        // Get duration of the final saved file
        let duration = await getAudioDuration(filePath: filePath)
        DebugLogger.log("[TTSAudioManager] Final saved audio duration: \(duration) seconds")
        
        return AudioFile(
            attempt: attempt,
            fileName: template.fileName,
            filePath: filePath,
            duration: duration,
            template: template
        )
    }
    
    private func convertToWAV(audioData: Data, allowLongDuration: Bool = false) async throws -> Data {
        // Create temporary MP3 file
        let tempMP3URL = fileManager.temporaryDirectory.appendingPathComponent("temp_audio.mp3")
        try audioData.write(to: tempMP3URL)
        
        defer {
            // Clean up temp file
            try? fileManager.removeItem(at: tempMP3URL)
        }
        
        // Convert MP3 to M4A using AVFoundation (M4A works better for iOS notifications)
        let asset = AVURLAsset(url: tempMP3URL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TTSAudioError.conversionFailed
        }
        
        let tempM4AURL = fileManager.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
        exportSession.outputURL = tempM4AURL
        exportSession.outputFileType = .m4a
        
        // Enforce iOS notification sound limit (< 30 seconds) only if NOT allowLongDuration
        // Use async load for duration on iOS 16+
        let assetDurationSeconds: Double
        if #available(iOS 16.0, *) {
            assetDurationSeconds = (try? await asset.load(.duration).seconds) ?? 0
        } else {
            assetDurationSeconds = CMTimeGetSeconds(asset.duration)
        }
        
        if !allowLongDuration {
            let maxNotificationDurationSeconds: Double = 29.0
            let clampedSeconds = min(assetDurationSeconds, maxNotificationDurationSeconds)
            let clampedDuration = CMTime(seconds: clampedSeconds, preferredTimescale: 600)
            exportSession.timeRange = CMTimeRange(start: .zero, duration: clampedDuration)
        } else {
            // For full consolidated files, use the full duration
            let fullDuration = CMTime(seconds: assetDurationSeconds, preferredTimescale: 600)
            exportSession.timeRange = CMTimeRange(start: .zero, duration: fullDuration)
        }
        
        // Use modern export API on iOS 18+
        if #available(iOS 18.0, *) {
            try await exportSession.export(to: tempM4AURL, as: .m4a)
        } else {
            await exportSession.export()
            if let error = exportSession.error {
                throw error
            }
        }
        
        // Read converted data
        let m4aData = try Data(contentsOf: tempM4AURL)
        
        // Log the converted audio duration
        let convertedAsset = AVURLAsset(url: tempM4AURL)
        let convertedDuration: Double
        if #available(iOS 16.0, *) {
            convertedDuration = (try? await convertedAsset.load(.duration).seconds) ?? 0
        } else {
            convertedDuration = CMTimeGetSeconds(convertedAsset.duration)
        }
        DebugLogger.log("[TTSAudioManager] Converted audio duration: \(convertedDuration) seconds")
        
        // Clean up temp M4A file
        try? fileManager.removeItem(at: tempM4AURL)
        
        return m4aData
    }
    
    private func getAudioDuration(filePath: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: filePath)
        return (try? await asset.load(.duration).seconds) ?? 0
    }
}

// MARK: - Error Types

enum TTSAudioError: Error, LocalizedError {
    case invalidAttempt(Int)
    case promptGenerationFailed
    case conversionFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAttempt(let attempt):
            return "Invalid attempt number: \(attempt)"
        case .promptGenerationFailed:
            return "Failed to generate prompt"
        case .conversionFailed:
            return "Failed to convert audio format"
        case .fileWriteFailed:
            return "Failed to write audio file"
        }
    }
}
