import SwiftUI
import HealthKit

#if SELF_USE_BASIC
// A separate self-use build for testing signing without HealthKit entitlements.
@MainActor final class HealthService: ObservableObject {
    @Published var active: Double?
    @Published var basal: Double?
    @Published var steps: Double?
    @Published var weight: Double?
    @Published var heartRate: Double?
    @Published var workouts: [HKWorkout] = []
    @Published var error: String?
    @Published var refreshedAt: Date?
    @Published var busy = false
    var available: Bool { false }
    var minutes: Double? { nil }
    private var unavailable: NSError { NSError(domain: "SelfUse", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "基础自用版未启用 Apple 健康；照片识别与本机记录仍可使用。"])
    }
    func authorize() async { error = unavailable.localizedDescription }
    func refresh() async { }
    func sync(_ meal: Meal, store: MealStore) async {
        error = unavailable.localizedDescription
        do { try store.markHealth(meal.id, version: meal.version, status: .failed, error: error) }
        catch { self.error = error.localizedDescription }
    }
    func remove(_ meal: Meal) async throws { throw unavailable }
}
#else
@MainActor final class HealthService: ObservableObject {
    @Published var active: Double?
    @Published var basal: Double?
    @Published var steps: Double?
    @Published var weight: Double?
    @Published var heartRate: Double?
    @Published var workouts: [HKWorkout] = []
    @Published var error: String?
    @Published var refreshedAt: Date?
    @Published var busy = false
    private let health = HKHealthStore()
    private var inFlight: Set<UUID> = []
    private var dietary: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)! }
    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    var minutes: Double? { refreshedAt == nil ? nil : workouts.reduce(0) { $0 + $1.duration / 60 } }

    func authorize() async {
        guard available else { error = "此设备不支持 Apple 健康"; return }
        let ids: [HKQuantityTypeIdentifier] = [.activeEnergyBurned, .basalEnergyBurned, .stepCount, .bodyMass, .heartRate]
        let types = ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }
        var read = Set<HKObjectType>(types); read.insert(HKObjectType.workoutType())
        do {
            try await health.requestAuthorization(toShare: [dietary], read: read)
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        guard available, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        let start = Calendar.current.startOfDay(for: Date())
        do {
            let nextActive = try await sum(.activeEnergyBurned, unit: .kilocalorie(), start: start)
            let nextBasal = try await sum(.basalEnergyBurned, unit: .kilocalorie(), start: start)
            let nextSteps = try await sum(.stepCount, unit: .count(), start: start)
            let nextWeight = try await latest(.bodyMass, unit: .gramUnit(with: .kilo))
            let nextHeart = try await latest(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()))
            let nextWorkouts = try await readWorkouts(start: start)
            active = nextActive; basal = nextBasal; steps = nextSteps; weight = nextWeight; heartRate = nextHeart
            workouts = nextWorkouts; refreshedAt = Date()
        } catch { self.error = "读取失败：\(error.localizedDescription)" }
    }
    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, start: Date) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: id)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit)) }
            }; health.execute(query)
        }
    }
    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: id)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: (result?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)) }
            }; health.execute(query)
        }
    }
    private func readWorkouts(start: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result as? [HKWorkout] ?? []) }
            }; health.execute(query)
        }
    }
    func sync(_ meal: Meal, store: MealStore) async {
        guard !inFlight.contains(meal.id) else { return }
        inFlight.insert(meal.id); defer { inFlight.remove(meal.id) }
        do {
            try meal.validate()
            guard available, health.authorizationStatus(for: dietary) == .sharingAuthorized else {
                throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先在数据同步页授权膳食能量写入"])
            }
            try store.markHealth(meal.id, version: meal.version, status: .pending)
            let metadata: [String: Any] = [HKMetadataKeySyncIdentifier: meal.id.uuidString,
                HKMetadataKeySyncVersion: meal.version, HKMetadataKeyWasUserEntered: true]
            let sample = HKQuantitySample(type: dietary, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: meal.totalKcal),
                start: meal.date, end: meal.date, metadata: metadata)
            try await health.save(sample)
            try store.markHealth(meal.id, version: meal.version, status: .synced)
        } catch {
            self.error = error.localizedDescription
            do { try store.markHealth(meal.id, version: meal.version, status: .failed, error: error.localizedDescription) }
            catch { self.error = "健康状态无法保存：\(error.localizedDescription)" }
        }
    }
    func remove(_ meal: Meal) async throws {
        guard available else { throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "此设备无法清理健康样本，原餐食暂时保留。"]) }
        guard !inFlight.contains(meal.id) else { throw NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "这餐正在同步，请稍后删除。"]) }
        inFlight.insert(meal.id); defer { inFlight.remove(meal.id) }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [meal.id.uuidString])
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: dietary, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, result, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: result ?? []) }
            }; health.execute(query)
        }
        let own = samples.filter { $0.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier }
        if !own.isEmpty { try await health.delete(own) }
    }
}
#endif
