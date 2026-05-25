import Foundation
import Speech
import AVFoundation

/// A service that handles real-time speech transcription using Apple's Speech framework.
/// Downgraded to use SFSpeechRecognizer exclusively due to hardware limitations on iPhone 11 (missing SpeechTranscriber assets).
final class AppleSpeechService {
    
    // Legacy / Primary Recognizer
    private let legacyRecognizer = SFSpeechRecognizer(locale: .current)
    private var legacyRequest: SFSpeechAudioBufferRecognitionRequest?
    private var legacyTask: SFSpeechRecognitionTask?
    
    init() {}
    
    /// Starts the speech analysis pipeline and returns a stream of results.
    /// - Parameter inputStream: A stream of audio buffers from the microphone/engine.
    func start(inputStream: AsyncStream<AVAudioPCMBuffer>) -> AsyncStream<AppleSpeechResult> {
        DebugLogger.log("[AppleSpeechService] Starting speech analysis (Legacy Mode)...")
        
        return AsyncStream { continuation in
            Task {
                await self.runRecognition(inputStream: inputStream, continuation: continuation)
            }
        }
    }
    
    private func runRecognition(inputStream: AsyncStream<AVAudioPCMBuffer>, continuation: AsyncStream<AppleSpeechResult>.Continuation) async {
        guard let recognizer = legacyRecognizer, recognizer.isAvailable else {
            DebugLogger.log("[AppleSpeechService] SFSpeechRecognizer not available")
            continuation.finish()
            return
        }
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.legacyRequest = request
        
        legacyTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard self != nil else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                // Heuristic: Use first segment confidence if available
                let confidence = result.bestTranscription.segments.first?.confidence ?? 0.0
                let isFinal = result.isFinal
                
                let speechResult = AppleSpeechResult(
                    text: text,
                    confidence: Double(confidence),
                    isFinal: isFinal
                )
                continuation.yield(speechResult)
            }
            
            if let error = error {
                // Ignore code 301 (request cancelled) and 1110 (no speech detected) as they are often expected
                let nsError = error as NSError
                // kLSRErrorDomain logic might be needed, but SFSpeechErrorDomain is standard
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    DebugLogger.log("[AppleSpeechService] Request cancelled (expected).")
                } else if nsError.code == 203 || nsError.localizedDescription.contains("Retry") {
                    // Retryable error? For now just log
                    DebugLogger.log("[AppleSpeechService] Recognition error (retryable?): \(error)")
                } else {
                    DebugLogger.log("[AppleSpeechService] Recognition error: \(error)")
                }
                continuation.finish()
            }
            
            if result?.isFinal == true {
                continuation.finish()
            }
        }
        
        // Feed audio to request
        for await buffer in inputStream {
            self.legacyRequest?.append(buffer)
        }
        
        DebugLogger.log("[AppleSpeechService] Input stream ended.")
        self.legacyRequest?.endAudio()
    }
    
    func stop() {
        DebugLogger.log("[AppleSpeechService] Stop called")
        legacyRequest?.endAudio()
        legacyTask?.cancel()
        legacyRequest = nil
        legacyTask = nil
    }
}

// Internal result structure
struct AppleSpeechResult {
    let text: String
    let confidence: Double
    let isFinal: Bool
}
