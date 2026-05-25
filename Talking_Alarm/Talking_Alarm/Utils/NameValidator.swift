import Foundation
import Combine

// MARK: - Name Validation System
final class NameValidator: ObservableObject {
    @Published var isValid = false
    @Published var validationMessage = ""
    @Published var isChecking = false
    
    private var validationTimer: Timer?
    private let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Validation Rules
    
    func validateName(_ name: String) {
        // Cancel previous timer
        validationTimer?.invalidate()
        
        // Start checking state
        isChecking = true
        
        // Set up debounced validation
        validationTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performValidation(name)
        }
    }
    
    private func performValidation(_ name: String) {
        let result = validateNameRules(name)
        
        DispatchQueue.main.async {
            self.isValid = result.isValid
            self.validationMessage = result.message
            self.isChecking = false
        }
    }
    
    private func validateNameRules(_ name: String) -> (isValid: Bool, message: String) {
        // Rule 1: Length check (2-30 characters)
        if name.count < 2 {
            return (false, "Name must be at least 2 characters long")
        }
        
        if name.count > 30 {
            return (false, "Name must be no more than 30 characters long")
        }
        
        // Rule 2: Character validation (letters, spaces, hyphens, apostrophes only)
        let allowedPattern = "^[A-Za-z\\s'-]+$"
        let regex = try? NSRegularExpression(pattern: allowedPattern)
        let range = NSRange(location: 0, length: name.utf16.count)
        
        if let regex = regex, regex.firstMatch(in: name, options: [], range: range) == nil {
            return (false, "Name can only contain letters, spaces, hyphens, and apostrophes")
        }
        
        // Rule 3: Reject excessive repeated characters (3+ in a row)
        if hasExcessiveRepeatedCharacters(name) {
            return (false, "Name cannot have 3 or more of the same character in a row")
        }
        
        // Rule 4: Reject gibberish via vowel ratio (minimum 20% vowels)
        if !hasMinimumVowelRatio(name) {
            return (false, "Name must contain at least 20% vowels")
        }
        
        // Rule 5: Reject keyboard patterns
        if containsKeyboardPattern(name) {
            return (false, "Name cannot contain keyboard patterns like 'qwerty' or 'asdfgh'")
        }
        
        // All validations passed
        return (true, "Name looks good!")
    }
    
    // MARK: - Individual Validation Rules
    
    private func hasExcessiveRepeatedCharacters(_ name: String) -> Bool {
        var currentChar: Character?
        var count = 0
        
        for char in name.lowercased() {
            if char == currentChar {
                count += 1
                if count >= 3 {
                    return true
                }
            } else {
                currentChar = char
                count = 1
            }
        }
        
        return false
    }
    
    private func hasMinimumVowelRatio(_ name: String) -> Bool {
        let vowels = Set("aeiou")
        let vowelCount = name.lowercased().filter { vowels.contains($0) }.count
        let totalLetters = name.filter { $0.isLetter }.count
        
        guard totalLetters > 0 else { return false }
        
        let vowelRatio = Double(vowelCount) / Double(totalLetters)
        return vowelRatio >= 0.2
    }
    
    private func containsKeyboardPattern(_ name: String) -> Bool {
        let keyboardPatterns = [
            "qwerty", "qwertyuiop", "asdfgh", "asdfghjkl", "zxcvbn",
            "qwertyuiopasdfghjklzxcvbnm", "abcdefghijklmnopqrstuvwxyz",
            "1234567890", "abcdef", "ghijkl", "mnopqr", "stuvwx", "yz"
        ]
        
        let lowercasedName = name.lowercased()
        
        for pattern in keyboardPatterns {
            if lowercasedName.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Validation States
    
    func reset() {
        validationTimer?.invalidate()
        isValid = false
        validationMessage = ""
        isChecking = false
    }
}

// MARK: - Validation Result Extensions

extension NameValidator {
    var validationColor: String {
        if isChecking {
            return "orange"
        } else if isValid {
            return "green"
        } else {
            return "red"
        }
    }
    
    var canProceed: Bool {
        return isValid && !isChecking
    }
}


