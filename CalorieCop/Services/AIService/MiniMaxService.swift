import Foundation
import UIKit

final class MiniMaxService: AIServiceProtocol {
    private let endpoint = URL(string: "https://api.minimaxi.chat/v1/text/chatcompletion_v2")!
    private let model = "MiniMax-Text-01"
    private let visionModel = "MiniMax-VL-01"

    func parseFoodInput(_ input: String) async throws -> NutritionInfo {
        try await parseFoodInput(input, preferences: [])
    }

    func parseFoodInput(_ input: String, preferences: [FoodPreference]) async throws -> NutritionInfo {
        guard let apiKey = APIKeyManager.miniMaxAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyNotConfigured
        }

        let systemPrompt = FoodParsingPrompt.systemPrompt(with: preferences)

        let requestBody = MiniMaxRequest(
            model: model,
            messages: [
                Message(role: "system", content: .text(systemPrompt)),
                Message(role: "user", content: .text(input))
            ]
        )

        return try await sendRequest(requestBody)
    }

    func parseFoodImage(_ image: UIImage, additionalContext: String? = nil, preferences: [FoodPreference] = []) async throws -> NutritionInfo {
        guard let apiKey = APIKeyManager.miniMaxAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.apiKeyNotConfigured
        }

        // Resize image if too large
        let resizedImage = resizeImage(image, maxDimension: 1024)

        // Convert to base64
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            throw AIServiceError.parsingError("Failed to process image")
        }
        let base64String = imageData.base64EncodedString()

        var userPrompt = "请识别这张图片中的食物，并估算其营养成分。"
        if let context = additionalContext {
            userPrompt += " 额外信息：\(context)"
        }

        let imageContent = ImageContent(
            type: "image_url",
            imageUrl: ImageURL(url: "data:image/jpeg;base64,\(base64String)")
        )

        let textContent = TextContent(type: "text", text: userPrompt)

        let systemPrompt = FoodParsingPrompt.systemPrompt(with: preferences)

        let requestBody = MiniMaxVisionRequest(
            model: visionModel,
            messages: [
                VisionMessage(role: "system", content: systemPrompt),
                VisionMessage(role: "user", content: [imageContent, textContent])
            ]
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        // Debug
        if let rawString = String(data: data, encoding: .utf8) {
            print("Vision API Response: \(rawString)")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.parsingError("API Error (\(httpResponse.statusCode)): \(errorMsg)")
        }

        let miniMaxResponse = try JSONDecoder().decode(MiniMaxResponse.self, from: data)

        guard let content = miniMaxResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        let jsonString = extractJSON(from: content)

        guard let contentData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingError("Failed to convert content to data")
        }

        let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: contentData)
        return nutritionInfo
    }

    private func sendRequest(_ requestBody: MiniMaxRequest) async throws -> NutritionInfo {
        guard let apiKey = APIKeyManager.miniMaxAPIKey else {
            throw AIServiceError.apiKeyNotConfigured
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.parsingError("API Error (\(httpResponse.statusCode)): \(errorMsg)")
        }

        let miniMaxResponse = try JSONDecoder().decode(MiniMaxResponse.self, from: data)

        guard let content = miniMaxResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse
        }

        let jsonString = extractJSON(from: content)

        guard let contentData = jsonString.data(using: .utf8) else {
            throw AIServiceError.parsingError("Failed to convert content to data")
        }

        let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: contentData)
        return nutritionInfo
    }

    private func extractJSON(from content: String) -> String {
        var cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        return cleaned
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)

        if maxSize <= maxDimension {
            return image
        }

        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}

// MARK: - Request Models

private struct MiniMaxRequest: Encodable {
    let model: String
    let messages: [Message]
}

private struct Message: Encodable {
    let role: String
    let content: MessageContent

    enum MessageContent: Encodable {
        case text(String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            }
        }
    }
}

// Vision request models
private struct MiniMaxVisionRequest: Encodable {
    let model: String
    let messages: [VisionMessage]
}

private struct VisionMessage: Encodable {
    let role: String
    let content: VisionContent

    enum VisionContent: Encodable {
        case text(String)
        case mixed([Any])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .mixed(_):
                break // Handled by custom init
            }
        }
    }

    init(role: String, content: String) {
        self.role = role
        self.content = .text(content)
    }

    init(role: String, content: [any Encodable]) {
        self.role = role
        self.content = .mixed([])
        self._content = content
    }

    private var _content: [any Encodable]?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)

        if let mixedContent = _content {
            var contentContainer = container.nestedUnkeyedContainer(forKey: .content)
            for item in mixedContent {
                if let imageContent = item as? ImageContent {
                    try contentContainer.encode(imageContent)
                } else if let textContent = item as? TextContent {
                    try contentContainer.encode(textContent)
                }
            }
        } else {
            switch content {
            case .text(let string):
                try container.encode(string, forKey: .content)
            case .mixed:
                break
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

private struct ImageContent: Encodable {
    let type: String
    let imageUrl: ImageURL

    enum CodingKeys: String, CodingKey {
        case type
        case imageUrl = "image_url"
    }
}

private struct ImageURL: Encodable {
    let url: String
}

private struct TextContent: Encodable {
    let type: String
    let text: String
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
