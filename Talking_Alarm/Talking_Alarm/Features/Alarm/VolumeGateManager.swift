import Foundation
import AVFoundation
import UIKit

/// Manages volume checking and speaker output forcing for the Volume Gate feature.
/// Ensures users cannot bypass the wake-up conversation by having their device volume too low.
///
/// The Volume Gate acts as a gatekeeper between the alarm firing and the conversation starting,
/// checking the device's output volume and blocking progress until the user turns it up to an
/// acceptable level (15% or higher).
@Observable
@MainActor
final class VolumeGateManager {
    
    // MARK: - State
    
    /// Represents the current state of the volume gate check.
    enum State: Equatable {
        /// No volume check in progress
        case idle
        /// Currently checking volume
        case checking
        /// Volume too low, overlay displayed. Stores the alarm context for retry scheduling.
        case blocked(alarmId: String, alarmKind: AlarmKind)
        /// Volume check passed, proceeding to conversation
        case passed
    }
    
    // MARK: - Properties
    
    /// The current state of the volume gate.
    private(set) var state: State = .idle
    
    /// The current device output volume (0.0 to 1.0).
    private(set) var currentVolume: Float = 0
    
    /// The minimum acceptable volume level (15%).
    /// Volume must be >= this threshold to pass the gate.
    static let volumeThreshold: Float = 0.15
    
    /// Delay in seconds before a retry alarm fires after user escapes.
    static let retryDelaySeconds: TimeInterval = 30
    
    // MARK: - Volume Observation
    
    /// Polling task for volume monitoring (more reliable than KVO)
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Haptic Feedback
    
    /// Task running the continuous haptic feedback loop.
    private var hapticTask: Task<Void, Never>?
    
    /// Haptic feedback generator for strong impact feedback.
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // MARK: - Callbacks
    
    /// Called when volume crosses the threshold from below to at-or-above.
    /// Used to dismiss the overlay and start the conversation.
    var onVolumeThresholdCrossed: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {
        // Read initial volume
        currentVolume = AVAudioSession.sharedInstance().outputVolume
    }
    
    // MARK: - Audio Session Setup
    
    /// Configures the audio session and forces speaker output.
    ///
    /// Uses .playAndRecord category because overrideOutputAudioPort(.speaker)
    /// only works with this category. This forces audio to the built-in speaker
    /// even when AirPods/Bluetooth are connected.
    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Must use .playAndRecord for overrideOutputAudioPort to work
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Force speaker - this is the key to avoiding AirPods-in-another-room bug
            try audioSession.overrideOutputAudioPort(.speaker)
            
            currentVolume = audioSession.outputVolume
            
            let route = audioSession.currentRoute
            let outputs = route.outputs.map { $0.portType.rawValue }.joined(separator: ", ")
            DebugLogger.log("[VolumeGate] Audio configured. Volume=\(String(format: "%.0f", currentVolume * 100))% Route=[\(outputs)]")
        } catch {
            DebugLogger.log("[VolumeGate] Audio session error: \(error)")
            currentVolume = audioSession.outputVolume
        }
    }
    
    // MARK: - Volume Check
    
    /// Checks if volume is at or above 15% threshold.
    func checkVolume() -> Bool {
        state = .checking
        
        let audioSession = AVAudioSession.sharedInstance()
        currentVolume = audioSession.outputVolume
        
        let passes = currentVolume >= Self.volumeThreshold
        
        if passes {
            state = .passed
            DebugLogger.log("[VolumeGate] Volume OK: \(String(format: "%.0f", currentVolume * 100))%")
        } else {
            DebugLogger.log("[VolumeGate] Volume LOW: \(String(format: "%.0f", currentVolume * 100))%")
        }
        
        return passes
    }
    
    // MARK: - Blocking State Management
    
    /// Starts the blocking state with volume observation.
    ///
    /// Called when volume is below threshold. Sets up polling for
    /// real-time volume changes and stores alarm context for retry scheduling.
    ///
    /// - Parameters:
    ///   - alarmId: The ID of the alarm that triggered the volume check.
    ///   - alarmKind: The kind of alarm (scheduled or nap).
    ///
    /// **Validates: Requirements 4.1, 4.2, 4.3**
    func startBlocking(alarmId: String, alarmKind: AlarmKind) {
        state = .blocked(alarmId: alarmId, alarmKind: alarmKind)
        DebugLogger.log("[VolumeGate] Started blocking for alarm \(alarmId) kind=\(alarmKind.logLabel)")
        
        // Start polling for volume changes (KVO is unreliable)
        startVolumePolling()
    }
    
    /// Stops the blocking state and cleans up resources.
    ///
    /// Called when volume crosses threshold or when the gate is dismissed.
    func stopBlocking() {
        stopVolumePolling()
        state = .idle
        DebugLogger.log("[VolumeGate] Stopped blocking")
    }
    
    // MARK: - Volume Polling
    
    /// Starts polling for volume changes every 200ms.
    /// This is more reliable than KVO which can fire spurious notifications.
    private func startVolumePolling() {
        pollingTask?.cancel()
        
        pollingTask = Task { [weak self] in
            DebugLogger.log("[VolumeGate] Started volume polling")
            
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                
                guard let self else { break }
                guard case .blocked = self.state else { break }
                
                // Read fresh volume from audio session
                let audioSession = AVAudioSession.sharedInstance()
                let newVolume = audioSession.outputVolume
                
                // Update displayed volume
                if abs(newVolume - self.currentVolume) > 0.01 {
                    let oldVolume = self.currentVolume
                    self.currentVolume = newVolume
                    DebugLogger.log("[VolumeGate] Volume: \(String(format: "%.0f", oldVolume * 100))% → \(String(format: "%.0f", newVolume * 100))%")
                }
                
                // Check if volume crossed threshold
                if newVolume >= Self.volumeThreshold {
                    DebugLogger.log("[VolumeGate] Volume crossed threshold! (\(String(format: "%.0f", newVolume * 100))% >= \(String(format: "%.0f", Self.volumeThreshold * 100))%)")
                    self.state = .passed
                    self.onVolumeThresholdCrossed?()
                    break
                }
            }
            
            DebugLogger.log("[VolumeGate] Volume polling ended")
        }
    }
    
    /// Stops the volume polling task.
    private func stopVolumePolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Haptic Feedback
    
    /// Starts continuous haptic feedback to get user's attention.
    ///
    /// Uses a pulsing pattern with heavy impact feedback every 1.5 seconds
    /// to create an annoying but attention-grabbing vibration.
    ///
    /// **Validates: Requirements 3.6, 4.4**
    func startHapticLoop() {
        // Cancel any existing haptic task
        hapticTask?.cancel()
        
        // Prepare the generator for low-latency feedback
        hapticGenerator.prepare()
        
        hapticTask = Task { [weak self] in
            guard let self else { return }
            
            DebugLogger.log("[VolumeGate] Started haptic loop")
            
            while !Task.isCancelled {
                // Trigger heavy impact feedback
                await MainActor.run {
                    self.hapticGenerator.impactOccurred(intensity: 1.0)
                }
                
                // Wait 1.5 seconds before next pulse
                // This creates an annoying but not overwhelming pattern
                do {
                    try await Task.sleep(for: .milliseconds(1500))
                } catch {
                    // Task was cancelled
                    break
                }
            }
            
            DebugLogger.log("[VolumeGate] Haptic loop ended")
        }
    }
    
    /// Stops the haptic feedback loop.
    ///
    /// **Validates: Requirements 4.4**
    func stopHapticLoop() {
        hapticTask?.cancel()
        hapticTask = nil
        DebugLogger.log("[VolumeGate] Stopped haptic loop")
    }
    
    // MARK: - Retry Scheduling
    
    /// Schedules a retry alarm for when the user escapes the volume nag screen.
    ///
    /// Uses `AlarmKitManager.scheduleFixedAlarm()` with a 30-second delay.
    /// The retry alarm ID is saved to `LocalStore.volumeGateRetryAlarmID` and
    /// added to `provisionalRetryAlarmIDs` for proper identity tracking.
    ///
    /// - Parameter alarmKind: The kind of alarm to schedule (affects which sound file is used).
    /// - Returns: The ID of the scheduled retry alarm, or `nil` if scheduling failed.
    ///
    /// **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.9**
    func scheduleVolumeGateRetry(alarmKind: AlarmKind) async -> String? {
        // Cancel any existing volume gate retry first
        await cancelPendingRetry()
        
        let retryDate = Date().addingTimeInterval(Self.retryDelaySeconds)
        let name = UserDefaults.standard.string(forKey: "user_name") ?? "User"
        let goal = UserDefaults.standard.string(forKey: "user_goal") ?? "Wake up"
        
        do {
            let alarmId = try await AlarmKitManager.shared.scheduleFixedAlarm(
                at: retryDate,
                name: name,
                goal: goal,
                kind: alarmKind
            )
            
            // Save the retry alarm ID for tracking
            LocalStore.saveVolumeGateRetryAlarmID(alarmId)
            
            // Add to provisional retry IDs for identity tracking
            LocalStore.addProvisionalRetryAlarmID(alarmId)
            
            DebugLogger.log("[VolumeGate] Scheduled retry alarm at \(retryDate) id=\(alarmId) kind=\(alarmKind.logLabel)")
            return alarmId
        } catch {
            DebugLogger.log("[VolumeGate] Failed to schedule retry alarm: \(error)")
            LocalStore.saveVolumeGateRetryAlarmID(nil)
            return nil
        }
    }
    
    /// Cancels any pending volume gate retry alarm.
    ///
    /// Clears the stored `volumeGateRetryAlarmID` and cancels the alarm via AlarmKitManager.
    ///
    /// **Validates: Requirements 5.10**
    func cancelPendingRetry() async {
        guard let retryId = LocalStore.loadVolumeGateRetryAlarmID() else {
            return
        }
        
        do {
            try await AlarmKitManager.shared.cancelAlarm(idString: retryId)
            LocalStore.removeProvisionalRetryAlarmID(retryId)
            DebugLogger.log("[VolumeGate] Cancelled pending retry alarm: \(retryId)")
        } catch {
            DebugLogger.log("[VolumeGate] Failed to cancel retry alarm: \(error)")
        }
        
        LocalStore.saveVolumeGateRetryAlarmID(nil)
    }
}
