import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var activeCaloriesBurned: Double = 0
    @Published var basalCaloriesBurned: Double = 0
    @Published var authorizationError: String?

    var totalCaloriesBurned: Double {
        activeCaloriesBurned + basalCaloriesBurned
    }

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            await fetchTodayCaloriesBurned()
        } catch {
            authorizationError = "Failed to authorize HealthKit: \(error.localizedDescription)"
        }
    }

    func fetchTodayCaloriesBurned() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.fetchActiveCalories()
            }
            group.addTask {
                await self.fetchBasalCalories()
            }
        }
    }

    private func fetchActiveCalories() async {
        let calories = await fetchCalories(for: .activeEnergyBurned)
        activeCaloriesBurned = calories
    }

    private func fetchBasalCalories() async {
        let calories = await fetchCalories(for: .basalEnergyBurned)
        basalCaloriesBurned = calories
    }

    private func fetchCalories(for identifier: HKQuantityTypeIdentifier) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let sum = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: sum)
            }
            healthStore.execute(query)
        }
    }
}
