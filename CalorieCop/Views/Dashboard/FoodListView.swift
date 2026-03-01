import SwiftUI
import SwiftData

struct FoodListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.createdAt, order: .reverse)
    private var allEntries: [FoodEntry]

    private var todayEntries: [FoodEntry] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { $0.createdAt >= startOfDay }
    }

    var body: some View {
        Group {
            if todayEntries.isEmpty {
                emptyState
            } else {
                foodList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("今天还没有记录")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击下方按钮记录你的第一餐")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var foodList: some View {
        List {
            ForEach(todayEntries) { entry in
                FoodEntryRow(entry: entry)
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(.plain)
    }

    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { todayEntries[$0] }
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName)
                    .font(.headline)

                Text("\(entry.grams.formattedGrams)g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.calories.formattedCalories) kcal")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)

                Text(entry.createdAt.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FoodListView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
