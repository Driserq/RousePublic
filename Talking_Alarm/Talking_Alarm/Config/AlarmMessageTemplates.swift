import Foundation

// MARK: - Centralized Alarm Message Templates
// EDIT THESE MESSAGE TEMPLATES HERE FOR EASY CUSTOMIZATION

struct AlarmMessageTemplates {
    
    // MARK: - Message Templates for Escalating Wake-Up Sequence
    
    static let messages = [
        // Attempt 1 (Gentle - Encouraging)
        MessageTemplate(
            attempt: 1,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a gentle, encouraging wake-up message.
            User's goal: [USER_GOAL]
            Tone: Warm, supportive, understanding
            Length: 15-20 seconds when spoken
            Include: Their specific goal, gentle motivation
            Example tone: "Good morning! Ready to work on [goal]? Let's start this day right!"
            """,
            maxDuration: 20
        ),
        
        // Attempt 2 (Firm - More Direct)
        MessageTemplate(
            attempt: 2,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a firmer wake-up message.
            User's goal: [USER_GOAL]
            Tone: More direct, accountability-focused, still caring
            Length: 20-25 seconds when spoken
            Include: Reference to their commitment, gentle pressure
            Example tone: "Hey! I know you can hear me. Your [goal] won't complete itself!"
            """,
            maxDuration: 25
        ),
        
        // Attempt 3 (Urgent - Demanding)
        MessageTemplate(
            attempt: 3,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate an urgent wake-up message.
            User's goal: [USER_GOAL]
            Tone: Demanding, accountability-focused, disappointed but not mean
            Length: 25-30 seconds when spoken
            Include: This is attempt #3, their goal is important, time is running out
            Example tone: "This is attempt 3! You committed to [goal]. Stop pretending you can't hear me!"
            """,
            maxDuration: 30
        ),
        
        // Attempt 4 (Final Warning - Ultimatum)
        MessageTemplate(
            attempt: 4,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a final warning wake-up message.
            User's goal: [USER_GOAL]
            Tone: Final ultimatum, disappointed, giving up on them
            Length: 30 seconds max when spoken
            Include: This is the last attempt, they're on their own now, consequences
            Example tone: "FINAL WARNING! [goal] was YOUR priority. I'm done. Don't blame me when you fail!"
            Add instruction: Include attention-grabbing sounds or effects in TTS
            """,
            maxDuration: 30
        )
    ]

    static let napMessages = [
        MessageTemplate(
            attempt: 1,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a gentle, encouraging nap wake-up message.
            User's goal after the nap: [USER_GOAL]
            Tone: Calm, supportive, reassuring
            Length: 15-20 seconds when spoken
            Include: Acknowledge the nap, help them transition to their goal
            Example tone: "Welcome back from your nap. Let's ease into [goal] and get moving."
            """,
            maxDuration: 20
        ),
        MessageTemplate(
            attempt: 2,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a firmer nap wake-up message.
            User's goal after the nap: [USER_GOAL]
            Tone: More direct, accountability-focused, still calm
            Length: 20-25 seconds when spoken
            Include: Mention the nap is done, it's time to start their plan
            Example tone: "Nap's over. Time to get up and move toward [goal]."
            """,
            maxDuration: 25
        ),
        MessageTemplate(
            attempt: 3,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate an urgent nap wake-up message.
            User's goal after the nap: [USER_GOAL]
            Tone: Demanding, accountability-focused, not harsh
            Length: 25-30 seconds when spoken
            Include: This is attempt #3, nap is done, time to act
            Example tone: "This is attempt 3. Nap is over. Get up and start [goal] now."
            """,
            maxDuration: 30
        ),
        MessageTemplate(
            attempt: 4,
            prompt: """
            You are [PERSONALITY_TYPE]. Generate a final warning nap wake-up message.
            User's goal after the nap: [USER_GOAL]
            Tone: Final ultimatum, disappointed, urging action
            Length: 30 seconds max when spoken
            Include: This is the last attempt, nap time is done, consequences
            Add instruction: Include attention-grabbing sounds or effects in TTS
            """,
            maxDuration: 30
        )
    ]
    
    // MARK: - Helper Methods
    
    static func getTemplate(for attempt: Int) -> MessageTemplate? {
        return messages.first { $0.attempt == attempt }
    }

    static func getNapTemplate(for attempt: Int) -> MessageTemplate? {
        return napMessages.first { $0.attempt == attempt }
    }
    
    static func generatePrompt(for attempt: Int, userGoal: String, personality: String) -> String? {
        guard let template = getTemplate(for: attempt) else { return nil }
        
        return template.prompt
            .replacingOccurrences(of: "[PERSONALITY_TYPE]", with: personality)
            .replacingOccurrences(of: "[USER_GOAL]", with: userGoal)
            .replacingOccurrences(of: "[goal]", with: userGoal)
    }

    static func generateNapPrompt(for attempt: Int, userGoal: String, personality: String) -> String? {
        guard let template = getNapTemplate(for: attempt) else { return nil }

        return template.prompt
            .replacingOccurrences(of: "[PERSONALITY_TYPE]", with: personality)
            .replacingOccurrences(of: "[USER_GOAL]", with: userGoal)
            .replacingOccurrences(of: "[goal]", with: userGoal)
    }
}

// MARK: - Message Template Structure

struct MessageTemplate {
    let attempt: Int
    let prompt: String
    let maxDuration: Int
    
    // MARK: - Template Properties
    
    var fileName: String {
        return "attempt\(attempt).m4a"
    }
    
    var notificationTitle: String {
        return "Talking Alarm - Attempt \(attempt)"
    }
    
    var notificationBody: String {
        switch attempt {
        case 1:
            return "Your accountability partner is calling"
        case 2:
            return "Still sleeping? Your goal is waiting"
        case 3:
            return "This is getting serious - wake up!"
        case 4:
            return "FINAL WARNING - Last chance!"
        default:
            return "Talking Alarm"
        }
    }
}

