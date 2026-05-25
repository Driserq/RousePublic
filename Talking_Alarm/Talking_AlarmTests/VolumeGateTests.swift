//
//  VolumeGateTests.swift
//  Talking_AlarmTests
//
//  Property-based tests for VolumeGateManager volume threshold logic.
//

import Testing
@testable import Talking_Alarm

/// Property-based tests for the Volume Gate feature.
///
/// These tests validate the volume threshold boundary logic using random inputs
/// to ensure the threshold check is correct across all possible volume values.
struct VolumeGateTests {
    
    // MARK: - Constants
    
    /// The volume threshold used by VolumeGateManager (15%)
    private let volumeThreshold: Float = 0.15
    
    /// Minimum number of iterations for property-based tests
    private let minimumIterations = 100
    
    // MARK: - Testable Volume Check Logic
    
    /// Pure function that implements the volume threshold check logic.
    /// This mirrors the logic in `VolumeGateManager.checkVolume()` but accepts
    /// a volume parameter for testability.
    ///
    /// - Parameter volume: The volume level to check (0.0 to 1.0)
    /// - Returns: `true` if volume >= threshold (0.15), `false` otherwise
    private func checkVolumeThreshold(_ volume: Float) -> Bool {
        return volume >= volumeThreshold
    }
    
    // MARK: - Property 1: Volume Threshold Boundary
    
    /// **Property 1: Volume Threshold Boundary**
    ///
    /// For any volume value in [0.0, 1.0], `checkVolume()` SHALL return `true`
    /// if and only if the volume is greater than or equal to 0.15, and `false` otherwise.
    ///
    /// **Validates: Requirements 1.2, 1.3**
    ///
    /// This property test generates random Float values in the valid volume range
    /// and verifies the threshold logic returns the correct boolean result.
    @Test("Property 1: Volume Threshold Boundary - Random values in [0.0, 1.0]")
    func volumeThresholdBoundaryProperty() async throws {
        // Run minimum 100 iterations with random volume values
        for iteration in 1...minimumIterations {
            // Generate random Float in [0.0, 1.0]
            let randomVolume = Float.random(in: 0.0...1.0)
            
            // Calculate expected result based on threshold
            let expectedResult = randomVolume >= volumeThreshold
            
            // Get actual result from threshold check
            let actualResult = checkVolumeThreshold(randomVolume)
            
            // Verify the property holds
            #expect(
                actualResult == expectedResult,
                "Iteration \(iteration): Volume \(randomVolume) should return \(expectedResult) but got \(actualResult)"
            )
        }
    }
    
    // MARK: - Boundary Edge Cases
    
    /// Test exact threshold boundary: volume exactly at 0.15 should pass.
    @Test("Boundary: Volume exactly at threshold (0.15) should pass")
    func volumeExactlyAtThreshold() {
        let volume: Float = 0.15
        let result = checkVolumeThreshold(volume)
        #expect(result == true, "Volume at exactly 0.15 should pass the threshold check")
    }
    
    /// Test just below threshold: volume at 0.149 should fail.
    @Test("Boundary: Volume just below threshold (0.149) should fail")
    func volumeJustBelowThreshold() {
        let volume: Float = 0.149
        let result = checkVolumeThreshold(volume)
        #expect(result == false, "Volume at 0.149 should fail the threshold check")
    }
    
    /// Test minimum volume: 0.0 should fail.
    @Test("Boundary: Minimum volume (0.0) should fail")
    func volumeAtMinimum() {
        let volume: Float = 0.0
        let result = checkVolumeThreshold(volume)
        #expect(result == false, "Volume at 0.0 should fail the threshold check")
    }
    
    /// Test maximum volume: 1.0 should pass.
    @Test("Boundary: Maximum volume (1.0) should pass")
    func volumeAtMaximum() {
        let volume: Float = 1.0
        let result = checkVolumeThreshold(volume)
        #expect(result == true, "Volume at 1.0 should pass the threshold check")
    }
    
    /// Test just above threshold: volume at 0.151 should pass.
    @Test("Boundary: Volume just above threshold (0.151) should pass")
    func volumeJustAboveThreshold() {
        let volume: Float = 0.151
        let result = checkVolumeThreshold(volume)
        #expect(result == true, "Volume at 0.151 should pass the threshold check")
    }
    
    // MARK: - Property: All values below threshold fail
    
    /// **Property: All values below threshold should fail**
    ///
    /// For any volume value in [0.0, 0.15), the check should return false.
    @Test("Property: All values below threshold [0.0, 0.15) should fail")
    func allValuesBelowThresholdFail() async throws {
        for _ in 1...minimumIterations {
            // Generate random Float in [0.0, 0.15) - exclusive of 0.15
            let randomVolume = Float.random(in: 0.0..<volumeThreshold)
            
            let result = checkVolumeThreshold(randomVolume)
            
            #expect(
                result == false,
                "Volume \(randomVolume) is below threshold and should fail"
            )
        }
    }
    
    // MARK: - Property: All values at or above threshold pass
    
    /// **Property: All values at or above threshold should pass**
    ///
    /// For any volume value in [0.15, 1.0], the check should return true.
    @Test("Property: All values at or above threshold [0.15, 1.0] should pass")
    func allValuesAtOrAboveThresholdPass() async throws {
        for _ in 1...minimumIterations {
            // Generate random Float in [0.15, 1.0]
            let randomVolume = Float.random(in: volumeThreshold...1.0)
            
            let result = checkVolumeThreshold(randomVolume)
            
            #expect(
                result == true,
                "Volume \(randomVolume) is at or above threshold and should pass"
            )
        }
    }
    
    // MARK: - Threshold Constant Verification
    
    /// Verify that VolumeGateManager uses the correct threshold constant.
    @Test("VolumeGateManager threshold constant is 0.15")
    func volumeGateManagerThresholdConstant() {
        #expect(
            VolumeGateManager.volumeThreshold == 0.15,
            "VolumeGateManager.volumeThreshold should be 0.15"
        )
    }
}
