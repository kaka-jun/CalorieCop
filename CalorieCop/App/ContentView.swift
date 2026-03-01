import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("概览", systemImage: "chart.pie.fill")
                }

            FoodInputView()
                .tabItem {
                    Label("记录", systemImage: "plus.circle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
}
