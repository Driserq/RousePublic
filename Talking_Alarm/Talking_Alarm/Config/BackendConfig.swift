import Foundation

struct BackendConfig {
    let baseURL: String
    let sharedKey: String
    let longPollTimeoutSeconds: Int
    let maxPollAttempts: Int

    static let `default` = BackendConfig(
        baseURL: AppConfig.shared.backendBaseURL,
        sharedKey: AppConfig.shared.backendSharedKey,
        longPollTimeoutSeconds: 45,
        maxPollAttempts: 3
    )
}
