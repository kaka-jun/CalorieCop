import SwiftUI

struct CalorieBalanceView: View {
    let consumed: Double
    let burned: Double

    var balance: Double {
        burned - consumed
    }

    var isDeficit: Bool {
        balance > 0
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
