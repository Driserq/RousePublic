import Foundation

enum DebugLogger {
    #if DEBUG
    static func log(_ message: String) {
        Swift.print(message)
        Task {
            await DebugLogStore.shared.append(message)
        }
    }
    #else
    @inline(__always)
    static func log(_ message: String) {}
    #endif
}
