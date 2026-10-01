# iPhone 自用：先不购买苹果开发者会员

当前用途为个人 iPhone 使用，iPad 次要。不准备 App Store / TestFlight 分发，不要求先购买 Apple Developer Program 会员。

云端构建现在生成两个未签名包：

- `LightMeal-basic-unsigned.ipa`：独立基础自用构建，保留原生相机、用户配置的真实视觉请求、钥匙串和本机历史；编译时关闭 HealthKit 调用与签名能力。用于优先验证免费账号的安装和基础流程，不能当作完整健康同步版本。
- `LightMeal-health-unsigned.ipa`：保留 HealthKit 实现的完整构建；对应签名能力与免费账号的兼容性尚未验证，不承诺能使用健康功能。

这两个包不含模型密钥、签名材料或真实个人历史；需要在 Windows 本地重新签名才能尝试安装，不能在 iPhone 文件应用中点开直接安装。基础版 Bundle ID 为 `com.sunshined.lightmeal.basic`，与完整版本的数据独立，切换版本应先导出记录。

## 操作顺序

1. 打开仓库 Actions，选择最新成功构建，在 Artifacts 下载 `LightMeal-unsigned-self-use` ZIP，解压取得 IPA。不要选择先前仅编译检查的运行，它没有文件产物。
2. 按 [AltStore Classic 的 Windows 官方步骤](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)安装 Apple 依赖和 AltServer。AltStore Classic 与 AltStore PAL 是不同路线，此处使用 Classic。先确认其最新版本支持自己的 iOS 版本；本项目未验证 iOS 27 安装兼容性。
3. USB 连接并信任 iPhone，按官方步骤配置 Wi-Fi 同步，使用自己的 Apple 账号安装 AltStore。账号、密码及验证码仅由用户在官方软件中输入，不提供给本项目或聊天。
4. 依照工具提示开启开发者模式。将基础版 IPA 传到 iPhone 文件应用，在 AltStore 的 My Apps 使用＋选择它重新签名安装。
5. 安装成功后打开轻食记：先手动记一餐并重启确认保存，再检查相机；在“我的”配置 HTTPS 视觉服务地址、模型与个人密钥，确认发送照片后测试真实识别。API 调用收费取决于所配置服务，免费签名不表示模型免费。
6. 免费账号应用通常7天到期，需在到期前用 AltStore / AltServer 刷新签名；具体操作见 [官方刷新说明](https://faq.altstore.io/altstore-classic/your-altstore)。最多3个侧载 App 的限制也适用，AltStore 本身占用其中一个位置。刷新通常需要 Windows 与 iPhone 同网且 AltServer 运行。

## 未验证与保留要求

用户自用并不等于无需苹果签名，也不会自动解锁所有受限能力。安装、签名刷新、iOS 27 相机/钥匙串及真实识别均需要实际设备验证；没有宣称已完成这些检查。Apple 健康、小米每餐自动导入、iCloud 多端同步仍是保留的原始需求。基础自用版关闭健康能力只用于先验证基础流程，不替代这些验收。免费路线若无法满足受限能力，应报告具体阻塞后再决定后续方案。
