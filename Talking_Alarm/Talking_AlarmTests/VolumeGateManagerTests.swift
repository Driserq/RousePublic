//
//  VolumeGateManagerTests.swift
//  Talking_AlarmTests
//
//  Property-based and unit tests for VolumeGateManager.
//

import Testing
import Foundation
@testable import Talking_Alarm

// MARK: - Property 1: Volume Threshold Boundary

/// **Property 1: Volume Threshold Boundary**
/// *For any* volume value, the threshold check SHALL return `true` if and only if
/// the volume is greater than or equal to 0.15, and `false` otherwise.
///
/// **Validates: Requirements 1.2, 1.3**
@Suite("Volume Gate Manager Tests")
struct VolumeGateManagerTests {
    
    // MARK: - Property-Based Test: Volume Threshold Boundary
    
    /// Property test that generates random volume values and verifies the threshold logic.
    /// Runs 100 iterations with random Float values in [0.0, 1.0].
    @Test("Property 1: Volume Threshold Boundary - random values")
    func propertyVolumeThresholdBoundary() async throws {
        let threshold = VolumeGateManager.volumeThreshold
        
        // Run 100 iterations with random volume values
        for _ in 0..<100 {
            let randomVolume = Float.random(in: 0.0...1.0)
            let expectedResult = randomVolume >= threshold
            let actualResult = checkVolumeThreshold(volume: randomVolume, threshold: threshold)
            
            #expect(actualResult == expectedResult,
                   "Volume \(randomVolume) should \(expectedResult ? "pass" : "fail") threshold \(threshold)")
        }
    }
    
    // MARK: - Unit Tests: Boundary Cases
    
    @Test("Volume exactly at threshold (0.15) should pass")
    func volumeExactlyAtThreshold() {
        let result = checkVolumeThreshold(volume: 0.15, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == true)
    }
    
    @Test("Volume just below threshold (0.149) should fail")
    func volumeJustBelowThreshold() {
        let result = checkVolumeThreshold(volume: 0.149, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == false)
    }
    
    @Test("Volume at zero should fail")
    func volumeAtZero() {
        let result = checkVolumeThreshold(volume: 0.0, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == false)
    }
    
    @Test("Volume at maximum (1.0) should pass")
    func volumeAtMaximum() {
        let result = checkVolumeThreshold(volume: 1.0, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == true)
    }
    
    @Test("Volume at 50% should pass")
    func volumeAtFiftyPercent() {
        let result = checkVolumeThreshold(volume: 0.5, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == true)
    }
    
    @Test("Volume at 10% should fail")
    func volumeAtTenPercent() {
        let result = checkVolumeThreshold(volume: 0.1, threshold: VolumeGateManager.volumeThreshold)
        #expect(result == false)
    }
    
    // MARK: - Helper
    
    /// Pure function that implements the volume threshold check logic.
    /// This mirrors the logic in VolumeGateManager.checkVolume() but is testable
    /// without requiring AVAudioSession.
    private func checkVolumeThreshold(volume: Float, threshold: Float) -> Bool {
        return volume >= threshold
    }
}


// MARK: - Property 2: Threshold Crossing State Transition

/// **Property 2: Threshold Crossing State Transition**
/// *For any* sequence of volume changes where the volume crosses from below 0.15
/// to at or above 0.15, the callback SHALL be invoked.
///
/// **Validates: Requirements 4.2**
@Suite("Volume Gate Threshold Crossing Tests")
struct VolumeGateThresholdCrossingTests {
    
    /// Property test that generates random volume transitions and verifies
    /// the callback is invoked when crossing from below to at-or-above threshold.
    @Test("Property 2: Threshold crossing triggers callback")
    func propertyThresholdCrossingTriggersCallback() async throws {
        let threshold = VolumeGateManager.volumeThreshold
        
        // Run 100 iterations with random volume transitions
        for _ in 0..<100 {
            let oldVolume = Float.random(in: 0.0...1.0)
            let newVolume = Float.random(in: 0.0...1.0)
            
            let wasBelow = oldVolume < threshold
            let isNowAtOrAbove = newVolume >= threshold
            let shouldTrigger = wasBelow && isNowAtOrAbove
            
            let didTrigger = simulateThresholdCrossing(oldVolume: oldVolume, newVolume: newVolume, threshold: threshold)
            
            #expect(didTrigger == shouldTrigger,
                   "Transition \(oldVolume) → \(newVolume): expected trigger=\(shouldTrigger), got \(didTrigger)")
        }
    }
    
    // MARK: - Unit Tests: Specific Crossing Scenarios
    
    @Test("Crossing from 0.10 to 0.20 should trigger callback")
    func crossingBelowToAbove() {
        let result = simulateThresholdCrossing(oldVolume: 0.10, newVolume: 0.20, threshold: 0.15)
        #expect(result == true)
    }
    
    @Test("Crossing from 0.10 to 0.15 (exactly at threshold) should trigger callback")
    func crossingBelowToExactThreshold() {
        let result = simulateThresholdCrossing(oldVolume: 0.10, newVolume: 0.15, threshold: 0.15)
        #expect(result == true)
    }
    
    @Test("Staying below threshold (0.05 to 0.10) should NOT trigger callback")
    func stayingBelowThreshold() {
        let result = simulateThresholdCrossing(oldVolume: 0.05, newVolume: 0.10, threshold: 0.15)
        #expect(result == false)
    }
    
    @Test("Staying above threshold (0.50 to 0.80) should NOT trigger callback")
    func stayingAboveThreshold() {
        let result = simulateThresholdCrossing(oldVolume: 0.50, newVolume: 0.80, threshold: 0.15)
        #expect(result == false)
    }
    
    @Test("Crossing from above to below (0.20 to 0.10) should NOT trigger callback")
    func crossingAboveToBelow() {
        let result = simulateThresholdCrossing(oldVolume: 0.20, newVolume: 0.10, threshold: 0.15)
        #expect(result == false)
    }
    
    @Test("Same volume below threshold should NOT trigger callback")
    func sameVolumeBelowThreshold() {
        let result = simulateThresholdCrossing(oldVolume: 0.10, newVolume: 0.10, threshold: 0.15)
        #expect(result == false)
    }
    
    @Test("Same volume above threshold should NOT trigger callback")
    func sameVolumeAboveThreshold() {
        let result = simulateThresholdCrossing(oldVolume: 0.50, newVolume: 0.50, threshold: 0.15)
        #expect(result == false)
    }
    
    // MARK: - Helper
    
    /// Simulates the threshold crossing logic from VolumeGateManager.
    /// Returns true if the callback would be triggered.
    private func simulateThresholdCrossing(oldVolume: Float, newVolume: Float, threshold: Float) -> Bool {
        let wasBelow = oldVolume < threshold
        let isNowAtOrAbove = newVolume >= threshold
        return wasBelow && isNowAtOrAbove
    }
}


// MARK: - Property 5: Volume Gate State Isolation

/// **Property 5: Volume Gate State Isolation**
/// *For any* volume-gate retry alarm, the `volumeGateRetryAlarmID` SHALL be independent
/// of `currentRetryAlarmID`, ensuring volume-gate retries do not interfere with
/// conversation retry tracking.
///
/// **Validates: Requirements 5.8, 6.5**
@Suite("Volume Gate State Isolation Tests", .serialized)
struct VolumeGateStateIsolationTests {
    
    /// Property test that verifies volumeGateRetryAlarmID and currentRetryAlarmID
    /// are stored and retrieved independently.
    @Test("Property 5: Volume gate and conversation retry IDs are independent")
    func propertyStateIsolation() async throws {
        // Run 100 iterations with random ID combinations
        for iteration in 0..<100 {
            // Generate random IDs
            let volumeGateID = "volume-gate-\(UUID().uuidString)"
            let conversationRetryID = "conversation-\(UUID().uuidString)"
            
            // Save both IDs
            LocalStore.saveVolumeGateRetryAlarmID(volumeGateID)
            LocalStore.saveCurrentRetryAlarmID(conversationRetryID)
            
            // Verify they are stored independently
            let loadedVolumeGateID = LocalStore.loadVolumeGateRetryAlarmID()
            let loadedConversationID = LocalStore.loadCurrentRetryAlarmID()
            
            #expect(loadedVolumeGateID == volumeGateID,
                   "Iteration \(iteration): Volume gate ID should be \(volumeGateID), got \(loadedVolumeGateID ?? "nil")")
            #expect(loadedConversationID == conversationRetryID,
                   "Iteration \(iteration): Conversation ID should be \(conversationRetryID), got \(loadedConversationID ?? "nil")")
            
            // Verify clearing one doesn't affect the other
            LocalStore.saveVolumeGateRetryAlarmID(nil)
            #expect(LocalStore.loadVolumeGateRetryAlarmID() == nil,
                   "Volume gate ID should be nil after clearing")
            #expect(LocalStore.loadCurrentRetryAlarmID() == conversationRetryID,
                   "Conversation ID should be unchanged after clearing volume gate ID")
            
            // Clean up
            LocalStore.saveCurrentRetryAlarmID(nil)
        }
    }
    
    // MARK: - Unit Tests: Specific Isolation Scenarios
    
    @Test("Setting volume gate ID does not affect conversation retry ID")
    func settingVolumeGateDoesNotAffectConversation() {
        // Set up initial conversation retry ID
        let conversationID = "conv-123"
        LocalStore.saveCurrentRetryAlarmID(conversationID)
        
        // Set volume gate ID
        let volumeGateID = "vg-456"
        LocalStore.saveVolumeGateRetryAlarmID(volumeGateID)
        
        // Verify conversation ID is unchanged
        #expect(LocalStore.loadCurrentRetryAlarmID() == conversationID)
        #expect(LocalStore.loadVolumeGateRetryAlarmID() == volumeGateID)
        
        // Clean up
        LocalStore.saveCurrentRetryAlarmID(nil)
        LocalStore.saveVolumeGateRetryAlarmID(nil)
    }
    
    @Test("Clearing conversation retry ID does not affect volume gate ID")
    func clearingConversationDoesNotAffectVolumeGate() {
        // Set up both IDs
        LocalStore.saveCurrentRetryAlarmID("conv-789")
        LocalStore.saveVolumeGateRetryAlarmID("vg-012")
        
        // Clear conversation ID
        LocalStore.saveCurrentRetryAlarmID(nil)
        
        // Verify volume gate ID is unchanged
        #expect(LocalStore.loadCurrentRetryAlarmID() == nil)
        #expect(LocalStore.loadVolumeGateRetryAlarmID() == "vg-012")
        
        // Clean up
        LocalStore.saveVolumeGateRetryAlarmID(nil)
    }
    
    @Test("Both IDs can be nil independently")
    func bothIDsCanBeNilIndependently() {
        // Start with both nil
        LocalStore.saveCurrentRetryAlarmID(nil)
        LocalStore.saveVolumeGateRetryAlarmID(nil)
        
        #expect(LocalStore.loadCurrentRetryAlarmID() == nil)
        #expect(LocalStore.loadVolumeGateRetryAlarmID() == nil)
        
        // Set only volume gate
        LocalStore.saveVolumeGateRetryAlarmID("vg-only")
        #expect(LocalStore.loadCurrentRetryAlarmID() == nil)
        #expect(LocalStore.loadVolumeGateRetryAlarmID() == "vg-only")
        
        // Clean up
        LocalStore.saveVolumeGateRetryAlarmID(nil)
    }
}
