import Foundation

enum APIKeyManager {
    static var miniMaxAPIKey: String? {
        ProcessInfo.processInfo.environment["MINIMAX_API_KEY"]
    }

    static var isMiniMaxConfigured: Bool {
        guard let key = miniMaxAPIKey else { return false }
        return !key.isEmpty
    }
}
