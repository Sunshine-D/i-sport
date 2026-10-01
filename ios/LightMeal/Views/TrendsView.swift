import SwiftUI
import Charts

struct TrendsView: View {
    @EnvironmentObject private var store: MealStore
    @EnvironmentObject private var health: HealthService
    @State private var range = 7
    struct Day: Identifiable { var date: Date; var kcal: Double; var id: Date { date } }
    private var days: [Day] {
        let start = Calendar.current.date(byAdding: .day, value: -(range - 1), to: Calendar.current.startOfDay(for: Date()))!
        let included = store.meals.filter { $0.date >= start && $0.date <= Date() }
        return Dictionary(grouping: included) { Calendar.current.startOfDay(for: $0.date) }
            .map { Day(date: $0.key, kcal: $0.value.reduce(0) { $0 + $1.totalKcal }) }.sorted { $0.date < $1.date }
    }
    var body: some View {
        Page(title: "趋势") {
            Picker("时间范围", selection: $range) { Text("近7天").tag(7); Text("近30天").tag(30); Text("近365天").tag(365) }.pickerStyle(.segmented)
            MealCard {
                HStack { Text("已记录摄入").font(.headline); Spacer(); Text("\(Int(days.reduce(0) { $0 + $1.kcal }.rounded())) kcal").foregroundStyle(Color.mealOrange) }
                if days.isEmpty { ContentUnavailableView("尚无记录", systemImage: "chart.bar") }
                else { Chart(days) { day in BarMark(x: .value("日期", day.date, unit: .day), y: .value("摄入", day.kcal)).foregroundStyle(Color.mealOrange) }.frame(height: 220)
                    ForEach(days) { day in HStack { Text(day.date, format: .dateTime.month().day()); Spacer(); Text("约 \(Int(day.kcal.rounded())) kcal") }.font(.caption) }
                }
            }
            MealCard {
                Text("最近体重").font(.headline)
                Text(health.weight.map { String(format: "%.1f kg", $0) } ?? "尚未读到体重")
                    .font(.title2.bold()).padding(.top, 10)
                Text("最近可读取样本，不代表今天测量；历史体重曲线尚未接入。").font(.caption).foregroundStyle(.secondary)
            }
            MealCard {
                Text("今日运动记录").font(.headline)
                if health.workouts.isEmpty { Text("未读到今日训练").foregroundStyle(.secondary).padding(.top, 12) }
                ForEach(health.workouts, id: \.uuid) { workout in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("训练").font(.headline)
                            Text(workout.startDate, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Text("\(Int((workout.duration / 60).rounded())) 分钟")
                    }.padding(.vertical, 10)
                }
            }
            Notice(text: "只显示实际记录日期，未记录的日期不是零摄入。历史消耗与体重曲线尚未接入，不使用示例冒充真实数据。")
        }
    }
}
