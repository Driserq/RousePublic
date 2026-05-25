import Foundation
import AVFoundation

final class TextToSpeech {
    private let elevenLabs: ElevenLabsService
    var onAudioLevelUpdate: ((Float) -> Void)?

    private var currentPlayer: AVAudioPlayer?

    private var lastCachedAudioURL: URL?

    func consumeLastCachedAudioURL() -> URL? {
        defer { lastCachedAudioURL = nil }
        return lastCachedAudioURL
    }

    private func pendingChallengeCacheURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent("TalkingAlarm", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("pending-challenge.m4a")
    }

    private let iosSynthesizer = AVSpeechSynthesizer()
    private var iosDelegate: SpeechCompletionDelegate?

    init(elevenLabs: ElevenLabsService) {
        self.elevenLabs = elevenLabs
    }

    func speak(_ text: String) async throws {
        DebugLogger.log("[TextToSpeech] Starting to speak: '\(text)'")
        
        // Ensure Unified Session is active (replaces configureForPlayback)
        // This ensures TTS plays loudly through speaker while keeping microphone ready
        DebugLogger.log("[TextToSpeech] Ensuring unified audio session...")
        try AudioSessionManager.shared.configureUnifiedConversationSession()
        DebugLogger.log("[TextToSpeech] Audio session verified")
        
        do {
            DebugLogger.log("[TextToSpeech] Requesting audio synthesis from ElevenLabs...")
            let data = try await elevenLabs.synthesizeToData(text: text)
            DebugLogger.log("[TextToSpeech] Audio synthesis successful, \(data.count) bytes")

            // Cache to disk for fast retry replay.
            do {
                let url = try pendingChallengeCacheURL()
                try data.write(to: url, options: [.atomic])
                lastCachedAudioURL = url
            } catch {
                DebugLogger.log("[TextToSpeech] Failed to cache pending audio: \(error)")
            }

            let player = try AVAudioPlayer(data: data)
            currentPlayer = player
            DebugLogger.log("[TextToSpeech] Player created successfully from audio data")
            
            // Enable metering
            player.isMeteringEnabled = true
            player.prepareToPlay()
            DebugLogger.log("[TextToSpeech] Player prepared to play")
            
            // Play the audio
            DebugLogger.log("[TextToSpeech] Starting playback...")
            guard player.play() else {
                DebugLogger.log("[TextToSpeech] ERROR: Failed to start audio playback")
                throw NSError(domain: "TextToSpeech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback"])
            }
            DebugLogger.log("[TextToSpeech] Playback started successfully")
            
            // Monitor levels while playing
            // We use a simpler loop here instead of a Timer since we are already awaiting completion in a loop
            DebugLogger.log("[TextToSpeech] Waiting for playback to complete...")
            while player.isPlaying {
                if Task.isCancelled {
                    break
                }
                player.updateMeters()
                let averagePower = player.averagePower(forChannel: 0) // dB: -160 to 0
                // Normalize dB to 0.0 - 1.0 (approximate range of interest -40dB to 0dB)
                let normalized = max(0.0, (averagePower + 40) / 40)
                
                await MainActor.run {
                    self.onAudioLevelUpdate?(normalized)
                }
                
                try await Task.sleep(for: .milliseconds(50)) // 0.05 second update rate (20fps)
            }
            DebugLogger.log("[TextToSpeech] Playback completed")
            
            // Clean up
            await MainActor.run {
                self.onAudioLevelUpdate?(0) // Reset level
            }
            player.stop()
            currentPlayer = nil
            DebugLogger.log("[TextToSpeech] Player stopped and cleaned up")
            
        } catch {
            DebugLogger.log("[TextToSpeech] ElevenLabs failed with error: \(error)")
            DebugLogger.log("[TextToSpeech] Falling back to iOS TTS...")
            
            // Fallback to iOS TTS
            try await speakWithiOSTTS(text: text)
        }
    }

    func speak(text: String, audioData: Data) async throws {
        DebugLogger.log("[TextToSpeech] Playing backend audio for text: '\(text)'")

        DebugLogger.log("[TextToSpeech] Ensuring unified audio session...")
        try AudioSessionManager.shared.configureUnifiedConversationSession()
        DebugLogger.log("[TextToSpeech] Audio session verified")

        do {
            let url = try pendingChallengeCacheURL()
            try audioData.write(to: url, options: [.atomic])
            lastCachedAudioURL = url
        } catch {
            DebugLogger.log("[TextToSpeech] Failed to cache pending audio: \(error)")
        }

        let player = try AVAudioPlayer(data: audioData)
        currentPlayer = player
        player.isMeteringEnabled = true
        player.prepareToPlay()

        guard player.play() else {
            throw NSError(domain: "TextToSpeech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback"])
        }

        while player.isPlaying {
            if Task.isCancelled {
                break
            }
            player.updateMeters()
            let averagePower = player.averagePower(forChannel: 0)
            let normalized = max(0.0, (averagePower + 40) / 40)

            await MainActor.run {
                self.onAudioLevelUpdate?(normalized)
            }

            try await Task.sleep(for: .milliseconds(50))
        }

        await MainActor.run {
            self.onAudioLevelUpdate?(0)
        }
        player.stop()
        currentPlayer = nil
    }

    func playCachedFile(url: URL) async throws {
        DebugLogger.log("[TextToSpeech] Playing cached audio: \(url.path)")
        DebugLogger.log("[TextToSpeech] Ensuring unified audio session...")
        try AudioSessionManager.shared.configureUnifiedConversationSession()
        DebugLogger.log("[TextToSpeech] Audio session verified")

        let player = try AVAudioPlayer(contentsOf: url)
        currentPlayer = player
        player.isMeteringEnabled = true
        player.prepareToPlay()

        guard player.play() else {
            throw NSError(domain: "TextToSpeech", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio playback"])
        }

        DebugLogger.log("[TextToSpeech] Waiting for playback to complete...")
        while player.isPlaying {
            if Task.isCancelled {
                break
            }
            player.updateMeters()
            let averagePower = player.averagePower(forChannel: 0)
            let normalized = max(0.0, (averagePower + 40) / 40)
            await MainActor.run { self.onAudioLevelUpdate?(normalized) }
            try await Task.sleep(for: .milliseconds(50))
        }

        await MainActor.run { self.onAudioLevelUpdate?(0) }
        player.stop()
        currentPlayer = nil
        DebugLogger.log("[TextToSpeech] Playback completed")
    }

    /// System-only TTS path that never hits the network.
    /// Used for offline fallback when no prerecorded audio is available.
    func speakUsingSystemTTS(_ text: String) async throws {
        DebugLogger.log("[TextToSpeech] Speaking using system TTS (offline)")
        try AudioSessionManager.shared.configureUnifiedConversationSession()
        try await speakWithiOSTTS(text: text)
    }
    
    func stop() {
        currentPlayer?.stop()
        currentPlayer = nil
        iosSynthesizer.stopSpeaking(at: .immediate)
    }

    private func speakWithiOSTTS(text: String) async throws {
        DebugLogger.log("[TextToSpeech] Using iOS TTS fallback")
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure voice settings for wake-up urgency
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5  // Slightly slower for clarity
        utterance.pitchMultiplier = 1.1  // Slightly higher pitch for energy
        utterance.volume = 1.0
        
        DebugLogger.log("[TextToSpeech] Starting iOS TTS playback...")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let lock = NSLock()
            var finished = false

            func finishOnce(_ result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true

                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let delegate = SpeechCompletionDelegate(
                onFinish: { finishOnce(.success(())) },
                onCancel: { finishOnce(.failure(NSError(domain: "TextToSpeech", code: -2, userInfo: [NSLocalizedDescriptionKey: "iOS TTS cancelled"])) ) }
            )
            self.iosDelegate = delegate
            self.iosSynthesizer.delegate = delegate

            self.iosSynthesizer.speak(utterance)

            Task {
                try? await Task.sleep(for: .seconds(15))
                finishOnce(.failure(NSError(domain: "TextToSpeech", code: -3, userInfo: [NSLocalizedDescriptionKey: "iOS TTS timeout"])) )
            }
        }
        
        DebugLogger.log("[TextToSpeech] iOS TTS playback completed")
    }
}

// Helper class to detect when speech is complete
private class SpeechCompletionDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: () -> Void
    private let onCancel: () -> Void
    
    init(onFinish: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onFinish = onFinish
        self.onCancel = onCancel
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onCancel()
    }
}


