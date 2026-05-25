import Foundation
import AVFoundation

// MARK: - Media-based Alarm Engine

final class MediaAlarmEngine: NSObject {
    static let shared = MediaAlarmEngine()

    // MARK: - Internal State
    private let audioSessionManager = AudioSessionManager.shared
    private let ttsAudioManager = TTSAudioManager.shared
    private let activityManager = EscalatingAlarmActivityManager.shared

    private var inputEngine: AVAudioEngine?
    private var player: AVAudioPlayer?
    private var fireTimer: DispatchSourceTimer?
    private var escalationTimers: [DispatchSourceTimer] = []

    private var liveActivityId: String?
    private var isActive: Bool = false
    private var currentAttempt: Int = 0

    // Intervals used to escalate attempts (in seconds)
    private let productionIntervals: [TimeInterval] = [0, 45, 90, 135]
    private let testIntervals: [TimeInterval] = [0, 20, 40, 65]

    // MARK: - Public API
    /// Starts a media-based alarm session. Keeps an audio session alive using microphone capture until alarm fires, then plays escalating media.
    func startSession(alarmDate: Date, soundURL: URL?, liveActivityOn: Bool) async {
        guard !isActive else { return }
        isActive = true
        currentAttempt = 0

        // Start Live Activity if requested
        if liveActivityOn {
            liveActivityId = await activityManager.startLiveActivity(name: UserDefaults.standard.string(forKey: "user_name") ?? "", goal: UserDefaults.standard.string(forKey: "user_goal") ?? "")
        }

        // Configure session for overnight tracking (microphone keeps session alive)
        do {
            // Request mic permission if needed
            let granted = await audioSessionManager.requestMicrophonePermission()
            if !granted { DebugLogger.log("[MediaAlarmEngine] Microphone permission not granted; media alarm may not sustain in background") }

            try audioSessionManager.configureForPlayAndRecord()
            startInputKeepAlive()
        } catch {
            DebugLogger.log("[MediaAlarmEngine] Failed to configure play-and-record session: \(error)")
        }

        // Schedule fire timer
        scheduleFire(at: alarmDate, initialSoundURL: soundURL)
    }

    /// Stops the media alarm session; stops playback, ends Live Activity, releases audio session.
    func stopSession() {
        cancelTimers()
        stopPlayer()
        stopInputKeepAlive()
        activityEnd()
        audioSessionManager.deactivate()
        isActive = false
        currentAttempt = 0
        DebugLogger.log("[MediaAlarmEngine] Session stopped")
    }

    // MARK: - Internal: Scheduling
    private func scheduleFire(at date: Date, initialSoundURL: URL?) {
        let delay = max(0, date.timeIntervalSinceNow)

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleAlarmFire(initialSoundURL: initialSoundURL)
        }
        timer.resume()
        fireTimer = timer

        // Live Activity countdown update
        if let id = liveActivityId {
            Task { [weak self] in
                guard let self = self else { return }
                await self.activityManager.updateLiveActivity(activityId: id, currentAttempt: 1, timeRemaining: delay)
            }
        }
    }

    private func handleAlarmFire(initialSoundURL: URL?) {
        DebugLogger.log("[MediaAlarmEngine] Alarm fire")
        fireTimer?.cancel(); fireTimer = nil

        // Decide intervals: if short lead, use test intervals; otherwise production
        let intervals = testIntervals

        // Start attempt 1 immediately
        playAttempt(1, preferredURL: initialSoundURL)
        scheduleEscalations(fromAttempt: 2, using: intervals)
    }

    private func scheduleEscalations(fromAttempt start: Int, using intervals: [TimeInterval]) {
        // intervals are cumulative offsets from fire time; attempt1 is 0, attempt2 at intervals[1], etc.
        cancelEscalations()
        for attempt in start...4 {
            let index = attempt - 1
            guard index < intervals.count else { continue }
            let offset = intervals[index]
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
            timer.schedule(deadline: .now() + max(0, offset))
            timer.setEventHandler { [weak self] in
                self?.playAttempt(attempt, preferredURL: nil)
            }
            timer.resume()
            escalationTimers.append(timer)
        }
    }

    // MARK: - Playback & Escalation
    private func playAttempt(_ attempt: Int, preferredURL: URL?) {
        guard isActive else { return }
        currentAttempt = attempt

        // Resolve URL for this attempt
        let url: URL? = preferredURL ?? ttsAudioManager.getEscalatingAlarmSoundURL(forAttempt: attempt)
        guard let soundURL = url else {
            DebugLogger.log("[MediaAlarmEngine] Missing sound for attempt \(attempt)")
            return
        }

        do {
            try audioSessionManager.configureForPlayAndRecord()
        } catch {
            DebugLogger.log("[MediaAlarmEngine] Re-configure session failed: \(error)")
        }

        do {
            stopPlayer()
            player = try AVAudioPlayer(contentsOf: soundURL)
            player?.numberOfLoops = -1
            player?.prepareToPlay()
            player?.volume = 0.05
            player?.play()
            DebugLogger.log("[MediaAlarmEngine] Playing attempt \(attempt): \(soundURL.lastPathComponent)")
            startVolumeRamp(to: 1.0, over: 20.0)
        } catch {
            DebugLogger.log("[MediaAlarmEngine] Failed to start player: \(error)")
        }

        // Live Activity updates
        if let id = liveActivityId {
            Task { [weak self] in
                guard let self = self else { return }
                await self.activityManager.updateLiveActivity(activityId: id, currentAttempt: attempt, timeRemaining: nil)
                if attempt >= 4 {
                    // Optionally end after last attempt when user stops
                }
            }
        }
    }

    private func startVolumeRamp(to target: Float, over seconds: TimeInterval) {
        guard seconds > 0 else { player?.volume = target; return }
        let steps = 40
        let interval = seconds / Double(steps)
        let start = player?.volume ?? 0
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let vol = start + Float(t) * (target - start)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                self?.player?.volume = max(0, min(1, vol))
            }
        }
    }

    // MARK: - Keep-alive microphone input
    private func startInputKeepAlive() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 256, format: format) { _, _ in
            // no-op; tapping the mic keeps the audio session active
        }
        do {
            try engine.start()
            inputEngine = engine
            DebugLogger.log("[MediaAlarmEngine] Input keep-alive started")
        } catch {
            DebugLogger.log("[MediaAlarmEngine] Failed to start input engine: \(error)")
        }
    }

    private func stopInputKeepAlive() {
        inputEngine?.inputNode.removeTap(onBus: 0)
        inputEngine?.stop()
        inputEngine = nil
        DebugLogger.log("[MediaAlarmEngine] Input keep-alive stopped")
    }

    // MARK: - Helpers
    private func stopPlayer() {
        player?.stop()
        player = nil
    }

    private func cancelEscalations() {
        escalationTimers.forEach { $0.cancel() }
        escalationTimers.removeAll()
    }

    private func cancelTimers() {
        fireTimer?.cancel(); fireTimer = nil
        cancelEscalations()
    }

    private func activityEnd() {
        if let id = liveActivityId {
            Task { [weak self] in
                await self?.activityManager.endLiveActivity(activityId: id)
            }
        }
        liveActivityId = nil
    }
}




