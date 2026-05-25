import Foundation

/// Represents a fully configured API call to the LLM.
/// This struct encapsulates everything needed to make the request,
/// decoupling the specific prompt logic from the execution service.
struct LLMRequest {
    // MARK: - Core Parameters
    let model: String
    let temperature: Double
    let maxTokens: Int
    
    // MARK: - Prompt Content
    let systemMessage: String
    let userMessage: String
    
    // MARK: - Optional Tuning
    let presencePenalty: Double
    let frequencyPenalty: Double
    
    // MARK: - Default Configuration
    /// Creates a request with standard defaults if specific params aren't provided
    init(
        model: String = "gpt-4o-mini",
        temperature: Double = 0.8,
        maxTokens: Int = 150,
        systemMessage: String,
        userMessage: String,
        presencePenalty: Double = 0.6,
        frequencyPenalty: Double = 0.3
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemMessage = systemMessage
        self.userMessage = userMessage
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}
