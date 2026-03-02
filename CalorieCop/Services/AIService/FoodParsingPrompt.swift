import Foundation

enum FoodParsingPrompt {
    static let basePrompt = """
你是一个专业的营养分析师。用户会用自然语言描述他们吃的食物，请解析并返回JSON格式的营养信息。

规则：
1. 如果用户没有指定克重，根据常识估算合理份量
2. 营养数据基于中国常见食物数据库
3. 如果食物描述模糊，选择最常见的理解方式
4. 所有数值保留1位小数
5. 注意识别时间描述：
   - "昨天"、"昨晚" = days_ago: 1
   - "前天" = days_ago: 2
   - "今天"、"刚才"、"刚刚" 或没有时间描述 = days_ago: 0
   - "上周X" = 计算距今天数
   - "X天前" = days_ago: X

【重要】必须返回严格的JSON格式，不要返回YAML或其他格式。示例：
{"food_name": "煮玉米", "grams": 200, "calories": 196, "protein": 4.2, "carbohydrates": 41.2, "fat": 2.4, "confidence": "high", "notes": "一根中等大小", "days_ago": 0}

字段说明：
- food_name: 食物名称（中文字符串）
- grams: 克重（数字）
- calories: 卡路里（数字）
- protein: 蛋白质克数（数字）
- carbohydrates: 碳水化合物克数（数字）
- fat: 脂肪克数（数字）
- confidence: "high"/"medium"/"low"
- notes: 可选备注
- days_ago: 距今天数（0=今天，1=昨天）
"""

    /// Generate system prompt with user's food preferences
    static func systemPrompt(with preferences: [FoodPreference] = []) -> String {
        var prompt = basePrompt

        if !preferences.isEmpty {
            prompt += "\n\n【用户的食物习惯】\n"
            prompt += "以下是用户的个人食物偏好设定，当用户提到这些关键词时，如果没有特别说明，请按照用户的习惯来解析：\n"

            for pref in preferences {
                prompt += "- \"\(pref.keyword)\" → \(pref.defaultDescription)\n"
            }

            prompt += "\n注意：如果用户明确指定了不同的份量或描述，以用户当前输入为准。"
        }

        return prompt
    }

    // Keep backward compatibility
    static var systemPrompt: String {
        basePrompt
    }
}
