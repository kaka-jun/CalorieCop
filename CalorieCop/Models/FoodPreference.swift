import Foundation
import SwiftData

@Model
final class FoodPreference {
    var id: UUID
    var keyword: String          // 用户输入的关键词，如 "咖啡牛奶"
    var defaultDescription: String  // 默认描述，如 "150ml全脂牛奶"
    var createdAt: Date
    var usageCount: Int          // 使用次数，用于排序

    init(keyword: String, defaultDescription: String) {
        self.id = UUID()
        self.keyword = keyword
        self.defaultDescription = defaultDescription
        self.createdAt = Date()
        self.usageCount = 1
    }
}
