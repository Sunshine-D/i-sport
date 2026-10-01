import SwiftUI

struct DiaryView: View {
    @EnvironmentObject private var store: MealStore
    @State private var date = Date()
    var body: some View {
        Page(title: "餐食日记") {
            DatePicker("选择日期", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            MealCard {
                Text("当日已记录摄入").font(.footnote).foregroundStyle(.secondary)
                Text("约 \(Int(store.on(date).reduce(0) { $0 + $1.totalKcal }.rounded())) kcal").font(.title.bold()).foregroundStyle(Color.mealOrange)
            }
            if store.on(date).isEmpty { ContentUnavailableView("这一天尚未记录", systemImage: "calendar", description: Text("未记录不代表没有摄入。可通过拍照或手动补记。")) }
            ForEach(store.on(date)) { meal in
                NavigationLink { MealDetailView(mealID: meal.id) } label: { MealCard {
                    if let image = store.image(meal) { Image(uiImage: image).resizable().scaledToFill().frame(height: 160).clipped().clipShape(RoundedRectangle(cornerRadius: 12)) }
                    MealRow(meal: meal)
                    Text(meal.foods.map { "\($0.name) \(Int($0.effectiveKcal.rounded())) kcal" }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                } }
            }
            Notice(text: "照片与记录保存在本机。完整历史 iCloud 同步尚未开启。")
        }
    }
}

struct MealDetailView: View {
    @EnvironmentObject private var store: MealStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    var mealID: UUID
    @State private var editor: FoodItem?
    @State private var deleteConfirmation = false
    @State private var error: String?
    @State private var copied = false
    @State private var busy = false
    private var meal: Meal? { store.meals.first { $0.id == mealID } }
    var body: some View {
        Page(title: "餐食详情") {
            if let meal {
                if let image = store.image(meal) { Image(uiImage: image).resizable().scaledToFill().frame(height: 200).clipped().clipShape(RoundedRectangle(cornerRadius: 18)) }
                Text("\(meal.kind.rawValue) · \(meal.date.formatted())").font(.footnote).foregroundStyle(.secondary)
                MealCard {
                    Text("约 \(Int(meal.totalKcal.rounded())) kcal").font(.largeTitle.bold()).foregroundStyle(Color.mealOrange)
                    ForEach(meal.foods) { food in
                        Divider()
                        Button { editor = food } label: { HStack {
                            VStack(alignment: .leading) { Text(food.name); Text("\(Int(food.effectiveGrams.rounded()))克 · \(Int(food.consumedFraction * 100))%").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text("\(Int(food.effectiveKcal.rounded())) kcal"); Image(systemName: "pencil")
                        }.padding(.vertical, 10) }.disabled(busy)
                    }
                }
                if !meal.note.isEmpty { Text(meal.note).foregroundStyle(.secondary) }
                Notice(text: meal.healthStatus.title + (meal.healthError.map { "：\($0)" } ?? ""))
                Button(copied ? "已复制本餐" : "复制记录，手动填入小米", systemImage: "doc.on.doc") { UIPasteboard.general.string = meal.copyText; copied = true }
                Button("写入 / 重试 Apple 健康") {
                    busy = true; Task { await health.sync(meal, store: store); busy = false }
                }.buttonStyle(.bordered).disabled(busy)
                Button("删除本餐", role: .destructive) { deleteConfirmation = true }.disabled(busy)
                if let error { Text(error).foregroundStyle(.red) }
            } else { ContentUnavailableView("餐食已删除", systemImage: "fork.knife") }
        }
        .sheet(item: $editor) { food in FoodEditor(food: food) { value in
            guard var next = meal, let index = next.foods.firstIndex(where: { $0.id == value.id }) else { return }
            next.foods[index] = value
            do {
                let updated = try store.upsert(next)
                if store.settings.writeHealth || next.healthStatus == .synced {
                    busy = true; Task { await health.sync(updated, store: store); busy = false }
                }
            } catch { self.error = error.localizedDescription }
        } }
        .confirmationDialog("删除本餐与本应用写入的健康样本？", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                guard let meal else { return }; busy = true
                Task {
                    defer { busy = false }
                    do {
                        if meal.healthStatus != .notRequested { try await health.remove(meal) }
                        try store.delete(meal); dismiss()
                    } catch { self.error = "删除未完成，餐食已保留以便重试：\(error.localizedDescription)" }
                }
            }
        }
    }
}
