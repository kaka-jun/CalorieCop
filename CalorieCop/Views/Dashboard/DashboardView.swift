import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitService = HealthKitService()

    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.createdAt >= startOfDay }
    }

    var totalCaloriesConsumed: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    var totalProtein: Double {
        todayEntries.reduce(0) { $0 + $1.protein }
    }

    var totalCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbohydrates }
    }

    var totalFat: Double {
        todayEntries.reduce(0) { $0 + $1.fat }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calorieBalanceSection

                    macroNutrientsSection

                    foodListSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日概览")
            .task {
                await healthKitService.requestAuthorization()
            }
            .refreshable {
                await healthKitService.fetchTodayCaloriesBurned()
            }
        }
    }

    private var calorieBalanceSection: some View {
        CalorieBalanceView(
            consumed: totalCaloriesConsumed,
            burned: healthKitService.totalCaloriesBurned
        )
    }

    private var macroNutrientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("营养摄入")
                .font(.headline)

            HStack(spacing: 12) {
                NutritionCard(
                    title: "蛋白质",
                    value: totalProtein.formattedGrams,
                    unit: "g",
                    color: .red
                )
                NutritionCard(
                    title: "碳水",
                    value: totalCarbs.formattedGrams,
                    unit: "g",
                    color: .blue
                )
                NutritionCard(
                    title: "脂肪",
                    value: totalFat.formattedGrams,
                    unit: "g",
                    color: .yellow
                )
            }
        }
    }

    private var foodListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日记录")
                    .font(.headline)
                Spacer()
                Text("\(todayEntries.count)项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FoodListView()
                .frame(minHeight: 200)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
