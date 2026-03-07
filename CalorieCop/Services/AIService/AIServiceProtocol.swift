import Foundation

protocol AIServiceProtocol {
    func parseFoodInput(_ input: String) async throws -> NutritionInfo
    func parseFoodInputMultiple(_ input: String, preferences: [FoodPreference]) async throws -> [NutritionInfo]
}

enum AIServiceError: LocalizedError {
    case apiKeyNotConfigured
    case invalidResponse
    case networkError(Error)
    case parsingError(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "MiniMax API key not configured. Please set MINIMAX_API_KEY environment variable."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Failed to parse food input: \(message)"
        }
    }
}
