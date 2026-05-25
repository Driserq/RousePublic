import Foundation
import AVFoundation

final class ElevenLabsService {
    private let config: ElevenLabsConfig
    
    init(config: ElevenLabsConfig = UserConfig.current.elevenLabs) {
        self.config = config
    }

    func synthesizeToPlayer(text: String) async throws -> AVAudioPlayer {
        if config.apiKey.isEmpty {
            DebugLogger.log("[ElevenLabs] Using fallback - no API key")
            // Fallback: speak via AVSpeechSynthesizer and return a short valid silent WAV player
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.6 // Slightly faster for wake-up urgency
            Task { @MainActor in
                AVSpeechSynthesizer().speak(utterance)
            }

            let wav = Self.makeSilentWav(duration: 0.25, sampleRate: config.sampleRate)
            let player = try AVAudioPlayer(data: wav)
            player.prepareToPlay()
            DebugLogger.log("[ElevenLabs] Fallback player created successfully")
            return player
        }
        
        DebugLogger.log("[ElevenLabs] Synthesizing with voice \(config.voiceId), model \(config.modelId)")
        
        let url = URL(string: "\(config.baseURL)/text-to-speech/\(config.voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
        
        let voiceSettingsDict: [String: Any] = [
            "stability": config.stability,
            "similarity_boost": config.similarityBoost,
            "style": config.style,
            "use_speaker_boost": config.useSpeakerBoost
        ]
        
        let body: [String: Any] = [
            "text": text,
            "model_id": config.modelId,
            "voice_settings": voiceSettingsDict
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            DebugLogger.log("[ElevenLabs] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw HTTPError.httpCode((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        DebugLogger.log("[ElevenLabs] Audio synthesis successful, \(data.count) bytes")
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        DebugLogger.log("[ElevenLabs] Player created successfully from API data")
        return player
    }
    
    func synthesizeToData(text: String) async throws -> Data {
        if config.apiKey.isEmpty {
            DebugLogger.log("[ElevenLabs] Using fallback - no API key")
            // Fallback: return a short silent WAV data
            let wav = Self.makeSilentWav(duration: 0.25, sampleRate: config.sampleRate)
            DebugLogger.log("[ElevenLabs] Fallback audio data created: \(wav.count) bytes")
            return wav
        }
        
        DebugLogger.log("[ElevenLabs] Synthesizing with voice \(config.voiceId), model \(config.modelId)")
        
        let url = URL(string: "\(config.baseURL)/text-to-speech/\(config.voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
        
        let voiceSettingsDict: [String: Any] = [
            "stability": config.stability,
            "similarity_boost": config.similarityBoost,
            "style": config.style,
            "use_speaker_boost": config.useSpeakerBoost
        ]
        
        let body: [String: Any] = [
            "text": text,
            "model_id": config.modelId,
            "voice_settings": voiceSettingsDict
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            DebugLogger.log("[ElevenLabs] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw HTTPError.httpCode((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        DebugLogger.log("[ElevenLabs] Audio synthesis successful, \(data.count) bytes")
        return data
    }
    
    private static func makeSilentWav(duration: Double, sampleRate: Int) -> Data {
        let numSamples = Int(duration * Double(sampleRate))
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = UInt16(numChannels) * bitsPerSample / 8
        var data = Data()
        let pcmData = Data(count: numSamples * Int(bitsPerSample / 8))
        let chunkSize = UInt32(36 + pcmData.count)
        data.append("RIFF".data(using: .ascii)!)
        data.append(chunkSize.littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(numChannels.littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(byteRate.littleEndianData)
        data.append(blockAlign.littleEndianData)
        data.append(bitsPerSample.littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(pcmData.count).littleEndianData)
        data.append(pcmData)
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data { withUnsafeBytes(of: self.littleEndian) { Data($0) } }
}


