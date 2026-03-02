import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitService = HealthKitService()

    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    @Query private var goals: [UserGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var manualWeightEntries: [WeightEntry]

    @State private var useAppleWatchData = true
    @State private var goalRefreshTrigger = UUID()

    private var currentGoal: UserGoal? { goals.first }

    private var hasAppleWatchData: Bool {
        healthKitService.totalCaloriesBurned > 0
    }

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

    private var currentWeight: Double? {
        let latestManual = manualWeightEntries.first?.weight
        let latestHealthKit = healthKitService.currentWeight
        return latestHealthKit ?? latestManual
    }

    private var calculatedTDEE: Double? {
        guard let goal = currentGoal, let weight = currentWeight else { return nil }
        return goal.calculateTDEE(currentWeight: weight)
    }

    private var totalCaloriesBurned: Double {
        if useAppleWatchData && hasAppleWatchData {
            guard let goal = currentGoal, let weight = currentWeight else {
                return healthKitService.totalCaloriesBurned
            }
            let bmr = goal.calculateBMR(currentWeight: weight)
            return bmr + healthKitService.activeCaloriesBurned
        }
        return calculatedTDEE ?? healthKitService.totalCaloriesBurned
    }

    private var activeCalories: Double {
        guard let goal = currentGoal, let weight = currentWeight else { return 0 }
        if useAppleWatchData && hasAppleWatchData {
            return healthKitService.activeCaloriesBurned
        }
        return goal.calculateTDEE(currentWeight: weight) - goal.calculateBMR(currentWeight: weight)
    }

    private var bmrCalories: Double {
        guard let goal = currentGoal, let weight = currentWeight else { return 0 }
        return goal.calculateBMR(currentWeight: weight)
    }

    private var isShowingEstimated: Bool {
        !useAppleWatchData || !hasAppleWatchData
    }

    private var recommendedCalories: Double? {
        guard let goal = currentGoal, let weight = currentWeight else { return nil }
        return goal.recommendedDailyCalories(currentWeight: weight)
    }

    private var dailyGoal: Double {
        recommendedCalories ?? 2000
    }

    // 缺口 = 消耗 - 摄入
    private var deficit: Double {
        totalCaloriesBurned - totalCaloriesConsumed
    }

    // 还可吃 = 目标 - 已摄入
    private var remainingCalories: Double {
        dailyGoal - totalCaloriesConsumed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Main calorie card
                    calorieOverviewCard
                        .padding(.horizontal)

                    // Remaining and goal
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("还可吃 \(Int(max(0, remainingCalories))) kcal")
                                .font(.subheadline)
                        }

                        Spacer()

                        Text("目标 \(Int(dailyGoal).formatted()) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Data source note
                    Text("基于身体数据\(isShowingEstimated ? "估算" : "实时")消耗")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Calorie burn breakdown
                    CalorieBurnBreakdownView(
                        bmr: bmrCalories,
                        active: activeCalories,
                        total: totalCaloriesBurned,
                        isEstimated: isShowingEstimated
                    )
                    .padding(.horizontal)

                    // Nutrition breakdown
                    NutritionBreakdownView(
                        protein: totalProtein,
                        carbs: totalCarbs,
                        fat: totalFat
                    )
                    .padding(.horizontal)

                    // Today's food list
                    foodListSection
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日概览")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        useAppleWatchData.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: useAppleWatchData ? "applewatch" : "function")
                                .font(.caption)
                            Text(useAppleWatchData ? "实时" : "估算")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(useAppleWatchData ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundStyle(useAppleWatchData ? .green : .orange)
                        .clipShape(Capsule())
                    }
                    .disabled(!hasAppleWatchData)
                    .opacity(hasAppleWatchData ? 1 : 0.5)
                }
            }
            .task {
                await healthKitService.requestAuthorization()
            }
            .refreshable {
                await healthKitService.fetchTodayCaloriesBurned()
            }
            .onChange(of: currentGoal?.targetDate) {
                goalRefreshTrigger = UUID()
            }
            .onChange(of: currentGoal?.updatedAt) {
                goalRefreshTrigger = UUID()
            }
        }
    }

    private var calorieOverviewCard: some View {
        HStack(spacing: 0) {
            // 摄入
            VStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("\(Int(totalCaloriesConsumed))")
                    .font(.title)
                    .fontWeight(.bold)
                Text("摄入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Text("-")
                .font(.title2)
                .foregroundStyle(.secondary)

            // 消耗
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                Text("\(Int(totalCaloriesBurned))")
                    .font(.title)
                    .fontWeight(.bold)
                Text("消耗")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Text("=")
                .font(.title2)
                .foregroundStyle(.secondary)

            // 缺口
            VStack(spacing: 4) {
                Image(systemName: deficit >= 0 ? "bed.double.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(deficit >= 0 ? .purple : .red)
                Text("\(Int(abs(deficit)))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(deficit >= 0 ? Color.primary : Color.red)
                Text(deficit >= 0 ? "缺口" : "超出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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

            if todayEntries.isEmpty {
                VStack(spacing: 12) {
                    Image("mascot_avatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                    Text("还没有记录哦")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                FoodListView()
                    .frame(minHeight: 200)
            }
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [FoodEntry.self, UserGoal.self, WeightEntry.self], inMemory: true)
}

// MARK: - Calorie Burn Breakdown View

struct CalorieBurnBreakdownView: View {
    let bmr: Double
    let active: Double
    let total: Double
    var isEstimated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日消耗明细")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                BurnItem(icon: "bed.double.fill", value: Int(bmr), label: "基础代谢", color: .purple)
                BurnItem(icon: "figure.run", value: Int(active), label: isEstimated ? "活动消耗(估)" : "活动消耗", color: .green)
                BurnItem(icon: "flame.fill", value: Int(total), label: "总消耗", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BurnItem: View {
    let icon: String
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value.formatted())")
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nutrition Breakdown View

struct NutritionBreakdownView: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("营养摄入")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                NutritionStatCard(label: "蛋白质", value: protein, color: .red)
                NutritionStatCard(label: "碳水", value: carbs, color: .blue)
                NutritionStatCard(label: "脂肪", value: fat, color: .yellow)
            }
        }
    }
}

struct NutritionStatCard: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .foregroundStyle(color)
                .clipShape(Capsule())

            Text(String(format: "%.1f", value))
                .font(.title2)
                .fontWeight(.bold)

            Text("g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
