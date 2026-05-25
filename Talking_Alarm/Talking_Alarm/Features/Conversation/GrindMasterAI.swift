import Foundation

enum GrindTone: String {
    case encouraging
    case firm
    case exasperated
}

struct GrindPromptContext {
    let goal: String
    let attempt: Int
    let lastTranscript: String?
    let sleepSeconds: Int
}

enum GrindMasterAI {
    static func tone(for attempt: Int) -> GrindTone {
        switch attempt {
        case ..<2: return .encouraging
        case 2..<4: return .firm
        default: return .exasperated
        }
    }

    static func confidenceThreshold(for attempt: Int) -> Double {
        switch attempt {
        case ..<2: return 0.85
        case 2..<4: return 0.75
        default: return 0.70
        }
    }

    static func buildPrompt(_ ctx: GrindPromptContext) -> String {
        let tone = tone(for: ctx.attempt)
        let hours = max(1, ctx.sleepSeconds / 3600)
        let base = "You are having a real-time phone conversation with someone you're waking up. You're their warm but persistent morning coach — like a friend who called to make sure they get up."
        let style: String
        switch tone {
        case .encouraging:
            style = "Be empathetic and understanding. Acknowledge mornings are hard, but gently guide them toward action."
        case .firm:
            style = "Stay warm but be more direct. Remind them THEY set this alarm, THEY have a goal — help them take the next step."
        case .exasperated:
            style = "Sound a bit exasperated but still caring. Push them to commit to something specific RIGHT NOW."
        }
        
        // Build context about their response
        let responseContext: String
        if let lastTranscript = ctx.lastTranscript, !lastTranscript.isEmpty {
            // Check for questions
            let isQuestion = lastTranscript.contains("?") ||
                            lastTranscript.lowercased().contains("what do") ||
                            lastTranscript.lowercased().contains("what should") ||
                            lastTranscript.lowercased().contains("how do")
            
            // Check for unclear speech patterns
            let isUnclear = lastTranscript.count < 10 || 
                           lastTranscript.contains("How about") || 
                           lastTranscript.contains("um") || 
                           lastTranscript.contains("uh") ||
                           lastTranscript.hasSuffix(".") && lastTranscript.count < 15
            
            // Check for suspiciously easy responses
            let isSuspicious = lastTranscript.lowercased().contains("i'm up") ||
                              lastTranscript.lowercased().contains("im up") ||
                              lastTranscript.lowercased() == "okay" ||
                              lastTranscript.lowercased() == "fine"
            
            // Check for coherent, long explanations (person is clearly awake)
            let isCoherent = lastTranscript.count > 50
            
            if isQuestion {
                responseContext = "They asked: '\(lastTranscript)'. ANSWER their question directly! Then guide them toward taking action. If they're asking what to do, give them a specific suggestion based on their goal."
            } else if isCoherent {
                responseContext = "They gave a long, coherent response: '\(lastTranscript)'. A sleepy person doesn't write essays — they're clearly awake. Accept reasonable explanations."
            } else if isUnclear {
                responseContext = "They mumbled or gave an unclear response: '\(lastTranscript)'. Warmly ask them to speak up and tell you what they're actually doing right now."
            } else if isSuspicious {
                responseContext = "They said: '\(lastTranscript)'. This sounds too easy — be skeptical! Ask them to prove it: what are they doing RIGHT NOW? Are they actually out of bed?"
            } else {
                responseContext = "They said: '\(lastTranscript)'. Respond to what they said, acknowledge their feelings if they're struggling, and guide them toward a specific action."
            }
        } else {
            responseContext = "This is their first response. Warmly ask what they're doing right now to get up."
        }
        
        return "\(base) Tone: \(tone.rawValue). \(style) User's goal: \(ctx.goal). Slept about \(hours) hours. \(responseContext) Keep your response under 30 words, warm but persistent. THIS IS A CONVERSATION — respond to them, don't just generate a message."
    }
    
    static func buildGoodLuckPrompt(goal: String, userResponse: String) -> String {
        return """
        You are a warm morning coach saying goodbye. The user proved they're up for their goal: \(goal). Their response was: '\(userResponse)'.
        
        This is your FAREWELL. Make it count:
        - Acknowledge you're trusting them and letting them go
        - Add warmth and personality
        - Optionally add playful accountability like "Don't blame me tomorrow if you fall back asleep!"
        - Reference that you only talk once a day
        
        Keep it under 30 words. Be genuine, not over-the-top.
        
        Examples: "Alright, I'm trusting you on this one. Go crush it — and don't come crying to me tomorrow!" or "That's what I like to hear. You're on your own now. Make it count!"
        """
    }
    
    // MARK: - Structured Output for Wake-up Verification
    
    static func buildVerificationPrompt(_ ctx: GrindPromptContext) -> String {
        let hours = max(1, ctx.sleepSeconds / 3600)
        
        return """
        You are having a real-time phone conversation with someone you're waking up. You're their warm but persistent morning coach — like a friend who called to make sure they get up.
        
        CONTEXT:
        - Their goal: \(ctx.goal)
        - Hours slept: ~\(hours)
        - What they just said: "\(ctx.lastTranscript ?? "No response")"
        
        THIS IS A CONVERSATION, NOT A MESSAGE GENERATOR:
        - RESPOND to what they actually said. If they ask a question, ANSWER it.
        - If they say "what do you want me to do?" — tell them! Give a specific suggestion.
        - If they're confused, help them. If they're grumpy, acknowledge it but keep them moving.
        - Guide the conversation toward them taking action, don't just acknowledge and repeat.
        
        Respond in this EXACT JSON format:
        {
            "isAwake": true/false,
            "reason": "Brief explanation of your decision",
            "reply": "Your conversational response (under 35 words)"
        }
        
        WHEN TO SET isAwake = TRUE (and say goodbye):
        - They describe a SPECIFIC action they're doing RIGHT NOW ("I'm walking to the bathroom")
        - They give a long, coherent response (sleepy people don't write essays)
        - They commit to something concrete ("I'll start with coffee then head to the gym")
        
        WHEN TO KEEP isAwake = FALSE (and continue the conversation):
        - Vague agreement like "okay" or "I'm up" without proof
        - They ask questions — answer them and guide them forward
        - Excuses or requests for more time — empathize but redirect
        
        If isAwake is TRUE, your reply is a FAREWELL — acknowledge you trust them, add playful accountability, make it a proper goodbye.
        """
    }
    
    struct VerificationResponse: Codable {
        let isAwake: Bool
        let reason: String
        let reply: String
    }
}
