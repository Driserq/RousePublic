import Foundation
import Combine

// MARK: - Onboarding Manager
final class OnboardingManager: ObservableObject {
    @Published var currentScreen: OnboardingScreen = .welcome
    @Published var isCompleted = false
    @Published var userData = OnboardingUserData()
    
    private let totalScreens = 8
    
    var progressPercentage: Double {
        return Double(currentScreen.rawValue + 1) / Double(totalScreens) * 100
    }
    
    var progressText: String {
        return "\(currentScreen.rawValue + 1) of \(totalScreens)"
    }
    
    func nextScreen() {
        guard canProceedToNext else { return }
        
        if currentScreen.rawValue < totalScreens - 1 {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue + 1) ?? .welcome
        } else {
            completeOnboarding()
        }
    }
    
    func previousScreen() {
        if currentScreen.rawValue > 0 {
            currentScreen = OnboardingScreen(rawValue: currentScreen.rawValue - 1) ?? .welcome
        }
    }
    
    private var canProceedToNext: Bool {
        switch currentScreen {
        case .welcome:
            return true
        case .nameCollection:
            return userData.name.isValid
        case .goalCollection:
            return userData.goal.isValid
        case .alarmSetup:
            return true // Time picker always has a valid time
        case .permissions:
            return true // Permissions view handles its own advancement
        case .aiConsent:
            return true // AI consent view handles its own advancement
        case .ttsGeneration:
            return true // TTS generation is automatic
        case .completion:
            return true
        }
    }
    
    func completeOnboarding() {
        isCompleted = true
        // Save onboarding completion status
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        // Save user data
        saveUserData()
        // Post completion notification
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
    
    private func saveUserData() {
        UserDefaults.standard.set(userData.name, forKey: "user_name")
        UserDefaults.standard.set(userData.goal, forKey: "user_goal")
        UserDefaults.standard.set(userData.alarmTime.timeIntervalSince1970, forKey: "user_alarm_time")
    }
    
    static func isOnboardingCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: "onboarding_completed")
    }
    
    static func loadUserData() -> OnboardingUserData? {
        guard let name = UserDefaults.standard.string(forKey: "user_name"),
              let goal = UserDefaults.standard.string(forKey: "user_goal") else {
            return nil
        }
        
        let alarmTimeInterval = UserDefaults.standard.double(forKey: "user_alarm_time")
        let alarmTime = alarmTimeInterval > 0 ? Date(timeIntervalSince1970: alarmTimeInterval) : Date().addingTimeInterval(8 * 60 * 60)
        
        return OnboardingUserData(name: name, goal: goal, alarmTime: alarmTime)
    }
}

// MARK: - Onboarding Screen Enum
enum OnboardingScreen: Int, CaseIterable {
    case welcome = 0
    case nameCollection = 1
    case goalCollection = 2
    case alarmSetup = 3
    case permissions = 4
    case aiConsent = 5
    case ttsGeneration = 6
    case completion = 7
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome to Talking Alarm"
        case .nameCollection:
            return "What's your name?"
        case .goalCollection:
            return "What's your morning goal?"
        case .alarmSetup:
            return "Set your alarm time"
        case .permissions:
            return "Permissions"
        case .aiConsent:
            return "AI Consent"
        case .ttsGeneration:
            return "Generating your wake-up message"
        case .completion:
            return "All set!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .welcome:
            return "An AI-powered wake-up experience that ensures you're truly awake and ready to tackle your goals."
        case .nameCollection:
            return "We'll use this to personalize your wake-up message."
        case .goalCollection:
            return "What do you want to accomplish each morning?"
        case .alarmSetup:
            return "Choose when you want to wake up each day."
        case .permissions:
            return "We need a few permissions to wake you up."
        case .aiConsent:
            return "Consent to AI processing."
        case .ttsGeneration:
            return "Creating your personalized wake-up message..."
        case .completion:
            return "Your personalized alarm is ready to go!"
        }
    }
}

// MARK: - User Data Model
struct OnboardingUserData {
    var name: String = ""
    var goal: String = ""
    var alarmTime: Date = Date().addingTimeInterval(8 * 60 * 60) // Default to 8 AM
    
    init(name: String = "", goal: String = "", alarmTime: Date = Date().addingTimeInterval(8 * 60 * 60)) {
        self.name = name
        self.goal = goal
        self.alarmTime = alarmTime
    }
}

// MARK: - Validation Extensions
extension String {
    var isValid: Bool {
        return !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
