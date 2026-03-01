import Foundation

struct NutritionInfo: Codable {
    let foodName: String
    let grams: Double
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let confidence: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case grams, calories, protein, carbohydrates, fat, confidence, notes
    }
}
