# 没有 Mac：iPhone / iPad 使用与交付路径

用户设备约束：Windows 开发环境，有 iPhone 和 iPad，没有自有 Mac。后续交付不要求用户购买 Mac。当前状态仍为 PARTIAL：没有已签名的安装包，也没有已运行的云端构建。

## 先在手机和平板看效果

在 Windows 项目目录打开终端，运行：

```powershell
node scripts/preview-server.mjs --lan --port=4174
```

终端会列出本机的局域网地址，例如 `http://192.168.1.20:4174`。Windows 与 iPhone / iPad 连到同一 Wi-Fi，在设备 Safari 打开终端实际列出的地址。不要在手机上打开 `127.0.0.1`：它代表手机自身。多个网卡可能列出多个地址，选择连接同一 Wi-Fi 的网卡地址。

若访问不到，检查两端网络、路由器访客隔离、Windows 防火墙是否允许 Node 在私人网络上被访问。此脚本不自动更改防火墙或路由器设置。预览完成按 Ctrl+C 停止，电脑关机后链接不可访问。

这是临时静态页面服务，不是正式应用的业务后台。页面可查看七个入口、示例识别、编辑和保存；照片不会发送给模型。数据只在该设备浏览器保存，iPhone 和 iPad 不自动同步，清除网站数据会删除记录。HTTP 预览中的相机入口取决于 Safari 的文件选择能力，不承诺浏览器实时相机。预览不能读写 Apple 健康，也不能写入小米餐食模块。

## 正式原生版：云端 Mac 编译 → 签名 → TestFlight

选择这条路径以保留原生相机、模型调用、钥匙串和 HealthKit。云端 Mac 只负责编译；正式 App 的本地数据与模型调用不经过这个构建环境。

已准备 `.github/workflows/ios-build.yml`，只有手动触发，不在每次提交时自动消耗构建额度。需要代码进入自己的 GitHub 仓库后，在 Actions 选择 “Native iOS compilation (no signing)” 并 Run workflow：

- 默认 `macos-26`：用 runner 的默认稳定 SDK 编译现有稳定 API。
- 可选 `xcode-27`：官方公开预览 runner，用于 iOS 27 SDK 编译；实际可用性以 GitHub 为准。
- 执行工程生成、静态检查、24 项浏览器领域测试、Swift 领域测试、模拟器与未签名设备编译；工具版本写入日志。
- 它只验证源码能否编译，不产生可以安装的 IPA。执行成功也不等于相机、真实识别、HealthKit 或 iOS 27 真机验收通过。

当前没有关联 GitHub 仓库或远程构建权限，故未上传源码、未触发构建。私有仓库的 macOS 构建使用账号额度，超额可能计费；查看账号配额和预算后再运行，不承诺免费。

### 从编译到可安装版本还需要什么

1. Apple Developer Program 成员资格，以及该账号的 App Store Connect 权限；普通 Apple ID 不等于可用的 TestFlight 分发资格。
2. 唯一 Bundle ID 与 Team ID，账号中启用 HealthKit，并与工程 entitlements 对齐。
3. Apple Distribution 签名证书（含私钥）、密码及对应分发 provisioning profile。可以通过云端 macOS 创建签名请求并在 Apple 开发者网站配置，不要求自有 Mac；具体配置需账号持有人操作。
4. 自定义 App 图标、App Store Connect 的应用条目、隐私声明和必要元数据；目前工程尚未具备完整上架素材。
5. 将签名材料放在构建服务的加密 Secrets，后续配置 archive / export / upload。不要提交到代码库或把私钥发到聊天。
6. 构建上传后完成 Apple 处理，在 TestFlight 添加测试用户；外部测试可能需要 Beta App Review。iPhone 和 iPad 安装 TestFlight 后接受邀请即可，不需要连接 Mac。

签名和上传流水线尚未实现，不能把未签名 `.app` 打包改名成 IPA 来宣称已经能安装。实际账号和签名材料到位后才可验证此交付阶段。

## iPad Swift Playgrounds 的位置

Apple 官方支持在 iPad 用 Swift Playgrounds 创建 SwiftUI 应用，并向 App Store Connect 提交。它适合无 Mac 的界面和简单原生逻辑实验，但本仓库的 `.xcodeproj` 不能直接当作 App Playground 打开，需要转换为 `.swiftpm` 应用包。Apple 的 Playgrounds 能力列表没有给本项目的 HealthKit 配置提供足够保证，因此目前未提供或宣称已验证的 Playgrounds 运行包。不能用这一方案替代正式健康同步验证。

## 不因设备限制更改的产品要求

小米餐食自动导入、iCloud 餐食同步、端侧视觉识别仍是独立待解决项；换用云端构建并不会接通这些能力。iPhone 与 iPad 的双端记录同步仍待实现，当前只能显式导出与导入。

## 官方依据（2026-10-01 核查）

- [GitHub 托管 runner 与额度说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub 的 Apple 证书与 provisioning profile 配置](https://docs.github.com/en/enterprise-cloud%40latest/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple TestFlight](https://developer.apple.com/testflight/)
- [Apple 开发者账号与成员资格](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Swift Playgrounds 的能力说明](https://developer.apple.com/documentation/swift-playgrounds/project-capabilities)
- [iPad 分享与提交 App Playground](https://support.apple.com/en-lamr/guide/playgrounds-ipad/share-a-playground-itc65b2d9a15/4.6/ipados/18.0)
