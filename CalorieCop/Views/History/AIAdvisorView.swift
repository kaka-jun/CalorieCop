import SwiftUI
import SwiftData

struct AIAdvisorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatMessage.createdAt) private var chatMessages: [ChatMessage]

    let foodEntries: [FoodEntry]
    let userGoal: UserGoal?
    let currentWeight: Double?
    let weightHistory: [WeightEntry]

    @State private var userQuestion = ""
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false

    private var summary: String {
        var summaryLines: [String] = []

        // Goal information
        if let goal = userGoal {
            summaryLines.append("【用户目标设定】")
            summaryLines.append("- 目标体重: \(goal.targetWeight)kg")
            summaryLines.append("- 身高: \(goal.height)cm, 年龄: \(goal.age)岁, 性别: \(goal.gender == "male" ? "男" : "女")")
            summaryLines.append("- 活动水平: \(activityLevelText(goal.activityLevel))")

            if let targetDate = goal.targetDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy年M月d日"
                summaryLines.append("- 目标日期: \(formatter.string(from: targetDate))")

                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
                summaryLines.append("- 距目标还有: \(daysLeft)天")
            }

            if let weight = currentWeight {
                summaryLines.append("- 当前体重: \(String(format: "%.1f", weight))kg")
                summaryLines.append("- 需要减重: \(String(format: "%.1f", weight - goal.targetWeight))kg")

                let bmr = goal.calculateBMR(currentWeight: weight)
                let tdee = goal.calculateTDEE(currentWeight: weight)
                let recommended = goal.recommendedDailyCalories(currentWeight: weight)

                summaryLines.append("- 基础代谢(BMR): \(Int(bmr))kcal")
                summaryLines.append("- 每日总消耗(TDEE): \(Int(tdee))kcal")
                summaryLines.append("- 建议每日摄入: \(Int(recommended))kcal")
            }
            summaryLines.append("")
        }

        // Weight history
        if !weightHistory.isEmpty {
            summaryLines.append("【体重变化记录】")
            for entry in weightHistory.prefix(10) {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日"
                summaryLines.append("- \(formatter.string(from: entry.date)): \(String(format: "%.1f", entry.weight))kg")
            }
            summaryLines.append("")
        }

        // Food entries
        let grouped = Dictionary(grouping: foodEntries) { entry in
            Calendar.current.startOfDay(for: entry.createdAt)
        }.sorted { $0.key > $1.key }

        summaryLines.append("【最近饮食记录】")

        if grouped.isEmpty {
            summaryLines.append("暂无记录")
        } else {
            for day in grouped.prefix(7) {
                let totalCal = day.value.reduce(0) { $0 + $1.calories }
                let totalProtein = day.value.reduce(0) { $0 + $1.protein }
                let totalCarbs = day.value.reduce(0) { $0 + $1.carbohydrates }
                let totalFat = day.value.reduce(0) { $0 + $1.fat }

                let dateStr = formatDate(day.key)
                let foods = day.value.map { $0.foodName }.joined(separator: "、")

                summaryLines.append("\(dateStr): \(totalCal.formattedCalories)kcal (蛋白\(totalProtein.formattedGrams)g, 碳水\(totalCarbs.formattedGrams)g, 脂肪\(totalFat.formattedGrams)g) - 食物: \(foods)")
            }
        }

        return summaryLines.joined(separator: "\n")
    }

    private func activityLevelText(_ level: String) -> String {
        switch level {
        case "sedentary": return "久坐（很少运动）"
        case "light": return "轻度（每周1-3次运动）"
        case "moderate": return "中度（每周3-5次运动）"
        case "active": return "活跃（每周6-7次运动）"
        case "very_active": return "非常活跃（运动员/体力劳动）"
        default: return level
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Conversation
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Welcome message
                            AIMessageBubble(content: "你好！我是你的AI营养顾问。我可以看到你的目标设定、体重变化和饮食记录。\n\n你可以问我：\n• 按我的计划多久能达到目标？\n• 我这周吃得健康吗？\n• 我的热量缺口够吗？\n• 有什么改善建议？")

                            ForEach(chatMessages) { message in
                                if message.role == "user" {
                                    UserMessageBubble(content: message.content)
                                        .id(message.id)
                                } else {
                                    AIMessageBubble(content: message.content)
                                        .id(message.id)
                                }
                            }

                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatMessages.count) {
                        withAnimation {
                            if let lastMessage = chatMessages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input
                HStack(spacing: 12) {
                    TextField("问问AI顾问...", text: $userQuestion, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)

                    Button {
                        Task {
                            await sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(userQuestion.isEmpty ? .gray : .blue)
                    }
                    .disabled(userQuestion.isEmpty || isLoading)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("AI顾问")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !chatMessages.isEmpty {
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("清空聊天记录", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    deleteAllMessages()
                }
            } message: {
                Text("确定要删除所有聊天记录吗？此操作无法撤销。")
            }
        }
    }

    private func deleteAllMessages() {
        for message in chatMessages {
            modelContext.delete(message)
        }
    }

    private func sendMessage() async {
        let question = userQuestion
        userQuestion = ""

        // Save user message
        let userMessage = ChatMessage(role: "user", content: question)
        modelContext.insert(userMessage)

        isLoading = true

        do {
            let response = try await askAI(question: question)
            // Save assistant message
            let assistantMessage = ChatMessage(role: "assistant", content: response)
            modelContext.insert(assistantMessage)
        } catch {
            let errorMessage = ChatMessage(role: "assistant", content: "抱歉，出现了错误：\(error.localizedDescription)")
            modelContext.insert(errorMessage)
        }

        isLoading = false
    }

    private func askAI(question: String) async throws -> String {
        guard let apiKey = APIKeyManager.miniMaxAPIKey else {
            throw AIServiceError.apiKeyNotConfigured
        }

        let systemPrompt = """
你是一个专业的营养顾问和健身教练AI。用户会向你咨询关于减重、饮食和健康目标的问题。

以下是用户的完整数据：

\(summary)

请根据以上数据回答用户的问题。提供具体、实用、有数据支持的建议。
- 如果用户问多久能达到目标，请根据当前热量缺口和目标体重差距计算（每减1kg约需消耗7700kcal）
- 回答要简洁友好，使用中文
- 如果数据不足，请指出需要哪些信息
"""

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Add conversation history from persisted messages
        for msg in chatMessages {
            messages.append(["role": msg.role, "content": msg.content])
        }

        let requestBody: [String: Any] = [
            "model": "MiniMax-Text-01",
            "messages": messages
        ]

        var request = URLRequest(url: URL(string: "https://api.minimaxi.chat/v1/text/chatcompletion_v2")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct Response: Decodable {
            let choices: [Choice]
            struct Choice: Decodable {
                let message: Message
                struct Message: Decodable {
                    let content: String
                }
            }
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.choices.first?.message.content ?? "无法获取回复"
    }

    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            return formatter.string(from: date)
        }
    }
}

struct UserMessageBubble: View {
    let content: String

    var body: some View {
        HStack {
            Spacer()
            Text(content)
                .padding(12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct AIMessageBubble: View {
    let content: String

    var body: some View {
        HStack {
            Text(content)
                .padding(12)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
    }
}

#Preview {
    AIAdvisorView(foodEntries: [], userGoal: nil, currentWeight: nil, weightHistory: [])
        .modelContainer(for: ChatMessage.self, inMemory: true)
}
