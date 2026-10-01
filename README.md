# 轻食记 · AI 卡路里

原生 iOS 工程，以用户提供的 Ardot V2 七页面设计为基准。目标使用系统 iOS 27，使用稳定 SwiftUI / HealthKit API；最低部署 iOS 17。

文档顺序：[`docs/PRD.md`](docs/PRD.md) → [`docs/API.md`](docs/API.md) → [`docs/SPEC.md`](docs/SPEC.md) → [`docs/VERIFICATION.md`](docs/VERIFICATION.md)。

状态：首版源码与可运行交互预览已提供，完整产品验收仍为 PARTIAL。云端 Xcode 26.6 / iOS SDK 26.5 已通过模拟器与未签名设备编译、7 项 Swift 测试。签名、iOS 27 SDK 和相机/HealthKit 真机验证尚未完成。浏览器预览不是 iOS 安装包。预览领域24项测试通过，工程配置检查通过；具体证据见验证记录。

## 本机预览

执行 `node scripts/preview-server.mjs`，访问 `http://127.0.0.1:4173`。只绑定本机，不提供业务服务器；预览使用明确标识的示例识别，不调用真实模型或健康接口。

## 没有 Mac：iPhone / iPad 交付

最新使用偏好：仅个人使用，以 iPhone 为主，暂不购买苹果会员或走 App Store / TestFlight。构建会提供未签名基础自用版与完整健康版，须在 Windows 本地签名后尝试安装；具体步骤与限制见 [`docs/SELF-USE.md`](docs/SELF-USE.md)。基础版关闭 HealthKit，但保留原需求供后续验证，不承诺已完成免费账号签名或 iOS 27 真机安装。

不需要购买 Mac。先执行 `node scripts/preview-server.mjs --lan --port=4174`，用同一 Wi-Fi 下的 iPhone / iPad Safari 打开终端列出的局域网地址，查看交互预览。

原生交付采用云端 macOS 编译与 TestFlight 安装。已连接公开仓库 https://github.com/Sunshine-D/i-sport 。`.github/workflows/ios-build.yml` 在 main 分支推送时自动执行，也可手动触发，进行未签名编译检查；签名与 TestFlight 上传尚未实现。详细条件与步骤见 [`docs/NO-MAC.md`](docs/NO-MAC.md)。预览与未签名编译产物都不是可安装的原生 App。

## Mac / 云端 macOS 上运行

1. 打开 `ios/LightMeal.xcodeproj`，使用支持 iOS 27 的 Xcode SDK。
2. 设置自己的 Development Team 和唯一 Bundle Identifier；开发者账号启用 HealthKit。
3. 选择 iPhone 模拟器或已授权真机，运行 LightMeal target。
4. 默认本机记录。设置里配置支持视觉消息的兼容模型服务、完整 HTTPS Chat Completions 地址和个人密钥；首次发送照片需显式确认。密钥保存在钥匙串。
5. 需要运动数据或膳食能量写入时再开启 Apple 健康授权。

`python scripts/generate-project.py` 可从源文件重新生成 Xcode 工程。纯领域测试：`cd ios && swift test`；在 Xcode 中运行原生工程是另一项独立验证。Mac 一键检查：`bash scripts/verify-mac.sh`（尚未在本环境运行）。

## 能力边界

- 小米减重餐食写入未找到经过验证的接口，目前提供复制本餐记录。
- iCloud 个人饮食历史同步涉及 Apple 审核规则，未开启；不自动上传健康历史或照片。
- 端侧视觉模型尚未接入，离线可手动记录。iOS 27 新视觉 API 的实际设备可用性与中文餐食效果需进一步验证。
- 估算不能当作精确测量。用户确认后才保存与向健康应用写入；数据只代表已记录的餐食。
- 完整目标包含上述未验证能力，不能把当前版本标记为全部完成。
