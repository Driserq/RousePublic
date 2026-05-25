import Foundation

struct OpenAIConfig {
    // API Configuration
    let apiKey: String
    let baseURL: String
    let model: String
    
    // Response Generation Settings
    let temperature: Double
    let maxTokens: Int
    let presencePenalty: Double
    let frequencyPenalty: Double
    
    // Prompt Templates
    let systemPrompt: String
    let userPromptTemplate: String
    let goodLuckPromptTemplate: String
    
    // Prompt Variables
    let promptVariables: [String: String]
    
    // Default Configuration
    static let `default` = OpenAIConfig(
        apiKey: AppConfig.shared.openAIKey,
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini",
        temperature: 0.8,
        maxTokens: 150,
        presencePenalty: 0.6,
        frequencyPenalty: 0.3,
        systemPrompt: "You are The Grind Master: a brisk, effective morning coach.",
        userPromptTemplate: "Tone: {tone}. User's goal: {goal}. Slept about {hours} hours. {lastReply} Ask a short question requiring them to state a concrete action they will take right now.",
        goodLuckPromptTemplate: "The user just successfully completed their wake-up challenge for their goal: {goal}. Their response was: '{userResponse}'. Give them an enthusiastic, brief good luck message that references what they said and encourages them for their day. Keep it under 25 words and make it energetic and positive. End with something like 'Now go crush it!' or 'Let's make it happen!'",
        promptVariables: [:]
    )
    
    // Alternative configurations for different use cases
    static let conservative = OpenAIConfig(
        apiKey: AppConfig.shared.openAIKey,
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini",
        temperature: 0.3,
        maxTokens: 120,
        presencePenalty: 0.2,
        frequencyPenalty: 0.1,
        systemPrompt: "You are The Grind Master: a focused, direct morning coach.",
        userPromptTemplate: "Tone: {tone}. Goal: {goal}. Sleep: {hours} hours. {lastReply} Ask for a specific 5-minute action plan.",
        goodLuckPromptTemplate: "Goal: {goal}. Response: '{userResponse}'. Give a brief, focused encouragement to start their day.",
        promptVariables: [:]
    )
    
    static let creative = OpenAIConfig(
        apiKey: AppConfig.shared.openAIKey,
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini",
        temperature: 0.9,
        maxTokens: 180,
        presencePenalty: 0.8,
        frequencyPenalty: 0.5,
        systemPrompt: "You are The Grind Master: an energetic, creative morning motivator.",
        userPromptTemplate: "Tone: {tone}. Goal: {goal}. Sleep: {hours} hours. {lastReply} Ask an inspiring question that gets them excited about taking action right now.",
        goodLuckPromptTemplate: "Goal: {goal}. Response: '{userResponse}'. Give an energetic, creative good luck message that celebrates their commitment and gets them pumped for the day ahead!",
        promptVariables: [:]
    )
    
    // Custom prompt builder
    static func custom(
        systemPrompt: String? = nil,
        userPromptTemplate: String? = nil,
        goodLuckPromptTemplate: String? = nil,
        promptVariables: [String: String]? = nil
    ) -> OpenAIConfig {
        return OpenAIConfig(
            apiKey: AppConfig.shared.openAIKey,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini",
            temperature: 0.8,
            maxTokens: 150,
            presencePenalty: 0.6,
            frequencyPenalty: 0.3,
            systemPrompt: systemPrompt ?? OpenAIConfig.default.systemPrompt,
            userPromptTemplate: userPromptTemplate ?? OpenAIConfig.default.userPromptTemplate,
            goodLuckPromptTemplate: goodLuckPromptTemplate ?? OpenAIConfig.default.goodLuckPromptTemplate,
            promptVariables: promptVariables ?? OpenAIConfig.default.promptVariables
        )
    }
}
