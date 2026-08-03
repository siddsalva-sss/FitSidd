import Foundation
import HealthKit
import Observation

@Observable
class HealthKitManager {
    private let store = HKHealthStore()

    var steps: Int = 0
    var distanceMiles: Double = 0
    var activeCalories: Int = 0
    var workouts: [WorkoutRecord] = []
    var isAuthorized = false

    struct WorkoutRecord: Identifiable {
        let id = UUID()
        let name: String
        let date: Date
        let minutes: Int
        let calories: Int
        let source: String
    }

    func requestAuth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let s = HKQuantityType.quantityType(forIdentifier: .stepCount) { readTypes.insert(s) }
        if let d = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { readTypes.insert(d) }
        if let c = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { readTypes.insert(c) }

        store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success { self.refreshAll() }
            }
        }
    }

    func refreshAll() {
        fetchSteps()
        fetchDistance()
        fetchCalories()
        fetchWorkouts()
    }

    private func todayPredicate() -> NSPredicate {
        let start = Calendar.current.startOfDay(for: Date())
        return HKQuery.predicateForSamples(withStart: start, end: Date())
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier,
                             unit: HKUnit,
                             completion: @escaping (Double) -> Void) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
        let query = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: todayPredicate(),
                                      options: .cumulativeSum) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            DispatchQueue.main.async { completion(value) }
        }
        store.execute(query)
    }

    func fetchSteps() {
        sumQuantity(.stepCount, unit: .count()) { self.steps = Int($0) }
    }

    func fetchDistance() {
        sumQuantity(.distanceWalkingRunning, unit: .mile()) { self.distanceMiles = $0 }
    }

    func fetchCalories() {
        sumQuantity(.activeEnergyBurned, unit: .kilocalorie()) { self.activeCalories = Int($0) }
    }

    func fetchWorkouts() {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                  predicate: predicate,
                                  limit: 30,
                                  sortDescriptors: [sort]) { _, samples, _ in
            let list = (samples as? [HKWorkout] ?? []).map { w -> WorkoutRecord in
                let cals = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                return WorkoutRecord(
                    name: Self.label(for: w.workoutActivityType),
                    date: w.startDate,
                    minutes: Int(w.duration / 60),
                    calories: Int(cals),
                    source: w.sourceRevision.source.name
                )
            }
            DispatchQueue.main.async { self.workouts = list }
        }
        store.execute(query)
    }

    static func label(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running 🏃"
        case .walking: return "Walking 🚶"
        case .traditionalStrengthTraining: return "Strength 🏋️"
        case .functionalStrengthTraining: return "Functional 💪"
        case .highIntensityIntervalTraining: return "HIIT 🔥"
        case .cycling: return "Cycling 🚴"
        case .elliptical: return "Elliptical"
        case .stairClimbing, .stairs: return "Stairs"
        case .yoga: return "Yoga 🧘"
        case .coreTraining: return "Core"
        case .swimming: return "Swimming 🏊"
        default: return "Workout"
        }
    }
}
