import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitService = HealthKitService()
    @Query private var goals: [UserGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var manualWeightEntries: [WeightEntry]
    @Query private var settings: [UserSettings]

    @State private var showingGoalSettings = false
    @State private var showingWeightEntry = false

    private var currentGoal: UserGoal? { goals.first }

    private var weightUnit: WeightUnit {
        settings.first?.preferredWeightUnit ?? .kg
    }

    private func formatWeight(_ kgValue: Double) -> String {
        weightUnit.format(kgValue)
    }

    private var combinedWeightHistory: [WeightRecord] {
        var allRecords: [WeightRecord] = []
        allRecords.append(contentsOf: healthKitService.dailyWeights)

        for entry in manualWeightEntries {
            allRecords.append(WeightRecord(date: entry.date, weight: entry.weight))
        }

        let grouped = Dictionary(grouping: allRecords) { record in
            Calendar.current.startOfDay(for: record.date)
        }

        return grouped.map { (_, records) in
            records.first!
        }.sorted { $0.date < $1.date }
    }

    private var currentWeight: Double? {
        let latestManual = manualWeightEntries.first?.weight
        let latestHealthKit = healthKitService.currentWeight

        if let manual = latestManual, let healthKit = latestHealthKit {
            if let manualDate = manualWeightEntries.first?.date {
                if let hkDate = healthKitService.weightHistory.first?.date {
                    return manualDate > hkDate ? manual : healthKit
                }
            }
            return healthKit
        }

        return latestManual ?? latestHealthKit
    }

    private var startWeight: Double? {
        combinedWeightHistory.first?.weight
    }

    private var weightLost: Double {
        guard let start = startWeight, let current = currentWeight else { return 0 }
        return start - current
    }

    private var progressPercent: Double {
        guard let goal = currentGoal,
              let start = startWeight,
              let current = currentWeight else { return 0 }

        let totalToLose = start - goal.targetWeight
        guard totalToLose > 0 else { return 100 }

        let lost = start - current
        return min(max(lost / totalToLose * 100, 0), 100)
    }

    private var remainingWeight: Double {
        guard let goal = currentGoal, let current = currentWeight else { return 0 }
        return max(current - goal.targetWeight, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Weight trend chart
                    weightTrendSection

                    // Current goal section
                    if let goal = currentGoal {
                        currentGoalSection(goal)
                    } else {
                        noGoalCard
                    }

                    // Mascot encouragement
                    if currentGoal != nil {
                        mascotEncouragementSection
                    }

                    // Update goal button
                    Button {
                        showingGoalSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("更新目标")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("目标管理")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingWeightEntry = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Button {
                                setWeightUnit(unit)
                            } label: {
                                HStack {
                                    Text(unit.displayName)
                                    if unit == weightUnit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .sheet(isPresented: $showingGoalSettings) {
                GoalSettingView(passedCurrentWeight: currentWeight)
            }
            .sheet(isPresented: $showingWeightEntry) {
                ManualWeightEntryView()
            }
            .task {
                await healthKitService.requestAuthorization()
            }
            .refreshable {
                await healthKitService.fetchWeightHistory()
            }
        }
    }

    private var weightTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("体重趋势")
                    .font(.headline)

                Text("过去30天变化")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if weightLost != 0 {
                    HStack(spacing: 4) {
                        Text(weightLost > 0 ? "-\(formatWeight(weightLost))" : "+\(formatWeight(abs(weightLost)))")
                            .font(.headline)
                            .foregroundStyle(weightLost > 0 ? .green : .red)

                        Text(weightLost > 0 ? "坚持就是胜利" : "继续努力")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Weight chart
            WeightChartView(
                weightHistory: combinedWeightHistory,
                targetWeight: currentGoal?.targetWeight,
                weightUnit: weightUnit
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func currentGoalSection(_ goal: UserGoal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前目标")
                .font(.headline)

            // Three weight columns
            HStack {
                WeightStatColumn(
                    label: "起始体重",
                    value: formatWeight(startWeight ?? goal.targetWeight + 5),
                    color: .secondary
                )

                Spacer()

                WeightStatColumn(
                    label: "当前体重",
                    value: formatWeight(currentWeight ?? 0),
                    color: .primary
                )

                Spacer()

                WeightStatColumn(
                    label: "目标体重",
                    value: formatWeight(goal.targetWeight),
                    color: .blue
                )
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("完成进度")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.1f%%", progressPercent))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * progressPercent / 100, height: 12)
                    }
                }
                .frame(height: 12)
            }

            // Remaining text
            Text("加油！距离目标还差\(formatWeight(remainingWeight))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mascotEncouragementSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(generateEncouragement())
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 4)
            }
            .frame(maxWidth: 250)

            Image("mascot_avatar")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundStyle(.blue)
        }
    }

    private var noGoalCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("还没有设置目标")
                .font(.headline)

            Text("设置目标体重，获取个性化的每日热量建议")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("设置目标") {
                showingGoalSettings = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func setWeightUnit(_ unit: WeightUnit) {
        if let existing = settings.first {
            existing.preferredWeightUnit = unit
        } else {
            let newSettings = UserSettings(weightUnit: unit)
            modelContext.insert(newSettings)
        }
    }

    private var daysTracking: Int {
        guard let firstRecord = combinedWeightHistory.first else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: firstRecord.date, to: Date()).day ?? 0
        return max(days, 0)
    }

    private func generateEncouragement() -> String {
        if progressPercent > 50 {
            return "太棒了！你已经完成了一半以上的目标！继续保持，胜利就在眼前！"
        } else if daysTracking > 7 {
            return "你已经坚持了\(daysTracking)天！每一步都在靠近目标，继续保持！"
        } else if daysTracking > 0 {
            return "坚持记录第\(daysTracking + 1)天！健康的生活方式需要时间，相信自己！"
        } else if weightLost > 0 {
            return "已经减了\(formatWeight(weightLost))，继续加油！每一小步都是进步！"
        } else {
            return "刚刚开始的旅程最需要坚持，每一小步都是进步！记得今天多喝水哦~"
        }
    }
}

// MARK: - Weight Stat Column

struct WeightStatColumn: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    GoalsView()
        .modelContainer(for: [UserGoal.self, WeightEntry.self, UserSettings.self], inMemory: true)
}
