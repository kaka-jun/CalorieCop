import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var healthKitService = HealthKitService()

    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    @Query private var goals: [UserGoal]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]

    @State private var selectedDate = Date()
    @State private var showingAIAdvisor = false
    @State private var aiAdvisorInitialPrompt = ""

    private var currentGoal: UserGoal? { goals.first }

    private var currentWeight: Double? {
        let latestManual = weightEntries.first?.weight
        let latestHealthKit = healthKitService.currentWeight
        return latestHealthKit ?? latestManual
    }

    private var dailyGoalCalories: Double {
        guard let goal = currentGoal, let weight = currentWeight else { return 2000 }
        return goal.recommendedDailyCalories(currentWeight: weight)
    }

    private var groupedByDay: [(date: Date, entries: [FoodEntry])] {
        let grouped = Dictionary(grouping: allEntries) { entry in
            Calendar.current.startOfDay(for: entry.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, entries: $0.value) }
    }

    // Recent days for display (last 7 days with data)
    private var recentDays: [(date: Date, entries: [FoodEntry])] {
        Array(groupedByDay.prefix(7))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calendar section
                    calendarSection

                    // Daily review section
                    dailyReviewSection

                    // AI Health Tips
                    aiHealthTipsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                }
            }
            .sheet(isPresented: $showingAIAdvisor) {
                AIAdvisorView(
                    foodEntries: allEntries,
                    userGoal: currentGoal,
                    currentWeight: currentWeight,
                    weightHistory: weightEntries,
                    initialPrompt: aiAdvisorInitialPrompt
                )
            }
            .task {
                await healthKitService.requestAuthorization()
            }
        }
    }

    private var calendarSection: some View {
        VStack(spacing: 16) {
            // Month selector
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(monthYearString(from: selectedDate))
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            CalendarGridView(
                selectedDate: $selectedDate,
                entriesByDay: Dictionary(grouping: allEntries) { Calendar.current.startOfDay(for: $0.createdAt) },
                dailyGoal: dailyGoalCalories
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var dailyReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日回顾")
                .font(.headline)

            if recentDays.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("暂无记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(recentDays.prefix(3), id: \.date) { day in
                    NavigationLink {
                        DayDetailView(date: day.date, entries: day.entries)
                    } label: {
                        DayReviewCard(
                            date: day.date,
                            entries: day.entries,
                            dailyGoal: dailyGoalCalories
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var aiHealthTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("AI 健康小贴士")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image("mascot_avatar")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.blue)

                    Text(generateHealthTip())
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 12) {
                    Button {
                        aiAdvisorInitialPrompt = "请根据我最近的饮食记录，给我推荐一些健康的食谱建议，帮助我达到减重目标。"
                        showingAIAdvisor = true
                    } label: {
                        Text("食谱建议")
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Button {
                        aiAdvisorInitialPrompt = "请根据我的目标和当前情况，给我制定一个适合的运动计划。"
                        showingAIAdvisor = true
                    } label: {
                        Text("运动计划")
                            .font(.caption)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Button {
                        aiAdvisorInitialPrompt = ""
                        showingAIAdvisor = true
                    } label: {
                        Text("更多建议")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private func generateHealthTip() -> String {
        let daysOnTrack = recentDays.filter { day in
            let total = day.entries.reduce(0) { $0 + $1.calories }
            return total <= dailyGoalCalories
        }.count

        if daysOnTrack >= 5 {
            return "最近一周你已经达标了\(daysOnTrack)天！真是太棒了。建议明天多摄入一些高纤维蔬菜，你的碳水化合物比例略高，可以适当平衡一下哦~"
        } else if daysOnTrack >= 3 {
            return "继续加油！这周已经达标\(daysOnTrack)天了。记得保持均衡饮食，多喝水哦~"
        } else {
            return "新的一周，新的开始！制定一个可行的饮食计划，从今天开始吧~"
        }
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let entriesByDay: [Date: [FoodEntry]]
    let dailyGoal: Double

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private var calendar: Calendar { Calendar.current }

    private var monthDates: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var dates: [Date?] = []
        var current = firstWeek.start

        while current < monthInterval.end || dates.count % 7 != 0 {
            if current >= monthInterval.start && current < monthInterval.end {
                dates.append(current)
            } else {
                dates.append(nil)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return dates
    }

    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            status: dayStatus(for: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                }
            }
        }
    }

    private func dayStatus(for date: Date) -> DayStatus {
        let dayStart = calendar.startOfDay(for: date)
        guard let entries = entriesByDay[dayStart], !entries.isEmpty else {
            return .none
        }

        let total = entries.reduce(0) { $0 + $1.calories }
        if total <= dailyGoal {
            return .perfect
        } else {
            return .warning
        }
    }
}

enum DayStatus {
    case none, perfect, warning
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let status: DayStatus

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.blue)
            } else if isToday {
                Circle()
                    .stroke(Color.blue, lineWidth: 1)
            }

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)

            // Status indicator
            if status != .none {
                Circle()
                    .fill(status == .perfect ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                    .offset(y: 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
    }
}

// MARK: - Day Review Card

struct DayReviewCard: View {
    let date: Date
    let entries: [FoodEntry]
    let dailyGoal: Double

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var isOnTrack: Bool {
        totalCalories <= dailyGoal
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(formatDate(date))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(isOnTrack ? "PERFECT" : "WARNING")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(isOnTrack ? Color.green : Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("摄入: \(Int(totalCalories)) / 目标: \(Int(dailyGoal))kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image("mascot_avatar")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundStyle(isOnTrack ? .green : .orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")

        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [FoodEntry.self, UserGoal.self, WeightEntry.self], inMemory: true)
}
