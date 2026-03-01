import SwiftUI
import SwiftData

struct GoalSettingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [UserGoal]
    @Query private var settings: [UserSettings]

    @State private var targetWeight: Double = 65  // Input value in user's preferred unit
    @State private var height: Double = 170
    @State private var age: Int = 30
    @State private var gender: String = "male"
    @State private var activityLevel: String = "moderate"
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Date().addingTimeInterval(86400 * 90)
    @State private var initialized = false

    var currentGoal: UserGoal? { goals.first }

    private var weightUnit: WeightUnit {
        settings.first?.preferredWeightUnit ?? .kg
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("身体信息") {
                    HStack {
                        Text("身高")
                        Spacer()
                        TextField("cm", value: $height, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("年龄")
                        Spacer()
                        TextField("岁", value: $age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("岁")
                            .foregroundStyle(.secondary)
                    }

                    Picker("性别", selection: $gender) {
                        Text("男").tag("male")
                        Text("女").tag("female")
                    }
                }

                Section("目标设置") {
                    HStack {
                        Text("目标体重")
                        Spacer()
                        TextField(weightUnit.shortName, value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(weightUnit.shortName)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("设置目标日期", isOn: $hasTargetDate)

                    if hasTargetDate {
                        DatePicker("目标日期", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    }
                }

                Section("活动水平") {
                    Picker("日常活动量", selection: $activityLevel) {
                        Text("久坐（很少运动）").tag("sedentary")
                        Text("轻度（每周1-3次运动）").tag("light")
                        Text("中度（每周3-5次运动）").tag("moderate")
                        Text("活跃（每周6-7次运动）").tag("active")
                        Text("非常活跃（运动员/体力劳动）").tag("very_active")
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    calorieRecommendation
                }

                Section {
                    Button("保存目标") {
                        saveGoal()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("设置目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingGoal()
            }
        }
    }

    private var calorieRecommendation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("建议每日摄入")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Convert to kg for calculations
            let targetWeightInKg = weightUnit.toKg(targetWeight)

            let goal = UserGoal(
                targetWeight: targetWeightInKg,
                height: height,
                age: age,
                gender: gender,
                activityLevel: activityLevel,
                targetDate: hasTargetDate ? targetDate : nil
            )

            // Assume current weight is target + 5kg for preview
            let estimatedCurrentWeightKg = targetWeightInKg + 5
            let recommended = goal.recommendedDailyCalories(currentWeight: estimatedCurrentWeightKg)
            let tdee = goal.calculateTDEE(currentWeight: estimatedCurrentWeightKg)

            HStack {
                VStack {
                    Text("\(Int(recommended))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("推荐摄入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(Int(tdee))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("每日消耗")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(Int(tdee - recommended))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("热量缺口")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("* 基于预估当前体重 \(weightUnit.format(estimatedCurrentWeightKg)) 计算")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func loadExistingGoal() {
        guard !initialized else { return }
        initialized = true

        if let goal = currentGoal {
            // Convert stored kg value to user's preferred unit
            targetWeight = weightUnit.fromKg(goal.targetWeight)
            height = goal.height
            age = goal.age
            gender = goal.gender
            activityLevel = goal.activityLevel
            if let date = goal.targetDate {
                hasTargetDate = true
                targetDate = date
            }
        } else {
            // Set default based on unit
            targetWeight = weightUnit == .lb ? 143.0 : 65.0
        }
    }

    private func saveGoal() {
        // Remove existing goal
        if let existing = currentGoal {
            modelContext.delete(existing)
        }

        // Convert from user's unit to kg for storage
        let targetWeightInKg = weightUnit.toKg(targetWeight)

        // Create new goal
        let goal = UserGoal(
            targetWeight: targetWeightInKg,
            height: height,
            age: age,
            gender: gender,
            activityLevel: activityLevel,
            targetDate: hasTargetDate ? targetDate : nil
        )

        modelContext.insert(goal)
        dismiss()
    }
}

#Preview {
    GoalSettingView()
        .modelContainer(for: [UserGoal.self, FoodEntry.self, UserSettings.self], inMemory: true)
}
