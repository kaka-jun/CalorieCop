import Foundation

final class MiniMaxService: AIServiceProtocol {
    private let endpoint = URL(string: "https://api.minimax.chat/v1/text/chatcompletion_v2")!
    private let model = "abab6.5s"

    func parseFoodInput(_ input: String) async throws -> NutritionInfo {
        guard let apiKey = APIKeyManager.miniMaxAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyNotConfigured
        }

        let requestBody = MiniMaxRequest(
            model: model,
            messages: [
                Message(role: "system", content: FoodParsingPrompt.systemPrompt),
                Message(role: "user", content: input)
            ],
            responseFormat: ResponseFormat(type: "json_object")
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.invalidResponse
        }

        let miniMaxResponse = try JSONDecoder().decode(MiniMaxResponse.self, from: data)

        guard let content = miniMaxResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        guard let contentData = content.data(using: .utf8) else {
            throw AIServiceError.parsingError("Failed to convert content to data")
        }

        let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: contentData)
        return nutritionInfo
    }
}

// MARK: - Request Models

private struct MiniMaxRequest: Encodable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }
}

private struct Message: Encodable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

// MARK: - Response Models

private struct MiniMaxResponse: Decodable {
    let choices: [Choice]
}

private struct Choice: Decodable {
    let message: ResponseMessage
}

private struct ResponseMessage: Decodable {
    let content: String
}
