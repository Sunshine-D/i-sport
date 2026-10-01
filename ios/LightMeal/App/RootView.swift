import SwiftUI

extension Color {
    static let mealOrange = Color(red: 1, green: 0.40, blue: 0)
    static let mealGreen = Color(red: 0.13, green: 0.76, blue: 0.35)
    static let mealBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.95, green: 0.95, blue: 0.975, alpha: 1)
    })
}

struct MealCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22)) }
}
struct Page<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 16) {
        Text(title).font(.largeTitle.bold()); content
    }.padding(20) }.background(Color.mealBackground).navigationBarTitleDisplayMode(.inline) }
}
struct Notice: View {
    var text: String
    var body: some View { Label(text, systemImage: "info.circle").font(.footnote)
        .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14)) }
}
struct RootView: View {
    @EnvironmentObject var store: MealStore
    @EnvironmentObject var health: HealthService
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = 0
    @State private var capturing = false
    var body: some View {
        NavigationStack {
            Group {
                switch selected {
                case 1: DiaryView()
                case 3: TrendsView()
                case 4: SettingsView()
                default: TodayView(capture: { capturing = true })
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    tab("今日", icon: "house.fill", index: 0)
                    tab("日记", icon: "photo.on.rectangle", index: 1)
                    Button { capturing = true } label: {
                        Image(systemName: "camera.fill").font(.title2).foregroundStyle(.white)
                            .frame(width: 58, height: 52).background(Color.mealOrange, in: Capsule())
                    }.accessibilityLabel("拍照记录")
                    tab("趋势", icon: "chart.bar.fill", index: 3)
                    tab("我的", icon: "person.fill", index: 4)
                }.padding(10).background(.regularMaterial, in: Capsule()).padding(.horizontal, 20).padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $capturing) { NavigationStack { CaptureView() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, health.refreshedAt != nil { Task { await health.refresh() } }
        }
        .alert("本机历史读取失败", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("知道了", role: .cancel) { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
    }
    private func tab(_ title: String, icon: String, index: Int) -> some View {
        Button { selected = index } label: {
            VStack(spacing: 4) { Image(systemName: icon); Text(title).font(.caption2) }
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected == index ? Color.mealOrange : .secondary)
        }
    }
}
