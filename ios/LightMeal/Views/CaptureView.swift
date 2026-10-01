import SwiftUI
import PhotosUI
import AVFoundation

struct CaptureView: View {
    @EnvironmentObject private var store: MealStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var camera = false
    @State private var uploadConsent = false
    @State private var loading = false
    @State private var draft = Meal(kind: .suggested(), foods: [])
    @State private var error: String?
    @State private var editor: FoodItem?
    @State private var saved = false
    var body: some View {
        Page(title: draft.foods.isEmpty ? "拍照识别" : "识别结果") {
            if let photo { Image(uiImage: photo).resizable().scaledToFill().frame(height: 200).clipped().clipShape(RoundedRectangle(cornerRadius: 18)) }
            else { MealCard { VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder").font(.system(size: 64)).foregroundStyle(Color.mealOrange)
                Text("拍下餐食，记录这一餐").font(.headline)
                Text("拍全食物；共享餐请说明你吃的部分").font(.footnote).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 36) } }
            HStack {
                Button("打开相机", systemImage: "camera") { openCamera() }.buttonStyle(.bordered)
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("相册", systemImage: "photo") }.buttonStyle(.bordered)
            }.disabled(loading || saved)
            MealCard {
                Picker("餐次", selection: $draft.kind) { ForEach(MealKind.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                DatePicker("餐食时间", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                TextField("补充说明，如一人份、少油", text: $draft.note, axis: .vertical)
            }
            if draft.foods.isEmpty {
                Button { uploadConsent = true } label: {
                    HStack { if loading { ProgressView().tint(.white) }; Text(loading ? "正在分析…" : "开始 AI 分析") }.frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(photo == nil || loading)
                Button("手动记录（离线可用）") { editor = FoodItem(name: "", grams: 100, kcal: 0) }.disabled(loading)
                Notice(text: "使用你配置的视觉模型服务；照片会发送给该服务。端侧视觉尚未接入。")
            } else {
                MealCard {
                    HStack { Text("合计估算"); Spacer(); Text("约 \(Int(draft.totalKcal.rounded())) kcal").font(.title2.bold()).foregroundStyle(Color.mealOrange) }
                    ForEach(draft.foods) { food in
                        Divider()
                        Button { editor = food } label: { HStack {
                            VStack(alignment: .leading) { Text(food.name).foregroundStyle(.primary)
                                Text("约\(Int(food.effectiveGrams.rounded()))克 · 吃下\(Int(food.consumedFraction * 100))%")
                                    .font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text("\(Int(food.effectiveKcal.rounded())) kcal"); Image(systemName: "chevron.right")
                        }.padding(.vertical, 8) }.contextMenu { Button("移除", role: .destructive) { draft.foods.removeAll { $0.id == food.id } } }
                    }
                    Button("添加遗漏食物", systemImage: "plus") { editor = FoodItem(name: "", grams: 100, kcal: 0) }
                    HStack { nutrient("蛋白质", draft.nutrient(\.protein)); nutrient("脂肪", draft.nutrient(\.fat)); nutrient("碳水", draft.nutrient(\.carbs)) }.padding(.top, 12)
                }
                Notice(text: "照片不能测出精确重量与用油。点击食物修改份量；长按移除误识别项。")
                Button(store.settings.writeHealth ? "保存并写入 Apple 健康" : "确认并保存") { save() }
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity).disabled(loading || saved)
                Button("重新识别") { uploadConsent = true }.disabled(photo == nil || loading || saved)
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() }.disabled(loading) } }
        .sheet(isPresented: $camera) { CameraPicker { value in camera = false; if let value { photo = value; draft.foods = [] } }.ignoresSafeArea() }
        .sheet(item: $editor) { food in FoodEditor(food: food) { value in
            if let index = draft.foods.firstIndex(where: { $0.id == value.id }) { draft.foods[index] = value }
            else { draft.foods.append(value) }
        } }
        .onChange(of: selectedPhoto) { _, value in
            Task { do {
                guard let data = try await value?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                photo = image; draft.foods = []; error = nil
            } catch { self.error = error.localizedDescription } }
        }
        .confirmationDialog("发送照片到模型服务？", isPresented: $uploadConsent, titleVisibility: .visible) {
            Button("同意并分析") { analyze() }
        } message: { Text("照片和补充说明会发送至 \(URL(string: store.settings.modelEndpoint)?.host ?? "尚未配置的服务")。不会发送运动或体重数据。") }
        .alert("已保存本餐", isPresented: $saved) { Button("完成") { dismiss() } }
        message: { Text(store.meals.first(where: { $0.id == draft.id })?.healthStatus.title ?? "本机记录已保存") }
    }
    private func nutrient(_ name: String, _ value: Double?) -> some View {
        VStack { Text(value.map { "\(Int($0.rounded()))g" } ?? "—").font(.headline); Text(name).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "此设备没有可用相机，请从相册选择。"; return }
        Task {
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            if allowed { camera = true } else { error = "相机权限未开启，可使用相册或手动记录。" }
        }
    }
    private func analyze() {
        guard let data = photo?.mealJPEG() else { error = "无法读取照片"; return }
        loading = true; error = nil
        let settings = store.settings; let note = draft.note; let key = KeychainStore.read()
        Task {
            defer { loading = false }
            do { draft.foods = try await VisionRecognitionService().recognize(image: data, note: note, settings: settings, key: key) }
            catch { self.error = error.localizedDescription }
        }
    }
    private func save() {
        loading = true; error = nil
        Task {
            defer { loading = false }
            do {
                let value = try store.upsert(draft, photo: photo?.mealJPEG())
                if store.settings.writeHealth { await health.sync(value, store: store) }
                saved = true
            } catch { self.error = error.localizedDescription }
        }
    }
}
