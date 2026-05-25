import Foundation

struct SupabaseServiceConfig {
    let url: String
    let anonKey: String
}

final class SupabaseService {
    private let config: SupabaseServiceConfig
    private let http = HTTPClient.shared

    init(config: SupabaseServiceConfig) { self.config = config }

    private var baseHeaders: [String: String] {
        [
            "apikey": config.anonKey,
            "Authorization": "Bearer \(config.anonKey)"
        ]
    }

    func insertUser(_ user: User) async throws -> User {
        let url = "\(config.url)/rest/v1/Users"
        var headers = baseHeaders
        headers["Prefer"] = "return=representation"
        struct Wrapper: Encodable { let user_id: String; let email: String?; let primary_goal: String?; let preferred_wake_time: String? }
        let body = [Wrapper(user_id: user.user_id, email: user.email, primary_goal: user.primary_goal, preferred_wake_time: user.preferred_wake_time)]
        let result: [User] = try await http.post(url, body: body, headers: headers)
        return result.first ?? user
    }

    func upsertGoal(_ goal: Goal) async throws -> Goal {
        let url = "\(config.url)/rest/v1/Goals"
        var headers = baseHeaders
        headers["Prefer"] = "return=representation"
        let body = [goal]
        let result: [Goal] = try await http.post(url, body: body, headers: headers)
        return result.first ?? goal
    }

    func logVerification(_ log: VerificationLog) async throws {
        let url = "\(config.url)/rest/v1/VerificationLogs"
        let _ : [VerificationLog] = try await http.post(url, body: [log], headers: baseHeaders)
    }
}


