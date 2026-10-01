import Foundation

public enum MealError: LocalizedError {
    case invalidFood, invalidResponse, emptyMeal
    public var errorDescription: String? {
        switch self {
        case .invalidFood: return "食物数据不合法，请检查名称、份量与热量。"
        case .invalidResponse: return "模型没有返回规定的食物数据，请重试。"
        case .emptyMeal: return "请至少添加一种食物。"
        }
    }
}

public struct FoodItem: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var grams: Double
    public var kcal: Double
    public var consumedFraction: Double = 1
    public var protein: Double?
    public var fat: Double?
    public var carbs: Double?
    public var assumption: String = ""
    public var effectiveKcal: Double { kcal * consumedFraction }
    public var effectiveGrams: Double { grams * consumedFraction }
    public init(name: String, grams: Double, kcal: Double, consumedFraction: Double = 1,
                protein: Double? = nil, fat: Double? = nil, carbs: Double? = nil, assumption: String = "") {
        self.name = name; self.grams = grams; self.kcal = kcal
        self.consumedFraction = consumedFraction; self.protein = protein
        self.fat = fat; self.carbs = carbs; self.assumption = assumption
    }
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 80,
              grams.isFinite, grams > 0, grams <= 10000,
              kcal.isFinite, kcal >= 0, kcal <= 20000,
              consumedFraction.isFinite, (0...1).contains(consumedFraction),
              [protein, fat, carbs].allSatisfy({ $0 == nil || ($0!.isFinite && $0! >= 0 && $0! <= 10000) })
        else { throw MealError.invalidFood }
    }
}

public enum MealKind: String, Codable, CaseIterable, Identifiable {
    case breakfast = "早餐", lunch = "午餐", dinner = "晚餐", snack = "加餐"
    public var id: String { rawValue }
    public static func suggested(at date: Date = Date()) -> Self {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

public enum HealthWriteStatus: String, Codable {
    case notRequested, pending, synced, failed
    public var title: String {
        switch self {
        case .notRequested: return "未写入 Apple 健康"
        case .pending: return "Apple 健康待写入"
        case .synced: return "已写入 Apple 健康"
        case .failed: return "Apple 健康写入失败"
        }
    }
}

public struct Meal: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var date: Date
    public var kind: MealKind
    public var foods: [FoodItem]
    public var photoFileName: String?
    public var note = ""
    public var version = 1
    public var healthStatus: HealthWriteStatus = .notRequested
    public var healthError: String?
    public var totalKcal: Double { foods.reduce(0) { $0 + $1.effectiveKcal } }
    public init(date: Date = Date(), kind: MealKind = .lunch, foods: [FoodItem]) {
        self.date = date; self.kind = kind; self.foods = foods
    }
    public func nutrient(_ key: KeyPath<FoodItem, Double?>) -> Double? {
        guard !foods.isEmpty, foods.allSatisfy({ $0[keyPath: key] != nil }) else { return nil }
        return foods.reduce(0) { $0 + $1[keyPath: key]! * $1.consumedFraction }
    }
    public func validate() throws {
        guard !foods.isEmpty, foods.count <= 30 else { throw MealError.emptyMeal }
        guard date.timeIntervalSince1970.isFinite, version > 0,
              Set(foods.map(\.id)).count == foods.count else { throw MealError.invalidFood }
        try foods.forEach { try $0.validate() }
    }
    public var copyText: String {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let rows = foods.map { "\($0.name)：约\(Int($0.effectiveGrams.rounded()))克，\(Int($0.effectiveKcal.rounded()))千卡" }
        return (["\(formatter.string(from: date)) · \(kind.rawValue)"] + rows + ["本餐合计约 \(Int(totalKcal.rounded())) 千卡（估算）"]).joined(separator: "\n")
    }
}

public enum RecognitionParser {
    private struct Payload: Decodable { var foods: [Item] }
    private struct Item: Decodable {
        var name: String; var grams: Double; var kcal: Double
        var protein: Double?; var fat: Double?; var carbs: Double?; var assumption: String?
    }
    public static func parse(_ text: String) throws -> [FoodItem] {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```") {
            let lines = clean.components(separatedBy: "\n")
            guard lines.count >= 3, lines.last == "```" else { throw MealError.invalidResponse }
            clean = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = clean.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              !payload.foods.isEmpty, payload.foods.count <= 30 else { throw MealError.invalidResponse }
        let foods = payload.foods.map { FoodItem(name: $0.name, grams: $0.grams, kcal: $0.kcal,
            protein: $0.protein, fat: $0.fat, carbs: $0.carbs, assumption: $0.assumption ?? "照片估算") }
        try foods.forEach { try $0.validate() }
        return foods
    }
}
