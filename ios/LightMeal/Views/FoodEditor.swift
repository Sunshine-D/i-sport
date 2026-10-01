import SwiftUI

struct FoodEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var food: FoodItem
    var onSave: (FoodItem) -> Void
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("照片中的完整份量") {
                    TextField("食物名称", text: $food.name)
                    number("份量（克）", value: $food.grams)
                    number("完整份量热量（千卡）", value: $food.kcal)
                }
                Section("实际吃下") {
                    Slider(value: $food.consumedFraction, in: 0...1, step: 0.05)
                    Text("\(Int(food.consumedFraction * 100))% · 约 \(Int(food.effectiveKcal.rounded())) 千卡")
                    HStack { ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                        Button("\(Int(fraction * 100))%") { food.consumedFraction = fraction }.buttonStyle(.bordered)
                    } }
                }
                Section("营养素（未知可留空）") {
                    optionalNumber("蛋白质（克）", value: $food.protein)
                    optionalNumber("脂肪（克）", value: $food.fat)
                    optionalNumber("碳水（克）", value: $food.carbs)
                }
                Section("估算说明") { TextField("用油、烹饪方式等", text: $food.assumption, axis: .vertical) }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("编辑食物").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("完成") {
                        do { try food.validate(); onSave(food); dismiss() } catch { self.error = error.localizedDescription }
                    } }
                }
        }
    }
    private func number(_ label: String, value: Binding<Double>) -> some View {
        HStack { Text(label); Spacer(); TextField(label, value: value, format: .number)
            .keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }
    private func optionalNumber(_ label: String, value: Binding<Double?>) -> some View {
        HStack { Text(label); Spacer(); TextField("未知", text: Binding(get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { text in value.wrappedValue = text.isEmpty ? nil : Double(text) }))
            .keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
    }
}
