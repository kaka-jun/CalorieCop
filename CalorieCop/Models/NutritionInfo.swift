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
    let daysAgo: Int?

    enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case grams, calories, protein, carbohydrates, fat, confidence, notes
        case daysAgo = "days_ago"
    }

    // Computed property to get the actual date
    var entryDate: Date {
        let days = daysAgo ?? 0
        return Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    // Custom initializer with default values
    init(foodName: String, grams: Double, calories: Double, protein: Double,
         carbohydrates: Double, fat: Double, confidence: String,
         notes: String? = nil, daysAgo: Int? = 0) {
        self.foodName = foodName
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.confidence = confidence
        self.notes = notes
        self.daysAgo = daysAgo
    }
}
