import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: MealStore
    @State private var key = ""
    @State private var feedback: String?
    @State private var exportURL: URL?
    @State private var importing = false
    var body: some View {
        Page(title: "我的") {
            MealCard {
                HStack { Image(systemName: "person.crop.circle.fill").font(.system(size: 46)).foregroundStyle(Color.mealOrange)
                    TextField("记录名称", text: $store.settings.displayName).font(.title3.bold()) }
            }
            MealCard {
                HStack { Text("每日热量目标"); Spacer(); TextField("kcal", value: $store.settings.goal, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                Text("手动设置，仅用于记录进度，不是推荐摄入量。").font(.caption).foregroundStyle(.secondary)
                Divider().padding(.vertical, 10)
                NavigationLink("数据同步与健康授权") { SyncSettingsView() }
            }
            MealCard {
                Text("AI 识别引擎").font(.headline)
                Text("在线视觉模型 · 需自行配置").font(.caption).foregroundStyle(.secondary)
                TextField("完整 HTTPS Chat Completions 地址", text: $store.settings.modelEndpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                TextField("支持视觉消息的模型名称", text: $store.settings.modelName).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("个人 API 密钥（钥匙串）", text: $key)
                Button("保存设置") {
                    do { try KeychainStore.save(key); try store.saveSettings(); feedback = "设置已保存，尚未进行真实识别验证。" }
                    catch { feedback = error.localizedDescription }
                }.buttonStyle(.borderedProminent).padding(.top, 8)
            }
            MealCard {
                Label("iCloud 历史同步：尚未开启", systemImage: "icloud.slash")
                Text("个人饮食历史的 CloudKit 存储须核实审核要求；照片与记录目前只在本机。").font(.caption).foregroundStyle(.secondary)
                Divider().padding(.vertical, 10)
                Label("端侧视觉：尚未接入", systemImage: "iphone")
                Text("离线时可手动记录，不模拟 AI 识别成功。").font(.caption).foregroundStyle(.secondary)
            }
            MealCard {
                Button("导出记录 / 原始备份", systemImage: "square.and.arrow.up") {
                    do { exportURL = try store.export() } catch { feedback = error.localizedDescription }
                }
                if let exportURL { ShareLink(item: exportURL) { Text("分享导出文件（含个人饮食记录）") }.padding(.top, 8) }
                Button("导入 JSON 记录", systemImage: "square.and.arrow.down") { importing = true }.padding(.top, 10)
                Text("导出不含密钥和照片，仅支持恢复餐食文本；同一餐按 ID 合并。照片与历史文件被排除在 iCloud 备份之外。").font(.caption).foregroundStyle(.secondary)
            }
            if let feedback { Notice(text: feedback) }
            Notice(text: "轻食记 V2 · 照片识别仅为估算。图片发送前单独征求同意；不上传运动、体重和姓名到模型服务。")
        }.onAppear { key = KeychainStore.read() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try store.importBackup(Data(contentsOf: url))
                feedback = "已合并导入餐食文本，未自动写入健康应用。"
            } catch { feedback = "导入失败，原记录未更改：\(error.localizedDescription)" }
        }
    }
}
struct SyncSettingsView: View {
    @EnvironmentObject private var store: MealStore
    @EnvironmentObject private var health: HealthService
    @State private var feedback: String?
    var body: some View {
        Page(title: "数据同步") {
            #if SELF_USE_BASIC
            Notice(text: "基础自用构建：Apple 健康已关闭。此构建用于免费签名安装测试，完整健康版仍单独保留。")
            #endif
            MealCard {
                Label("Apple 健康", systemImage: "heart.fill").foregroundStyle(.pink).font(.headline)
                Text("读取能量、步数、最近体重、心率和训练；来源以系统记录为准，不假定全部来自小米。").font(.caption).foregroundStyle(.secondary)
                Button("请求健康权限") { Task { await health.authorize() } }.buttonStyle(.borderedProminent).padding(.top, 10)
                Button("刷新已授权的数据") { Task { await health.refresh() } }.buttonStyle(.bordered).disabled(health.busy)
                if let date = health.refreshedAt { Text("最近读取：\(date.formatted())").font(.caption2).foregroundStyle(.secondary) }
                Text("读取授权不向应用暴露是否拒绝；没有样本时显示未读到数据。").font(.caption2).foregroundStyle(.secondary)
            }
            MealCard {
                Text("已读取的数据").font(.headline)
                dataRow("活动能量 kcal", health.active)
                dataRow("基础能量 kcal", health.basal)
                dataRow("步数", health.steps)
                dataRow("最近体重 kg", health.weight)
                dataRow("最近心率 bpm", health.heartRate)
                dataRow("今日训练 min", health.minutes)
                Text("体重与心率为最近可读取样本，可能不是今天。— 表示未读到数据。").font(.caption).foregroundStyle(.secondary)
            }
            MealCard {
                Toggle("保存后写入膳食能量", isOn: $store.settings.writeHealth)
                    .disabled(!health.available)
                    .onChange(of: store.settings.writeHealth) { _, _ in do { try store.saveSettings() } catch { feedback = error.localizedDescription } }
                Text("仅写入用户确认的本应用餐食。修改保持餐食 ID 与版本；失败可重试。").font(.caption).foregroundStyle(.secondary)
                Button("重试待写入餐食") { Task {
                    for meal in store.meals.filter({ $0.healthStatus == .pending || $0.healthStatus == .failed }) { await health.sync(meal, store: store) }
                } }.padding(.top, 10)
            }
            MealCard {
                Label("小米运动健康", systemImage: "link").font(.headline)
                Text("减重 · 每餐记录：自动写入未接通").foregroundStyle(Color.mealOrange).padding(.top, 6)
                Text("在餐食详情复制名称、份量和总热量后手动填写。若小米将运动数据写入 Apple 健康，本应用可在授权后读取对应数据。").font(.footnote).foregroundStyle(.secondary)
            }
            if let error = health.error ?? feedback { Notice(text: error) }
        }
    }
    private func dataRow(_ name: String, _ value: Double?) -> some View {
        HStack { Text(name); Spacer(); Text(value.map { String(format: "%.1f", $0) } ?? "—").foregroundStyle(.secondary) }.font(.subheadline).padding(.vertical, 6)
    }
}
