import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: MealStore
    @EnvironmentObject private var health: HealthService
    var capture: () -> Void
    private var today: [Meal] { store.on(Date()) }
    private var total: Double { today.reduce(0) { $0 + $1.totalKcal } }
    var body: some View {
        Page(title: "今日") {
            Text(Date(), format: .dateTime.month().day().weekday()).font(.footnote).foregroundStyle(.secondary)
            MealCard {
                HStack { Text("热量").font(.headline); Spacer(); NavigationLink { SyncSettingsView() } label: { Image(systemName: "arrow.triangle.2.circlepath") } }
                HStack(spacing: 24) {
                    ZStack {
                        Circle().stroke(Color.mealOrange.opacity(0.1), lineWidth: 11)
                        Circle().trim(from: 0, to: min(total / max(store.settings.goal, 1), 1))
                            .stroke(Color.mealOrange, style: StrokeStyle(lineWidth: 11, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack { Text("\(Int(total.rounded()))").font(.title.bold()); Text("已记录 kcal").font(.caption2).foregroundStyle(.secondary) }
                    }.frame(width: 122, height: 122).accessibilityLabel("今日已记录约 \(Int(total.rounded())) 千卡")
                    VStack(alignment: .leading, spacing: 14) {
                        row("已摄入", value: total, color: .mealOrange)
                        row("基础消耗", value: health.basal, color: .secondary)
                        row("活动消耗", value: health.active, color: .mealGreen)
                    }.font(.footnote)
                }.padding(.top, 14)
                Text(total > store.settings.goal ? "已超过手动目标 \(Int((total - store.settings.goal).rounded())) 千卡" : "距手动目标 \(Int((store.settings.goal - total).rounded())) 千卡")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 12)
            }
            MealCard {
                HStack { Text("今日消耗").font(.headline); Spacer(); Text("Apple 健康").font(.caption).foregroundStyle(.secondary) }
                HStack { metric("活动 kcal", health.active); metric("步数", health.steps); metric("最近体重 kg", health.weight, decimals: true); metric("训练 min", health.minutes) }.padding(.top, 10)
                Text(health.refreshedAt == nil ? "尚未读取，前往数据同步授权" : "缺失项表示未读到数据；最近体重不是今日测量声明")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 10)
            }
            MealCard {
                HStack { Text("今日餐食").font(.headline); Spacer(); Button("照片日记", action: capture).font(.footnote) }
                if today.isEmpty { Text("今天尚未记录，拍下第一餐吧。").foregroundStyle(.secondary).padding(.vertical) }
                ForEach(today) { meal in NavigationLink { MealDetailView(mealID: meal.id) } label: { MealRow(meal: meal) }; Divider() }
            }
            Notice(text: "热量为估算，仅统计已记录餐食。小米餐食自动写入尚未接通。")
        }
    }
    private func row(_ name: String, value: Double?, color: Color) -> some View {
        HStack { Circle().fill(color).frame(width: 7, height: 7); Text(name).foregroundStyle(.secondary); Spacer(); Text(value.map { "\(Int($0.rounded()))" } ?? "—").foregroundStyle(.primary) }
    }
    private func metric(_ name: String, _ value: Double?, decimals: Bool = false) -> some View {
        VStack(spacing: 5) { Text(value.map { decimals ? String(format: "%.1f", $0) : "\(Int($0.rounded()))" } ?? "—").font(.headline); Text(name).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.mealBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct MealRow: View {
    var meal: Meal
    var body: some View {
        HStack { Image(systemName: "fork.knife").foregroundStyle(Color.mealOrange)
            VStack(alignment: .leading, spacing: 4) { Text(meal.kind.rawValue).font(.headline)
                Text("\(meal.date.formatted(date: .omitted, time: .shortened)) · \(meal.foods.map(\.name).joined(separator: "、"))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            Spacer(); Text("约 \(Int(meal.totalKcal.rounded())) kcal").font(.subheadline.bold()).foregroundStyle(Color.mealOrange)
        }.foregroundStyle(.primary).padding(.vertical, 12)
    }
}
