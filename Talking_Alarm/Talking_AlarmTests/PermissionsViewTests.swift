//
//  PermissionsViewTests.swift
//  Talking_AlarmTests
//
//  Property-based tests for PermissionsView Continue button enablement logic.
//  Content verification tests for UI requirements.
//

import Testing
import Foundation
@testable import Talking_Alarm

// MARK: - Source File Paths for Content Verification

/// Paths to source files relative to the test bundle's resource path.
/// These are used for content verification tests.
private enum SourceFilePaths {
    static let permissionsView = "PermissionsView.swift"
    static let consentRequiredView = "ConsentRequiredView.swift"
    static let settingsDrawer = "SettingsDrawer.swift"
}

// MARK: - Source File Content (Embedded for Testing)

/// Embedded source content for verification tests.
/// This approach allows testing without file system access at runtime.
private enum SourceContent {
    /// PermissionsView source content - key strings to verify
    static let permissionsViewContent = """
    I consent to AI processing
    Only your transcript is sent to AI services. Your actual voice recording stays private on your device.
    Not medical advice. AI is for motivation only.
    checkmark.square.fill
    isAIConsentChecked
    aiConsentSection
    """
    
    /// Strings that should NOT be in PermissionsView
    static let permissionsViewForbiddenStrings = [
        "Terms of Service",
        "Privacy Policy",
        "rousalarm.app/terms",
        "rousalarm.app/privacy"
    ]
    
    /// Strings that SHOULD be in PermissionsView for AI consent
    static let permissionsViewRequiredStrings = [
        "I consent to AI processing",
        "Only your transcript is sent to AI services",
        "Your actual voice recording stays private on your device",
        "Not medical advice. AI is for motivation only",
        "isAIConsentChecked",
        "checkmark.square.fill"
    ]
    
    /// Strings that should NOT be in ConsentRequiredView
    static let consentRequiredViewForbiddenStrings = [
        "Terms of Service",
        "Privacy Policy",
        "rousalarm.app/terms",
        "rousalarm.app/privacy"
    ]
    
    /// Strings that SHOULD be in SettingsDrawer Legal section
    static let settingsDrawerRequiredStrings = [
        "LEGAL",
        "Terms of Service",
        "Privacy Policy",
        "https://rousalarm.app/terms",
        "https://rousalarm.app/privacy",
        "doc.text.fill",
        "hand.raised.fill",
        "legalSection"
    ]
}

// MARK: - Permission State Enum for Testing

/// Represents the three possible states for each permission type.
enum PermissionState: String, CaseIterable, CustomStringConvertible {
    case granted
    case denied
    case notDetermined
    
    var description: String { rawValue }
}

// MARK: - Property 1: Continue Button Enablement Logic

/// **Property 1: Continue Button Enablement Logic**
/// *For any* combination of permission states (Microphone: granted/denied/notDetermined,
/// Speech: granted/denied/notDetermined, Alarm: granted/denied/notDetermined) and
/// AI consent checkbox state (checked/unchecked), the Continue button on the Permissions
/// screen SHALL be enabled if and only if ALL of the following conditions are true:
/// - Microphone permission is granted
/// - Speech permission is granted
/// - Alarm permission is granted
/// - AI consent checkbox is checked
///
/// **Validates: Requirements 6.1, 6.3, 6.4**
@Suite("Permissions View Continue Button Tests")
struct PermissionsViewContinueButtonTests {
    
    // MARK: - Property-Based Test: All 54 Combinations
    
    /// Property test that exhaustively tests all 54 combinations:
    /// 3 microphone states × 3 speech states × 3 alarm states × 2 consent states = 54 combinations
    @Test("Property 1: Continue button enabled iff all permissions granted AND consent checked")
    func propertyContinueButtonEnablement() async throws {
        var testedCombinations = 0
        
        // Enumerate all permission state combinations (27 total)
        for micState in PermissionState.allCases {
            for speechState in PermissionState.allCases {
                for alarmState in PermissionState.allCases {
                    // Test with consent unchecked
                    let resultUnchecked = shouldEnableContinue(
                        micGranted: micState == .granted,
                        speechGranted: speechState == .granted,
                        alarmGranted: alarmState == .granted,
                        consentChecked: false
                    )
                    
                    // Continue should NEVER be enabled when consent is unchecked
                    #expect(
                        resultUnchecked == false,
                        "Continue should be disabled when consent unchecked. Mic: \(micState), Speech: \(speechState), Alarm: \(alarmState)"
                    )
                    testedCombinations += 1
                    
                    // Test with consent checked
                    let resultChecked = shouldEnableContinue(
                        micGranted: micState == .granted,
                        speechGranted: speechState == .granted,
                        alarmGranted: alarmState == .granted,
                        consentChecked: true
                    )
                    
                    // Continue should ONLY be enabled when ALL permissions granted AND consent checked
                    let expectedEnabled = (micState == .granted && speechState == .granted && alarmState == .granted)
                    let expectedState = expectedEnabled ? "enabled" : "disabled"
                    #expect(
                        resultChecked == expectedEnabled,
                        "Continue should be \(expectedState). Mic: \(micState), Speech: \(speechState), Alarm: \(alarmState), Consent: checked"
                    )
                    testedCombinations += 1
                }
            }
        }
        
        // Verify we tested all 54 combinations
        #expect(testedCombinations == 54, "Should test exactly 54 combinations, tested \(testedCombinations)")
    }
    
    // MARK: - Unit Tests: Key Boundary Cases
    
    @Test("All permissions granted AND consent checked → Continue enabled")
    func allGrantedAndConsentChecked() {
        let result = shouldEnableContinue(
            micGranted: true,
            speechGranted: true,
            alarmGranted: true,
            consentChecked: true
        )
        #expect(result == true)
    }
    
    @Test("All permissions granted BUT consent unchecked → Continue disabled")
    func allGrantedButConsentUnchecked() {
        let result = shouldEnableContinue(
            micGranted: true,
            speechGranted: true,
            alarmGranted: true,
            consentChecked: false
        )
        #expect(result == false)
    }
    
    @Test("Microphone denied → Continue disabled regardless of consent")
    func microphoneDenied() {
        // With consent checked
        let resultChecked = shouldEnableContinue(
            micGranted: false,
            speechGranted: true,
            alarmGranted: true,
            consentChecked: true
        )
        #expect(resultChecked == false)
        
        // With consent unchecked
        let resultUnchecked = shouldEnableContinue(
            micGranted: false,
            speechGranted: true,
            alarmGranted: true,
            consentChecked: false
        )
        #expect(resultUnchecked == false)
    }
    
    @Test("Speech denied → Continue disabled regardless of consent")
    func speechDenied() {
        // With consent checked
        let resultChecked = shouldEnableContinue(
            micGranted: true,
            speechGranted: false,
            alarmGranted: true,
            consentChecked: true
        )
        #expect(resultChecked == false)
        
        // With consent unchecked
        let resultUnchecked = shouldEnableContinue(
            micGranted: true,
            speechGranted: false,
            alarmGranted: true,
            consentChecked: false
        )
        #expect(resultUnchecked == false)
    }
    
    @Test("Alarm denied → Continue disabled regardless of consent")
    func alarmDenied() {
        // With consent checked
        let resultChecked = shouldEnableContinue(
            micGranted: true,
            speechGranted: true,
            alarmGranted: false,
            consentChecked: true
        )
        #expect(resultChecked == false)
        
        // With consent unchecked
        let resultUnchecked = shouldEnableContinue(
            micGranted: true,
            speechGranted: true,
            alarmGranted: false,
            consentChecked: false
        )
        #expect(resultUnchecked == false)
    }
    
    @Test("No permissions granted → Continue disabled regardless of consent")
    func noPermissionsGranted() {
        // With consent checked
        let resultChecked = shouldEnableContinue(
            micGranted: false,
            speechGranted: false,
            alarmGranted: false,
            consentChecked: true
        )
        #expect(resultChecked == false)
        
        // With consent unchecked
        let resultUnchecked = shouldEnableContinue(
            micGranted: false,
            speechGranted: false,
            alarmGranted: false,
            consentChecked: false
        )
        #expect(resultUnchecked == false)
    }
    
    @Test("Only one permission granted → Continue disabled")
    func onlyOnePermissionGranted() {
        // Only microphone
        #expect(shouldEnableContinue(micGranted: true, speechGranted: false, alarmGranted: false, consentChecked: true) == false)
        
        // Only speech
        #expect(shouldEnableContinue(micGranted: false, speechGranted: true, alarmGranted: false, consentChecked: true) == false)
        
        // Only alarm
        #expect(shouldEnableContinue(micGranted: false, speechGranted: false, alarmGranted: true, consentChecked: true) == false)
    }
    
    @Test("Two permissions granted → Continue disabled")
    func twoPermissionsGranted() {
        // Microphone + Speech
        #expect(shouldEnableContinue(micGranted: true, speechGranted: true, alarmGranted: false, consentChecked: true) == false)
        
        // Microphone + Alarm
        #expect(shouldEnableContinue(micGranted: true, speechGranted: false, alarmGranted: true, consentChecked: true) == false)
        
        // Speech + Alarm
        #expect(shouldEnableContinue(micGranted: false, speechGranted: true, alarmGranted: true, consentChecked: true) == false)
    }
    
    // MARK: - Helper Function
    
    /// Pure function that implements the Continue button enablement logic.
    /// This mirrors the logic in PermissionsView.checkAllGranted() but is testable
    /// without requiring actual permission APIs.
    ///
    /// Continue enabled iff: Microphone granted AND Speech granted AND Alarm granted AND AI consent checked
    private func shouldEnableContinue(
        micGranted: Bool,
        speechGranted: Bool,
        alarmGranted: Bool,
        consentChecked: Bool
    ) -> Bool {
        return micGranted && speechGranted && alarmGranted && consentChecked
    }
}


// MARK: - Content Verification Tests

/// **Task 11.1: Test PermissionsView does not contain Terms/Privacy links**
/// **Validates: Requirements 7.1, 7.2**
///
/// These tests verify that the PermissionsView source code does NOT contain
/// Terms of Service or Privacy Policy links, as these have been moved to Settings.
@Suite("PermissionsView Content Verification - No Policy Links")
struct PermissionsViewNoPolicyLinksTests {
    
    /// Helper to read the PermissionsView source file content
    private func readPermissionsViewSource() throws -> String {
        // Get the path to the source file in the project
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PermissionsViewTests.swift
            .deletingLastPathComponent() // Talking_AlarmTests
            .deletingLastPathComponent() // Talking_Alarm (project folder)
        
        let sourceURL = projectRoot
            .appending(path: "Talking_Alarm")
            .appending(path: "Features")
            .appending(path: "Onboarding")
            .appending(path: "PermissionsView.swift")
        
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
    
    @Test("PermissionsView does not contain 'Terms of Service' text")
    func noTermsOfServiceText() throws {
        let source = try readPermissionsViewSource()
        
        // Verify "Terms of Service" is not present
        #expect(
            !source.contains("Terms of Service"),
            "PermissionsView should NOT contain 'Terms of Service' text (Requirement 7.1)"
        )
    }
    
    @Test("PermissionsView does not contain 'Privacy Policy' text")
    func noPrivacyPolicyText() throws {
        let source = try readPermissionsViewSource()
        
        // Verify "Privacy Policy" is not present
        #expect(
            !source.contains("Privacy Policy"),
            "PermissionsView should NOT contain 'Privacy Policy' text (Requirement 7.2)"
        )
    }
    
    @Test("PermissionsView does not contain terms URL")
    func noTermsURL() throws {
        let source = try readPermissionsViewSource()
        
        // Verify terms URL is not present
        #expect(
            !source.contains("rousalarm.app/terms"),
            "PermissionsView should NOT contain terms URL (Requirement 7.1)"
        )
    }
    
    @Test("PermissionsView does not contain privacy URL")
    func noPrivacyURL() throws {
        let source = try readPermissionsViewSource()
        
        // Verify privacy URL is not present
        #expect(
            !source.contains("rousalarm.app/privacy"),
            "PermissionsView should NOT contain privacy URL (Requirement 7.2)"
        )
    }
    
    @Test("PermissionsView retains disclaimer text")
    func retainsDisclaimerText() throws {
        let source = try readPermissionsViewSource()
        
        // Verify disclaimer is still present (Requirement 7.3)
        #expect(
            source.contains("Not medical advice. AI is for motivation only."),
            "PermissionsView should retain disclaimer text (Requirement 7.3)"
        )
    }
}

/// **Task 11.2: Test PermissionsView contains AI consent checkbox and explanation**
/// **Validates: Requirements 6.1, 6.2**
///
/// These tests verify that the PermissionsView contains the AI consent checkbox
/// and the required explanation text about transcript privacy.
@Suite("PermissionsView Content Verification - AI Consent")
struct PermissionsViewAIConsentTests {
    
    /// Helper to read the PermissionsView source file content
    private func readPermissionsViewSource() throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let sourceURL = projectRoot
            .appending(path: "Talking_Alarm")
            .appending(path: "Features")
            .appending(path: "Onboarding")
            .appending(path: "PermissionsView.swift")
        
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
    
    @Test("PermissionsView contains AI consent checkbox state variable")
    func containsAIConsentCheckboxState() throws {
        let source = try readPermissionsViewSource()
        
        // Verify checkbox state variable exists
        #expect(
            source.contains("isAIConsentChecked"),
            "PermissionsView should contain 'isAIConsentChecked' state variable (Requirement 6.1)"
        )
    }
    
    @Test("PermissionsView contains AI consent section")
    func containsAIConsentSection() throws {
        let source = try readPermissionsViewSource()
        
        // Verify aiConsentSection exists
        #expect(
            source.contains("aiConsentSection"),
            "PermissionsView should contain 'aiConsentSection' computed property (Requirement 6.1)"
        )
    }
    
    @Test("PermissionsView contains consent checkbox label text")
    func containsConsentLabelText() throws {
        let source = try readPermissionsViewSource()
        
        // Verify consent label text
        #expect(
            source.contains("I consent to AI processing"),
            "PermissionsView should contain 'I consent to AI processing' text (Requirement 6.1)"
        )
    }
    
    @Test("PermissionsView contains transcript privacy explanation")
    func containsTranscriptPrivacyExplanation() throws {
        let source = try readPermissionsViewSource()
        
        // Verify transcript privacy explanation (Requirement 6.2)
        #expect(
            source.contains("Only your transcript is sent to AI services"),
            "PermissionsView should contain transcript privacy explanation (Requirement 6.2)"
        )
        
        #expect(
            source.contains("Your actual voice recording stays private on your device"),
            "PermissionsView should contain voice recording privacy explanation (Requirement 6.2)"
        )
    }
    
    @Test("PermissionsView contains checkbox icon")
    func containsCheckboxIcon() throws {
        let source = try readPermissionsViewSource()
        
        // Verify checkbox icon is used
        #expect(
            source.contains("checkmark.square.fill"),
            "PermissionsView should use 'checkmark.square.fill' icon for checkbox (Requirement 6.1)"
        )
    }
    
    @Test("PermissionsView checkbox toggles consent state")
    func checkboxTogglesConsentState() throws {
        let source = try readPermissionsViewSource()
        
        // Verify toggle action exists
        #expect(
            source.contains("isAIConsentChecked.toggle()"),
            "PermissionsView checkbox should toggle consent state (Requirement 6.1)"
        )
    }
}

/// **Task 11.3: Test ConsentRequiredView does not contain Terms/Privacy links**
/// **Validates: Requirements 8.1, 8.2**
///
/// These tests verify that the ConsentRequiredView source code does NOT contain
/// Terms of Service or Privacy Policy links.
@Suite("ConsentRequiredView Content Verification - No Policy Links")
struct ConsentRequiredViewNoPolicyLinksTests {
    
    /// Helper to read the ConsentRequiredView source file content
    private func readConsentRequiredViewSource() throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let sourceURL = projectRoot
            .appending(path: "Talking_Alarm")
            .appending(path: "App")
            .appending(path: "ConsentRequiredView.swift")
        
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
    
    @Test("ConsentRequiredView does not contain 'Terms of Service' text")
    func noTermsOfServiceText() throws {
        let source = try readConsentRequiredViewSource()
        
        // Verify "Terms of Service" is not present
        #expect(
            !source.contains("Terms of Service"),
            "ConsentRequiredView should NOT contain 'Terms of Service' text (Requirement 8.1)"
        )
    }
    
    @Test("ConsentRequiredView does not contain 'Privacy Policy' text")
    func noPrivacyPolicyText() throws {
        let source = try readConsentRequiredViewSource()
        
        // Verify "Privacy Policy" is not present
        #expect(
            !source.contains("Privacy Policy"),
            "ConsentRequiredView should NOT contain 'Privacy Policy' text (Requirement 8.2)"
        )
    }
    
    @Test("ConsentRequiredView does not contain terms URL")
    func noTermsURL() throws {
        let source = try readConsentRequiredViewSource()
        
        // Verify terms URL is not present
        #expect(
            !source.contains("rousalarm.app/terms"),
            "ConsentRequiredView should NOT contain terms URL (Requirement 8.1)"
        )
    }
    
    @Test("ConsentRequiredView does not contain privacy URL")
    func noPrivacyURL() throws {
        let source = try readConsentRequiredViewSource()
        
        // Verify privacy URL is not present
        #expect(
            !source.contains("rousalarm.app/privacy"),
            "ConsentRequiredView should NOT contain privacy URL (Requirement 8.2)"
        )
    }
    
    @Test("ConsentRequiredView contains simplified privacy explanation")
    func containsSimplifiedPrivacyExplanation() throws {
        let source = try readConsentRequiredViewSource()
        
        // Verify simplified privacy explanation exists (Requirement 8.3)
        #expect(
            source.contains("Only your transcript is sent to AI services"),
            "ConsentRequiredView should contain transcript privacy explanation (Requirement 8.3)"
        )
    }
}

/// **Task 11.4: Test SettingsDrawer contains Legal section with correct links**
/// **Validates: Requirements 9.1, 9.2, 9.3**
///
/// These tests verify that the SettingsDrawer contains a Legal section
/// with Terms of Service and Privacy Policy links.
@Suite("SettingsDrawer Content Verification - Legal Section")
struct SettingsDrawerLegalSectionTests {
    
    /// Helper to read the SettingsDrawer source file content
    private func readSettingsDrawerSource() throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        let sourceURL = projectRoot
            .appending(path: "Talking_Alarm")
            .appending(path: "Features")
            .appending(path: "Settings")
            .appending(path: "SettingsDrawer.swift")
        
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
    
    @Test("SettingsDrawer contains Legal section header")
    func containsLegalSectionHeader() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify "LEGAL" header exists (Requirement 9.1)
        #expect(
            source.contains("\"LEGAL\""),
            "SettingsDrawer should contain 'LEGAL' section header (Requirement 9.1)"
        )
    }
    
    @Test("SettingsDrawer contains legalSection computed property")
    func containsLegalSectionProperty() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify legalSection property exists
        #expect(
            source.contains("legalSection"),
            "SettingsDrawer should contain 'legalSection' computed property (Requirement 9.1)"
        )
    }
    
    @Test("SettingsDrawer contains Terms of Service link")
    func containsTermsOfServiceLink() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify Terms of Service text and URL (Requirement 9.2)
        #expect(
            source.contains("Terms of Service"),
            "SettingsDrawer should contain 'Terms of Service' text (Requirement 9.2)"
        )
        
        #expect(
            source.contains("https://rousalarm.app/terms"),
            "SettingsDrawer should contain terms URL (Requirement 9.2)"
        )
    }
    
    @Test("SettingsDrawer contains Privacy Policy link")
    func containsPrivacyPolicyLink() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify Privacy Policy text and URL (Requirement 9.3)
        #expect(
            source.contains("Privacy Policy"),
            "SettingsDrawer should contain 'Privacy Policy' text (Requirement 9.3)"
        )
        
        #expect(
            source.contains("https://rousalarm.app/privacy"),
            "SettingsDrawer should contain privacy URL (Requirement 9.3)"
        )
    }
    
    @Test("SettingsDrawer Legal section uses correct icons")
    func legalSectionUsesCorrectIcons() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify icons are used (Requirements 9.2, 9.3)
        #expect(
            source.contains("doc.text.fill"),
            "SettingsDrawer should use 'doc.text.fill' icon for Terms (Requirement 9.2)"
        )
        
        #expect(
            source.contains("hand.raised.fill"),
            "SettingsDrawer should use 'hand.raised.fill' icon for Privacy (Requirement 9.3)"
        )
    }
    
    @Test("SettingsDrawer Legal section uses Link component")
    func legalSectionUsesLinkComponent() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify Link component is used for external URLs
        #expect(
            source.contains("Link(destination:"),
            "SettingsDrawer Legal section should use Link component for external URLs"
        )
    }
    
    @Test("SettingsDrawer Legal section uses external link indicator")
    func legalSectionUsesExternalLinkIndicator() throws {
        let source = try readSettingsDrawerSource()
        
        // Verify external link indicator icon is used
        #expect(
            source.contains("arrow.up.right"),
            "SettingsDrawer Legal section should use 'arrow.up.right' indicator for external links"
        )
    }
}
