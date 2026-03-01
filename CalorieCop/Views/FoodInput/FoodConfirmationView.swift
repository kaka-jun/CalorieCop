import SwiftUI

struct FoodConfirmationView: View {
    @Environment(\.dismiss) private var dismiss

    let rawInput: String
    let nutrition: NutritionInfo
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    nutritionSection

                    if let notes = nutrition.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    confidenceIndicator
                }
                .padding()
            }
            .navigationTitle("确认食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(nutrition.foodName)
                .font(.title2)
                .fontWeight(.bold)

            Text("\(nutrition.grams.formattedGrams)g")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("原始输入: \(rawInput)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var nutritionSection: some View {
        VStack(spacing: 12) {
            Text("营养成分")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                NutritionCard(
                    title: "热量",
                    value: nutrition.calories.formattedCalories,
                    unit: "kcal",
                    color: .orange
                )
                NutritionCard(
                    title: "蛋白质",
                    value: nutrition.protein.formattedGrams,
                    unit: "g",
                    color: .red
                )
            }

            HStack(spacing: 12) {
                NutritionCard(
                    title: "碳水",
                    value: nutrition.carbohydrates.formattedGrams,
                    unit: "g",
                    color: .blue
                )
                NutritionCard(
                    title: "脂肪",
                    value: nutrition.fat.formattedGrams,
                    unit: "g",
                    color: .yellow
                )
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注")
                .font(.headline)

            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var confidenceIndicator: some View {
        HStack {
            Image(systemName: confidenceIcon)
                .foregroundStyle(confidenceColor)
            Text("置信度: \(confidenceText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var confidenceIcon: String {
        switch nutrition.confidence {
        case "high": return "checkmark.circle.fill"
        case "medium": return "questionmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch nutrition.confidence {
        case "high": return .green
        case "medium": return .orange
        default: return .red
        }
    }

    private var confidenceText: String {
        switch nutrition.confidence {
        case "high": return "高"
        case "medium": return "中"
        default: return "低"
        }
    }
}

#Preview {
    FoodConfirmationView(
        rawInput: "一碗米饭",
        nutrition: NutritionInfo(
            foodName: "米饭",
            grams: 200,
            calories: 232,
            protein: 4.3,
            carbohydrates: 50.8,
            fat: 0.6,
            confidence: "high",
            notes: "按照普通家用碗估算份量"
        )
    ) {
        print("Confirmed")
    }
}
