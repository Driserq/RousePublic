import Foundation

struct OpenAIChatRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int?
    let presence_penalty: Double?
    let frequency_penalty: Double?
}

struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable { struct Message: Decodable { let role: String; let content: String }; let message: Message }
    let choices: [Choice]
}

final class OpenAIService {
    private let config: OpenAIConfig
    private let http = HTTPClient.shared

    init(config: OpenAIConfig = UserConfig.current.openAI) { 
        self.config = config
    }

    func generateReply(from request: LLMRequest) async throws -> String {
        // Use key from shared config (as LLMRequest doesn't store secrets)
        let apiKey = AppConfig.shared.openAIKey
        if apiKey.isEmpty {
            DebugLogger.log("[OpenAI] Using fallback - no API key")
            return "Okay, let's go. Tell me one concrete thing you'll do in the next 5 minutes toward your goal."
        }
        
        DebugLogger.log("[OpenAI] Generating reply with model \(request.model)")
        
        let req = OpenAIChatRequest(
            model: request.model,
            messages: [
                .init(role: "system", content: request.systemMessage),
                .init(role: "user", content: request.userMessage)
            ],
            temperature: request.temperature,
            max_tokens: request.maxTokens,
            presence_penalty: request.presencePenalty,
            frequency_penalty: request.frequencyPenalty
        )
        
        // Use standard config for base URL (unless we want to move that to LLMRequest too, but usually it's static)
        let headers = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        let url = "\(config.baseURL)/chat/completions"
        
        do {
            let response: OpenAIChatResponse = try await http.post(url, body: req, headers: headers)
            let reply = response.choices.first?.message.content ?? ""
            DebugLogger.log("[OpenAI] Generated reply: '\(reply)'")
            return reply
        } catch {
            DebugLogger.log("[OpenAIService] error: \(error)")
            return "Alright, I'm your Grind Master. What exact action will you take in the next 5 minutes?"
        }
    }

    // Keep old method for backward compatibility if needed, or deprecate
    func generateReply(prompt: String) async throws -> String {
        if config.apiKey.isEmpty {
            DebugLogger.log("[OpenAI] Using fallback - no API key")
            // Fallback for local/dev without a key
            return "Okay, let's go. Tell me one concrete thing you'll do in the next 5 minutes toward your goal."
        }
        
        DebugLogger.log("[OpenAI] Generating reply with model \(config.model)")
        
        let req = OpenAIChatRequest(
            model: config.model,
            messages: [
                .init(role: "system", content: config.systemPrompt),
                .init(role: "user", content: prompt)
            ],
            temperature: config.temperature,
            max_tokens: config.maxTokens,
            presence_penalty: config.presencePenalty,
            frequency_penalty: config.frequencyPenalty
        )
        let headers = [
            "Authorization": "Bearer \(config.apiKey)",
            "Content-Type": "application/json"
        ]
        let url = "\(config.baseURL)/chat/completions"
        do {
            let response: OpenAIChatResponse = try await http.post(url, body: req, headers: headers)
            let reply = response.choices.first?.message.content ?? ""
            DebugLogger.log("[OpenAI] Generated reply: '\(reply)'")
            return reply
        } catch {
            DebugLogger.log("[OpenAIService] error: \(error)")
            return "Alright, I'm your Grind Master. What exact action will you take in the next 5 minutes?"
        }
    }
}


