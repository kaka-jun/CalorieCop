import SwiftUI

struct CalorieBalanceView: View {
    let consumed: Double
    let burned: Double
    var recommended: Double? = nil  // Optional: for showing remaining calories

    var balance: Double {
        burned - consumed
    }

    var isDeficit: Bool {
        balance > 0
    }

    var remaining: Double? {
        guard let rec = recommended else { return nil }
        return rec - consumed
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(consumed.formattedCalories)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("摄入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "minus")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text(burned.formattedCalories)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("消耗")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "equal")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Image(systemName: isDeficit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isDeficit ? .green : .red)
                    Text(abs(balance).formattedCalories)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(isDeficit ? .green : .red)
                    Text(isDeficit ? "缺口" : "盈余")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Show remaining calories if recommended is provided
            if let remaining = remaining, let rec = recommended {
                Divider()

                HStack {
                    if remaining > 0 {
                        Label("还可吃 \(Int(remaining)) kcal", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    } else {
                        Label("已超出 \(Int(-remaining)) kcal", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    Text("目标 \(Int(rec)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        CalorieBalanceView(consumed: 1200, burned: 2000)
        CalorieBalanceView(consumed: 2500, burned: 2000)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
