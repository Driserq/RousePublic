import Foundation

enum BackendServiceError: Error {
    case invalidURL
    case missingResponse
    case timeout
    case decodingFailed
    case invalidAudio
    case httpStatus(Int, String)
}

final class BackendService {
    static let shared = BackendService()

    private let config: BackendConfig

    init(config: BackendConfig = .default) {
        self.config = config
    }

    func performConversationTurn(request: LLMRequest, voice: ElevenLabsConfig) async throws -> BackendConversationTurnResult {
        let job = try await submitConversationTurn(request: request, voice: voice)
        return try await pollResult(jobId: job.jobId)
    }

    func generateConsolidatedWakeMessage(
        goal: String,
        personality: String,
        isNap: Bool,
        llmConfig: OpenAIConfig,
        voice: ElevenLabsConfig
    ) async throws -> BackendConsolidatedMessageResult {
        let job = try await submitConsolidatedWakeMessage(
            goal: goal,
            personality: personality,
            isNap: isNap,
            llmConfig: llmConfig,
            voice: voice
        )
        return try await pollResult(jobId: job.jobId)
    }

    func generatePersonalMessage(
        systemMessage: String,
        userMessage: String,
        llmConfig: OpenAIConfig,
        voice: ElevenLabsConfig
    ) async throws -> BackendPersonalMessageResult {
        let job = try await submitPersonalMessage(
            systemMessage: systemMessage,
            userMessage: userMessage,
            llmConfig: llmConfig,
            voice: voice
        )
        return try await pollResult(jobId: job.jobId)
    }

    func reportIssue(_ report: BackendReportIssueRequest) async throws {
        let _: BackendReportIssueResponse = try await post(path: "/v1/report-issue", body: report)
    }

    func deleteAccount(_ request: BackendDeleteAccountRequest) async throws {
        let _: BackendDeleteAccountResponse = try await post(path: "/v1/account/delete", body: request)
    }

    func decodeBase64Audio(_ base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else {
            throw BackendServiceError.invalidAudio
        }
        return data
    }

    // MARK: - Requests

    private func submitConversationTurn(request: LLMRequest, voice: ElevenLabsConfig) async throws -> BackendJobResponse {
        let body = BackendConversationTurnRequest(
            llm: BackendLLMConfig(from: request),
            voice: BackendVoiceConfig(from: voice)
        )
        return try await post(path: "/v1/conversation/turn", body: body)
    }

    private func submitConsolidatedWakeMessage(
        goal: String,
        personality: String,
        isNap: Bool,
        llmConfig: OpenAIConfig,
        voice: ElevenLabsConfig
    ) async throws -> BackendJobResponse {
        let body = BackendConsolidatedMessageRequest(
            goal: goal,
            personality: personality,
            isNap: isNap,
            llm: BackendLLMConfig(from: llmConfig),
            voice: BackendVoiceConfig(from: voice)
        )
        return try await post(path: "/v1/onboarding/wake-message", body: body)
    }

    private func submitPersonalMessage(
        systemMessage: String,
        userMessage: String,
        llmConfig: OpenAIConfig,
        voice: ElevenLabsConfig
    ) async throws -> BackendJobResponse {
        let body = BackendPersonalMessageRequest(
            llm: BackendLLMConfig(
                model: llmConfig.model,
                temperature: llmConfig.temperature,
                maxTokens: llmConfig.maxTokens,
                presencePenalty: llmConfig.presencePenalty,
                frequencyPenalty: llmConfig.frequencyPenalty,
                systemMessage: systemMessage,
                userMessage: userMessage
            ),
            voice: BackendVoiceConfig(from: voice)
        )
        return try await post(path: "/v1/tts/personal-message", body: body)
    }

    private func pollResult<T: Decodable>(jobId: String) async throws -> T {
        var attempts = 0
        while attempts < config.maxPollAttempts {
            attempts += 1
            if let result: T = try await longPoll(jobId: jobId) {
                return result
            }
        }
        throw BackendServiceError.timeout
    }

    private func longPoll<T: Decodable>(jobId: String) async throws -> T? {
        guard var urlComponents = URLComponents(string: "\(config.baseURL)/v1/jobs/\(jobId)/long-poll") else {
            throw BackendServiceError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "timeout", value: "\(config.longPollTimeoutSeconds)")
        ]
        guard let url = urlComponents.url else {
            throw BackendServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.sharedKey, forHTTPHeaderField: "X-TalkingAlarm-Key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendServiceError.missingResponse
        }
        if http.statusCode == 204 {
            return nil
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyString = String(data: data, encoding: .utf8) ?? "(no body)"
            DebugLogger.log("[BackendService] longPoll failed: status=\(http.statusCode) body=\(bodyString.prefix(500))")
            throw BackendServiceError.httpStatus(http.statusCode, bodyString)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "(no body)"
            DebugLogger.log("[BackendService] longPoll decode error: \(error) body=\(bodyString.prefix(500))")
            throw BackendServiceError.decodingFailed
        }
    }

    private func post<T: Decodable, U: Encodable>(path: String, body: U) async throws -> T {
        guard let url = URL(string: "\(config.baseURL)\(path)") else {
            throw BackendServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.sharedKey, forHTTPHeaderField: "X-TalkingAlarm-Key")
        request.httpBody = try JSONEncoder().encode(body)

        DebugLogger.log("[BackendService] POST \(path)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendServiceError.missingResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let bodyString = String(data: data, encoding: .utf8) ?? "(no body)"
            DebugLogger.log("[BackendService] POST failed: status=\(http.statusCode) body=\(bodyString.prefix(500))")
            throw BackendServiceError.httpStatus(http.statusCode, bodyString)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let bodyString = String(data: data, encoding: .utf8) ?? "(no body)"
            DebugLogger.log("[BackendService] POST decode error: \(error) body=\(bodyString.prefix(500))")
            throw BackendServiceError.decodingFailed
        }
    }
}

// MARK: - DTOs

struct BackendJobResponse: Decodable {
    let jobId: String
}

struct BackendConversationTurnRequest: Encodable {
    let llm: BackendLLMConfig
    let voice: BackendVoiceConfig
}

struct BackendConsolidatedMessageRequest: Encodable {
    let goal: String
    let personality: String
    let isNap: Bool
    let llm: BackendLLMConfig
    let voice: BackendVoiceConfig
}

struct BackendPersonalMessageRequest: Encodable {
    let llm: BackendLLMConfig
    let voice: BackendVoiceConfig
}

struct BackendReportIssueRequest: Encodable {
    let message: String
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let goal: String
    let lastPromptText: String?
    let lastSSML: String?
    let timestamp: String
}

struct BackendDeleteAccountRequest: Encodable {
    let reason: String
    let timestamp: String
}

struct BackendLLMConfig: Encodable {
    let model: String
    let temperature: Double
    let maxTokens: Int
    let presencePenalty: Double
    let frequencyPenalty: Double
    let systemMessage: String
    let userMessage: String

    init(from request: LLMRequest) {
        self.model = request.model
        self.temperature = request.temperature
        self.maxTokens = request.maxTokens
        self.presencePenalty = request.presencePenalty
        self.frequencyPenalty = request.frequencyPenalty
        self.systemMessage = request.systemMessage
        self.userMessage = request.userMessage
    }

    init(from config: OpenAIConfig) {
        self.model = config.model
        self.temperature = config.temperature
        self.maxTokens = config.maxTokens
        self.presencePenalty = config.presencePenalty
        self.frequencyPenalty = config.frequencyPenalty
        self.systemMessage = config.systemPrompt
        self.userMessage = config.userPromptTemplate
    }

    init(
        model: String,
        temperature: Double,
        maxTokens: Int,
        presencePenalty: Double,
        frequencyPenalty: Double,
        systemMessage: String,
        userMessage: String
    ) {
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
        self.systemMessage = systemMessage
        self.userMessage = userMessage
    }
}

struct BackendVoiceConfig: Encodable {
    let voiceId: String
    let modelId: String
    let stability: Double
    let similarityBoost: Double
    let style: Double
    let useSpeakerBoost: Bool

    init(from config: ElevenLabsConfig) {
        self.voiceId = config.voiceId
        self.modelId = config.modelId
        self.stability = config.stability
        self.similarityBoost = config.similarityBoost
        self.style = config.style
        self.useSpeakerBoost = config.useSpeakerBoost
    }
}

struct BackendConversationTurnResult: Decodable {
    let isAwake: Bool
    let reason: String
    let replyText: String
    let replyAudioBase64: String
    let replyAudioMime: String
}

struct BackendConsolidatedMessageResult: Decodable {
    let ssmlText: String
    let audioBase64: String
    let audioMime: String
}

struct BackendPersonalMessageResult: Decodable {
    let messageText: String
    let audioBase64: String
    let audioMime: String
}

struct BackendReportIssueResponse: Decodable {
    let status: String
}

struct BackendDeleteAccountResponse: Decodable {
    let status: String
}
