import SwiftUI
import UIKit

struct AppSettings: Codable {
    var goal: Double = 1800
    var displayName = "我的记录"
    var modelEndpoint = ""
    var modelName = ""
    var writeHealth = false
}

@MainActor final class MealStore: ObservableObject {
    @Published private(set) var meals: [Meal] = []
    @Published var settings = AppSettings()
    @Published var storageError: String?
    private var storageLocked = false
    private let directory: URL
    private var file: URL { directory.appendingPathComponent("meals.json") }
    private struct Snapshot: Codable { var schemaVersion = 1; var meals: [Meal]; var settings: AppSettings }

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LightMeal", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var excluded = directory
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try excluded.setResourceValues(values)
            if FileManager.default.fileExists(atPath: file.path) {
                let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: file))
                guard snapshot.schemaVersion == 1 else { throw MealError.invalidResponse }
                try snapshot.meals.forEach { try $0.validate() }
                guard Set(snapshot.meals.map(\.id)).count == snapshot.meals.count else { throw MealError.invalidResponse }
                meals = snapshot.meals; settings = snapshot.settings
            }
        } catch {
            storageLocked = true
            storageError = "无法读取本机历史，原文件已保留，暂时禁止覆盖。\(error.localizedDescription)"
        }
    }
    private func persist(_ proposed: [Meal], settings nextSettings: AppSettings? = nil) throws {
        guard !storageLocked else { throw NSError(domain: "Storage", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "历史文件需要恢复，未覆盖原文件。请先导出原始备份。"] ) }
        let data = try JSONEncoder().encode(Snapshot(meals: proposed, settings: nextSettings ?? settings))
        try data.write(to: file, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
    func saveSettings() throws {
        guard settings.goal.isFinite, (500...10000).contains(settings.goal) else { throw MealError.invalidFood }
        try persist(meals)
    }
    @discardableResult func upsert(_ value: Meal, photo: Data? = nil) throws -> Meal {
        var updated = value
        if let old = meals.first(where: { $0.id == value.id }) {
            updated.version = old.version + 1
            if old.healthStatus != .notRequested || settings.writeHealth { updated.healthStatus = .pending }
        } else if settings.writeHealth { updated.healthStatus = .pending }
        try updated.validate()
        var createdPhoto: URL?
        if let photo {
            let name = "\(updated.id.uuidString)-\(UUID().uuidString).jpg"
            let url = directory.appendingPathComponent(name)
            try photo.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            updated.photoFileName = name; createdPhoto = url
        }
        var next = meals.filter { $0.id != updated.id }; next.append(updated)
        do { try persist(next) } catch {
            if let createdPhoto { try? FileManager.default.removeItem(at: createdPhoto) }
            throw error
        }
        meals = next.sorted { $0.date > $1.date }
        return updated
    }
    func markHealth(_ id: UUID, version: Int, status: HealthWriteStatus, error: String? = nil) throws {
        var next = meals
        guard let index = next.firstIndex(where: { $0.id == id }), next[index].version == version else { return }
        next[index].healthStatus = status; next[index].healthError = error
        try persist(next); meals = next
    }
    func delete(_ meal: Meal) throws {
        let next = meals.filter { $0.id != meal.id }; try persist(next); meals = next
        if let path = photoURL(meal) { try? FileManager.default.removeItem(at: path) }
    }
    func on(_ date: Date) -> [Meal] {
        meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.date < $1.date }
    }
    func photoURL(_ meal: Meal) -> URL? {
        guard let name = meal.photoFileName, name.hasSuffix(".jpg"),
              !name.contains("/"), !name.contains("\\"), !name.contains("..") else { return nil }
        return directory.appendingPathComponent(name)
    }
    func image(_ meal: Meal) -> UIImage? { photoURL(meal).flatMap { UIImage(contentsOfFile: $0.path) } }
    func export() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("轻食记-\(UUID().uuidString).json")
        let data: Data
        if storageLocked { data = try Data(contentsOf: file) }
        else { data = try JSONEncoder().encode(Snapshot(meals: meals, settings: settings)) }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        return url
    }
    func importBackup(_ data: Data) throws {
        guard data.count <= 5 * 1024 * 1024 else { throw MealError.invalidResponse }
        let backup = try JSONDecoder().decode(Snapshot.self, from: data)
        guard backup.schemaVersion == 1, Set(backup.meals.map(\.id)).count == backup.meals.count else { throw MealError.invalidResponse }
        try backup.meals.forEach { try $0.validate() }
        var next = meals
        for var meal in backup.meals {
            let old = next.first { $0.id == meal.id }
            meal.photoFileName = old?.photoFileName
            meal.version = (old?.version ?? 0) + 1
            meal.healthStatus = old?.healthStatus == .synced || old?.healthStatus == .pending || old?.healthStatus == .failed ? .pending : .notRequested
            meal.healthError = nil
            next.removeAll { $0.id == meal.id }; next.append(meal)
        }
        try persist(next); meals = next.sorted { $0.date > $1.date }
    }
}
