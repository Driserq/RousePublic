import Foundation
import AVFoundation

@MainActor
final class ConversationManager: ObservableObject {
    private let maxAttempts: Int = 10

    private var conversationSessionID: UInt64 = 0

    private func bumpSession() {
        conversationSessionID &+= 1
    }

    private var preparingWatchdogTask: Task<Void, Never>?

    private var offlineFallbackLoopTask: Task<Void, Never>?
    private let offlineFallbackRepeatDelay: Duration = .seconds(5)

    private var isIdleOrPreparing: Bool {
        switch state {
        case .idle, .preparing:
            return true
        default:
            return false
        }
    }
    enum State: Equatable { 
        case idle
        case preparing(String)
        case speaking(String)
        case recording
        case evaluating(String, Double)
        case offlineFallback(String)
        case playingGoodLuck(String)
        case done(success: Bool)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var attempt: Int = 0
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var lastConfidence: Double = 0
    @Published private(set) var lastThreshold: Double = 0
    @Published private(set) var debugLog: [String] = []
    
    // MARK: - Error Handling State
    @Published var isTextOnlyMode = false
    
    // Audio levels
    @Published var currentAILevel: Float = 0
    
    // Store the successful transcript for the good luck message
    private var successfulTranscript: String = ""
    
    // Track conversation history for the current session
    private var conversationHistory: [String] = []
    
    // Persistent session data
    private var currentGoal: String = ""
    private var sessionDate: Date = Date() // Track when session started for context
    private var currentAlarmKind: AlarmKind = .scheduled
    
    // Pre-loaded message for parallel loading optimization
    private var preloadedMessage: (text: String, audioBase64: String)?
    private var preloadTask: Task<Void, Never>?

    private let backend: BackendService
    private let tts: TextToSpeech
    private let stt: AppleSpeechService

    // Track active listening task
    private var listeningTask: Task<Void, Never>?
    private var isAborting: Bool = false

    init(backend: BackendService = .shared, tts: TextToSpeech, stt: AppleSpeechService) {
        self.backend = backend
        self.tts = tts
        self.stt = stt
        
        // Bind TTS audio levels
        self.tts.onAudioLevelUpdate = { [weak self] level in
            DispatchQueue.main.async {
                self?.currentAILevel = level
            }
        }
    }

    func start(goal: String, alarmKind: AlarmKind = .scheduled) async {
        bumpSession()
        let session = conversationSessionID

        // Guard against double execution
        guard isIdleOrPreparing else {
            log("Start ignored: Conversation already active (state=\(state))")
            return
        }
        
        preparingWatchdogTask?.cancel()
        // IMMEDIATE STATE CHANGE: Force UI to transition to Overlay
        state = .evaluating("Connecting to coach...", 0)
        
        attempt = 0
        successfulTranscript = ""
        conversationHistory.removeAll()
        
        // Save session data
        currentGoal = goal
        sessionDate = Date()
        currentAlarmKind = alarmKind
        
        // Load the welcome message text
        let welcomeText = welcomeMessage(for: alarmKind, goal: goal)
            
        // Inject into history as the start of context
        conversationHistory.append("AI (Alarm): \(welcomeText)")
        
        log("Start conversation. Goal='\(goal)' date=\(sessionDate)")
        
        // --- VIRTUAL TURN: Trigger AI Greeting Immediately ---
        
        // We pass context to the AI but don't show this to the user
        // The AI sees this to understand it's starting the conversation
        lastTranscript = "[SYSTEM: User just stopped the alarm. You're starting the conversation.]"
        
        // Trigger the ConversationTurn
        await decideAndContinue(goal: goal, session: session)
    }

    func beginWakeUI() {
        guard state == .idle else { return }
        state = .preparing("Waking up…")

        preparingWatchdogTask?.cancel()
        let session = conversationSessionID
        preparingWatchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15)) // Extended for parallel loading
            guard let self else { return }
            guard session == self.conversationSessionID else { return }
            if case .preparing = self.state {
                self.log("Preparing watchdog fired; resetting to idle")
                self.state = .idle
            }
        }
    }
    
    /// Starts preloading the AI message in the background.
    /// Call this immediately after showing the conversation overlay.
    func preloadMessage(goal: String, alarmKind: AlarmKind) {
        preloadTask?.cancel()
        preloadedMessage = nil
        
        // Save session data early
        currentGoal = goal
        sessionDate = Date()
        currentAlarmKind = alarmKind
        conversationHistory.removeAll()
        
        let welcomeText = welcomeMessage(for: alarmKind, goal: goal)
        conversationHistory.append("AI (Alarm): \(welcomeText)")
        
        log("Preloading message. Goal='\(goal)' alarmKind=\(alarmKind.logLabel)")
        
        let session = conversationSessionID
        preloadTask = Task { [weak self] in
            guard let self else { return }
            
            // Build the request
            let request = ConversationTurn.build(
                goal: goal,
                date: sessionDate,
                lastTranscript: "[SYSTEM: User just stopped the alarm. You're starting the conversation.]",
                history: conversationHistory,
                alarmKind: alarmKind,
                speechConfidence: 0
            )
            
            do {
                let result = try await backend.performConversationTurn(
                    request: request,
                    voice: UserConfig.current.elevenLabs
                )
                
                guard session == conversationSessionID else { return }
                guard !Task.isCancelled else { return }
                
                // Store the preloaded message
                preloadedMessage = (text: result.replyText, audioBase64: result.replyAudioBase64)
                log("Message preloaded successfully: '\(result.replyText.prefix(50))...'")
            } catch {
                log("Preload failed: \(error)")
                // Will fall back to normal loading in startWithPreloadedMessage
            }
        }
    }
    
    /// Starts the conversation using a preloaded message if available.
    /// If no preloaded message, falls back to normal loading.
    func startWithPreloadedMessage() async {
        bumpSession()
        let session = conversationSessionID
        
        guard isIdleOrPreparing else {
            log("Start ignored: Conversation already active (state=\(state))")
            return
        }
        
        preparingWatchdogTask?.cancel()
        
        // If preload is still running, wait for it to complete (no timeout - it's already in-flight)
        if preloadedMessage == nil, let task = preloadTask {
            log("Waiting for preload to complete...")
            if state == .idle {
                state = .preparing("Connecting to coach...")
            }
            
            // Wait for the preload task to finish (it's already making the API call)
            await task.value
        }
        
        // Check if we have a preloaded message
        if let preloaded = preloadedMessage {
            log("Using preloaded message")
            preloadedMessage = nil
            preloadTask = nil
            
            attempt = 0
            successfulTranscript = ""
            lastTranscript = "[SYSTEM: User just stopped the alarm. You're starting the conversation.]"
            
            conversationHistory.append("AI: \(preloaded.text)")
            
            state = .speaking(preloaded.text)
            LocalStore.savePendingChallengeText(preloaded.text)
            
            do {
                let audioData = try backend.decodeBase64Audio(preloaded.audioBase64)
                try await tts.speak(text: preloaded.text, audioData: audioData)
            } catch {
                handleAudioFailure(error: error)
                state = .done(success: false)
                return
            }
            
            if let url = tts.consumeLastCachedAudioURL() {
                LocalStore.savePendingChallengeAudioPath(url.path)
            }
            
            guard session == conversationSessionID else { return }
            
            try? await Task.sleep(for: .milliseconds(500))
            
            guard session == conversationSessionID else { return }
            state = .recording
        } else {
            // Preload failed (error, not timeout) - fall back to normal start
            log("Preload failed, falling back to normal start")
            preloadTask = nil
            state = .idle
            await start(goal: currentGoal, alarmKind: currentAlarmKind)
        }
    }

    func startWithExistingPrompt(goal: String, prompt: String, alarmKind: AlarmKind = .scheduled) async {
        bumpSession()
        let session = conversationSessionID

        // Guard against double execution
        guard isIdleOrPreparing else {
            log("Start ignored: Conversation already active (state=\(state))")
            return
        }

        preparingWatchdogTask?.cancel()
        state = .evaluating("Connecting to coach...", 0)

        attempt = 0
        successfulTranscript = ""
        conversationHistory.removeAll()

        currentGoal = goal
        sessionDate = Date()
        currentAlarmKind = alarmKind

        let welcomeText = welcomeMessage(for: alarmKind, goal: goal)
        conversationHistory.append("AI (Alarm): \(welcomeText)")
        conversationHistory.append("AI: \(prompt)")

        log("Start conversation (reuse prompt). Goal='\(goal)' date=\(sessionDate)")

        state = .speaking(prompt)
        LocalStore.savePendingChallengeText(prompt)
        do {
            if let path = LocalStore.loadPendingChallengeAudioPath() {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    try await tts.playCachedFile(url: url)
                } else {
                    LocalStore.savePendingChallengeAudioPath(nil)
                    try await tts.speak(prompt)
                }
            } else {
                try await tts.speak(prompt)
            }
        } catch {
            handleAudioFailure(error: error)
            state = .done(success: false)
            return
        }

        if let url = tts.consumeLastCachedAudioURL() {
            LocalStore.savePendingChallengeAudioPath(url.path)
        }

        guard session == conversationSessionID else { return }

        try? await Task.sleep(for: .milliseconds(500))

        guard session == conversationSessionID else { return }
        state = .recording
    }

    // MARK: - Streaming Speech Recognition
    
    func startListening(stream: AsyncStream<AVAudioPCMBuffer>) async {
        let session = conversationSessionID
        lastTranscript = ""
        lastConfidence = 0.0

        isAborting = false
        
        // Start STT Service with audio stream
        // We run the service handling in a separate task so we can consume results here
        
        listeningTask = Task {
            // 1. Start the service pipeline and get results stream
            // The service creates a fresh stream for this session
            let resultsStream = stt.start(inputStream: stream)
            
            // 2. Consume results in real-time
            log("Waiting for transcription results...")
            for await result in resultsStream {
                if Task.isCancelled || self.isAborting {
                    return
                }
                if session != self.conversationSessionID {
                    return
                }
                // FIX: Guard against empty final packets overwriting our data
                // SFSpeechRecognizer can sometimes emit an empty result on cancellation/stop
                if !result.text.isEmpty {
                    self.lastTranscript = result.text
                    self.lastConfidence = result.confidence
                    DebugLogger.log("[ConversationManager] Real-time transcript: '\(result.text)' (conf: \(result.confidence))")
                } else {
                    DebugLogger.log("[ConversationManager] Received empty transcript result")
                }
            }
            
            log("Transcription stream ended. Final text: '\(self.lastTranscript)'")

            if Task.isCancelled || self.isAborting {
                return
            }
            if session != self.conversationSessionID {
                return
            }
            
            // 3. Evaluate
            // Use stored properties
            await self.evaluateReply(goal: currentGoal, session: session)
        }
        
        await listeningTask?.value
    }
    
    // Called when recording stops or stream ends
    func stopListening() {
        log("Stop listening requested")
        stt.stop()
        // The results loop in startListening will exit, triggering evaluateReply
    }

    func cancelCurrentWork() {
        bumpSession()
        isAborting = true
        offlineFallbackLoopTask?.cancel()
        offlineFallbackLoopTask = nil
        listeningTask?.cancel()
        stt.stop()
        tts.stop()
        log("Cancelled current work")
    }

    func endOfflineFallback() {
        offlineFallbackLoopTask?.cancel()
        offlineFallbackLoopTask = nil
        tts.stop()
        state = .done(success: true)
        log("Offline fallback ended by user")
    }

    private func evaluateReply(goal: String, session: UInt64) async {
        guard session == conversationSessionID else { return }

        // Record user transcript to history if it's not empty
        if !lastTranscript.isEmpty {
            conversationHistory.append("User: \(lastTranscript)")
        }

        // Calculate heuristic confidence
        let heuristic = CoherenceHeuristics.analyze(transcript: lastTranscript, goal: goal).total
        // Combine with STT confidence (if available/reliable, otherwise rely on heuristic)
        let confidence = max(lastConfidence, heuristic)
        lastConfidence = confidence
        
        state = .evaluating(lastTranscript, confidence)
        log("Evaluation: conf=\(String(format: "%.2f", confidence)) transcript='\(lastTranscript)'")
        
        // Auto-continue after 1 second (faster than before since we already have the text)
        try? await Task.sleep(for: .seconds(1))
        await decideAndContinue(goal: goal, session: session)
    }

    private func decideAndContinue(goal: String, session: UInt64) async {
        guard session == conversationSessionID else { return }

        // Use AI to properly evaluate if user is actually awake
        // Using new prompt builder
        let request = ConversationTurn.build(
            goal: goal,
            date: sessionDate,
            lastTranscript: lastTranscript,
            history: conversationHistory,
            alarmKind: currentAlarmKind,
            speechConfidence: lastConfidence
        )
        
        do {
            let result = try await performConversationTurnWithConnectivityRetry(
                request: request,
                session: session
            )
            guard session == conversationSessionID else { return }
            log("AI decision: isAwake=\(result.isAwake), reason=\(result.reason)")

            if result.isAwake {
                successfulTranscript = lastTranscript
                state = .playingGoodLuck(result.replyText)
                LocalStore.savePendingChallengeText(nil)
                LocalStore.savePendingChallengeAudioPath(nil)
                let audioData = try backend.decodeBase64Audio(result.replyAudioBase64)
                try await tts.speak(text: result.replyText, audioData: audioData)
                guard session == conversationSessionID else { return }
                state = .done(success: true)
                log("Conversation completed successfully - user is awake!")
                return
            }

            attempt += 1
            conversationHistory.append("AI: \(result.replyText)")

            state = .speaking(result.replyText)
            LocalStore.savePendingChallengeText(result.replyText)

            do {
                let audioData = try backend.decodeBase64Audio(result.replyAudioBase64)
                try await tts.speak(text: result.replyText, audioData: audioData)
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSOSStatusErrorDomain && nsError.code == 561015905 {
                    log("Session activation failed, retrying in 0.5s...")
                    try? await Task.sleep(for: .milliseconds(500))
                    do {
                        let audioData = try backend.decodeBase64Audio(result.replyAudioBase64)
                        try await tts.speak(text: result.replyText, audioData: audioData)
                    } catch {
                        handleAudioFailure(error: error)
                        throw error
                    }
                } else {
                    handleAudioFailure(error: error)
                    throw error
                }
            }

            if let url = tts.consumeLastCachedAudioURL() {
                LocalStore.savePendingChallengeAudioPath(url.path)
            }

            guard session == conversationSessionID else { return }

            if attempt >= maxAttempts {
                state = .done(success: false)
                log("Done with success=false (max attempts)")
                return
            }

            try await Task.sleep(for: .milliseconds(500))

            guard session == conversationSessionID else { return }

            state = .recording
            log("AI says user not awake, continuing conversation")
            return
        } catch {
            if Self.isConnectivityError(error) {
                log("Connectivity failed twice; entering offline fallback: \(error)")
                enterOfflineFallback(session: session)
                return
            }

            log("AI verification failed: \(error)")
            await fallbackDecision(goal: goal, session: session)
        }
    }

    private func performConversationTurnWithConnectivityRetry(
        request: LLMRequest,
        session: UInt64
    ) async throws -> BackendConversationTurnResult {
        do {
            return try await backend.performConversationTurn(
                request: request,
                voice: UserConfig.current.elevenLabs
            )
        } catch {
            guard session == conversationSessionID else { throw error }
            guard Self.isConnectivityError(error) else { throw error }

            log("Connectivity error; retrying once: \(error)")
            try? await Task.sleep(for: .milliseconds(350))

            return try await backend.performConversationTurn(
                request: request,
                voice: UserConfig.current.elevenLabs
            )
        }
    }

    private func enterOfflineFallback(session: UInt64) {
        guard session == conversationSessionID else { return }

        preparingWatchdogTask?.cancel()
        listeningTask?.cancel()
        stt.stop()
        tts.stop()

        offlineFallbackLoopTask?.cancel()
        offlineFallbackLoopTask = nil

        let instructions = "Offline mode. Swipe right, then left, to end."
        state = .offlineFallback(instructions)
        log("Entered offline fallback mode")

        offlineFallbackLoopTask = Task { [weak self] in
            guard let self else { return }
            await self.runOfflineFallbackLoop(session: session)
        }
    }

    private func runOfflineFallbackLoop(session: UInt64) async {
        while true {
            guard !Task.isCancelled else { return }
            guard session == conversationSessionID else { return }
            guard case .offlineFallback = state else { return }

            if let url = offlineFallbackAudioURL(), FileManager.default.fileExists(atPath: url.path) {
                do {
                    try await tts.playCachedFile(url: url)
                } catch {
                    log("Offline fallback audio playback failed: \(error)")
                }
            } else {
                do {
                    try await tts.speakUsingSystemTTS(Self.offlineFallbackPlainText)
                } catch {
                    log("Offline fallback system TTS failed: \(error)")
                }
            }

            try? await Task.sleep(for: offlineFallbackRepeatDelay)
        }
    }

    private func offlineFallbackAudioURL() -> URL? {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsDirectory = libraryPath.appendingPathComponent("Sounds")
        return soundsDirectory.appendingPathComponent("offline-fallback-message.m4a")
    }

    private nonisolated static let offlineFallbackPlainText = "Hey. I'm offline right now, so I can't run the usual wake-up conversation. Give yourself a fair chance to notice I'm still talking to you. Okay. You're awake enough. Get up and start moving toward your goal."

    private nonisolated static let connectivityErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .timedOut
    ]

    nonisolated static func isConnectivityError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return connectivityErrorCodes.contains(urlError.code)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: nsError.code)
            return connectivityErrorCodes.contains(code)
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isConnectivityError(underlying)
        }

        return false
    }
    
    private func fallbackDecision(goal: String, session: UInt64) async {
        guard session == conversationSessionID else { return }
        let threshold = GrindMasterAI.confidenceThreshold(for: attempt)
        lastThreshold = threshold
        let pass = lastConfidence >= threshold
        log("Fallback decision: conf=\(String(format: "%.2f", lastConfidence)) threshold=\(String(format: "%.2f", threshold)) pass=\(pass)")
        
        if pass {
            successfulTranscript = lastTranscript
            state = .done(success: true)
            return
        }

        attempt += 1
        if attempt >= maxAttempts {
            state = .done(success: false)
            log("Done with success=false (max attempts)")
            return
        }
        
        // If we fail fallback, we ask user to try again
        log("Fallback fail: asking user to repeat")
        state = .recording
    }
    
    // MARK: - Error Handling Logic
    
    private func handleAudioFailure(error: Error) {
        log("Audio subsystem failed: \(error)")
        let nsError = error as NSError
        // If session activation keeps failing (561015905), switch to text mode
        if nsError.domain == NSOSStatusErrorDomain && nsError.code == 561015905 {
            DispatchQueue.main.async {
                self.isTextOnlyMode = true
                self.state = .idle // Reset to idle so UI can show a "Tap to Retry" button
            }
        }
    }

    // Helper to reset state for UI flow
    func reset() {
        preparingWatchdogTask?.cancel()
        offlineFallbackLoopTask?.cancel()
        offlineFallbackLoopTask = nil
        tts.stop()
        state = .idle
        attempt = 0
        lastTranscript = ""
        successfulTranscript = ""
        log("Manager reset to idle")
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        debugLog.append("[\(ts)] \(message)")
        if debugLog.count > 100 { debugLog.removeFirst(debugLog.count - 100) }
        DebugLogger.log("[ConversationManager] \(message)")
    }

    private func welcomeMessage(for alarmKind: AlarmKind, goal: String) -> String {
        switch alarmKind {
        case .nap:
            return UserDefaults.standard.string(forKey: "lastNapWelcomeMessage")
                ?? "I played a personalized nap alarm to wake them up for \(goal)."
        case .scheduled:
            return UserDefaults.standard.string(forKey: "lastWelcomeMessage")
                ?? "I played a motivational alarm sound encouraging them to wake up for \(goal)."
        }
    }
}
