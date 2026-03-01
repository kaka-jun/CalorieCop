import SwiftUI

struct FoodInputView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var parsedNutrition: NutritionInfo?
    @State private var errorMessage: String?
    @State private var showConfirmation = false

    private let aiService: AIServiceProtocol = MiniMaxService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                instructionText

                inputField

                if let error = errorMessage {
                    errorView(error)
                }

                Spacer()

                parseButton
            }
            .padding()
            .navigationTitle("记录食物")
            .sheet(isPresented: $showConfirmation) {
                if let nutrition = parsedNutrition {
                    FoodConfirmationView(
                        rawInput: inputText,
                        nutrition: nutrition
                    ) {
                        saveFoodEntry()
                    }
                }
            }
        }
    }

    private var instructionText: some View {
        Text("用自然语言描述你吃的食物")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var inputField: some View {
        TextField("例如：一碗米饭、两个鸡蛋、一杯牛奶", text: $inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .lineLimit(3...6)
    }

    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var parseButton: some View {
        Button {
            Task {
                await parseFood()
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                    Text("解析食物")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(inputText.isEmpty ? Color.gray : Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(inputText.isEmpty || isLoading)
    }

    private func parseFood() async {
        isLoading = true
        errorMessage = nil

        do {
            let nutrition = try await aiService.parseFoodInput(inputText)
            parsedNutrition = nutrition
            showConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveFoodEntry() {
        guard let nutrition = parsedNutrition else { return }

        let entry = FoodEntry(rawInput: inputText, nutrition: nutrition)
        modelContext.insert(entry)

        inputText = ""
        parsedNutrition = nil
        showConfirmation = false
    }
}

#Preview {
    FoodInputView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
