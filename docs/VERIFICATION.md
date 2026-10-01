# 验证记录与交付状态

日期：2026-10-01，Asia/Shanghai。整体状态 **PARTIAL**：文档、原生源码和交互预览已提供；原生编译、真实 AI 与 HealthKit、以及用户要求的全部跨端/小米能力尚未完成验收。没有 IPA，没有上架或外部发布。

## 文档与流程

PRD → API → Spec 先于实现落盘。用户已授权直接开发，不再设置中间确认。Linchpin 路由确认作者路径；合同检查 `CONFORMING docs/PRD.md`。当前不是 Git 仓库，因此没有启动 Linchpin 多模型/分支流水线，没有提交、PR、合并或虚构独立审查结果。

Contract conformance: prd_contract: v1（结构检查通过；不代表产品验收全部完成）。

## 自动检查

| 命令 | 实际结果 | 证据 |
|---|---|---|
| `node --test tests/core.test.mjs` | exit 0；24 tests, 24 pass, 0 fail | evidence/domain-tests.txt |
| `node scripts/negative-control.mjs` | exit 1；禁用实际比例计算后 4 tests fail | evidence/domain-negative.txt |
| `python scripts/generate-project.py` | exit 0；生成 14 Swift 源文件的 Xcode 工程 | evidence/project-generation.txt |
| `python scripts/check-project.py` | exit 0；源码引用、入口、权限及共享 scheme 通过 | evidence/project-check.txt |
| `python scripts/check-project.py --negative` | exit 1；Missing referenced source: LightMeal/App/Missing.swift | evidence/project-negative.txt |
| `node --check preview/app.mjs` | exit 0 | 本次终端输出 |
| Linchpin `contract docs/PRD.md` | CONFORMING，exit 0 | 本次终端输出 |

负向变更发生在临时模块副本/校验输入，不破坏生产源码。项目结构检查不是 Swift 编译器。Node 测试的是预览实际引用的 JS 领域模块，不是原生 HealthKit 和 SwiftUI。

## Gate Evidence

| Gate | Result | Observed-red evidence | Exact command/result |
|---|---|---|---|
| preview-domain | PASS | 禁用 consumedFraction 后总量、零摄入、更新与复制测试失败 | command: node scripts/negative-control.mjs; result: RED observed: consumed fraction disabled; exit: 1 |
| project-integrity | PASS | 添加缺失源码引用后检查失败 | command: python scripts/check-project.py --negative; result: RED observed: Missing referenced source: LightMeal/App/Missing.swift; exit: 1 |

## 浏览器实际流程

通过 Codex 内置浏览器实际打开 http://127.0.0.1:4173。检查桌面默认窗口和 390×844 移动视口，之后恢复默认视口；预览保留为可查看产物。

1. 空历史显示未记录与未连接；显式加载示例得到 386 + 457 + 328 = 1171 kcal，示例餐食持续标记。
2. 从午餐进入编辑，米饭 232 kcal 调为 50% → 116 kcal；总餐 457 → 341 kcal。
3. 确认保存后详情显示 341；刷新后今日合计 1055（386+341+328），无重复午餐。
4. 手动新增“手动测试燕麦”180 kcal，经表单完成与保存进入详情；后续清理测试记录。原生系统确认弹窗曾阻塞浏览器控制，删除确认改为应用内 dialog。
5. 日记日期和餐食列表可达；趋势从当前实际记录聚合 1171，仅显示有记录的日期，不填充虚假消耗。
6. 我的、数据同步和模型说明可达；所有未接通平台标记未连接。
7. 目标从 1800 改为 1900 保存成功，再恢复 1800；键盘操作可完成表单和导航。
8. 最终浏览器 `dev.logs` 的 error/warn 列表为空。

曾发现并修复的真实问题：表单隐藏输入 name=id 遮蔽 HTMLFormElement.id，导致食物编辑不提交；改为 getAttribute('id')，上述 50% 回写与刷新流程复验通过。短桌面窗口最初隐藏底部导航，改用受限高度与内部滚动，移动截图确认导航可见。

照片选择曾以本地设计 PNG 验证文件选择，仅验证 UI，不是食物识别。文件选择耗时且随后页面状态变化，**演示识别失败→重试全流程未完成可靠浏览器验收**，不列为已通过。对应服务错误源码和解析单元测试已提供，需后续补验。

## 原生工程状态

原生入口、SwiftUI 七页面、照片选择/相机桥接、密钥钥匙串、HTTPS 视觉请求、校验与本机原子持久化、按日期历史、编辑比例、导出/导入文本、健康授权、今日健康查询、膳食能量版本写入及删除已接入调用路径。

2026-10-01 云端构建更新：commit `4d1def53182b414b05a888c8ce34a206305aefc8`，标准 macos-26 runner，Xcode 26.6 / SDK 26.5。24项 Node 测试、7项 Swift XCTest、Debug 模拟器编译及 Release 未签名 arm64 设备编译全部通过。[构建日志](https://github.com/Sunshine-D/i-sport/actions/runs/36850506933)，摘要见 evidence/cloud-build.txt。没有签名、安装或运行模拟器 App，未使用 iOS 27 SDK。构建有 AppIntents 元数据提示与 iPad 全方向支持警告，待后续适配。

下面仍为 **NOT RUN**：

- 真机相机、照片权限、Keychain、持久化重启与文件保护。
- 用户提供真实视觉服务配置后的餐食识别（没有凭据，不发送请求、不扣费）。
- HealthKit 读取、样本更新防重与删除；需正确 Team/HealthKit capability 和真机。
- VoiceOver、动态字体、深色模式的原生运行验证。

未实现/未接通：多图同餐、历史体重/消耗曲线、每个健康类型独立授权 UI、小米减重每餐自动写入、完整历史 iCloud 多端、端侧离线视觉模型。日记可以调整食物但尚未支持已保存餐次/日期的重新编辑；记录时可设置餐次日期。设计中的完整数据来源和功能不能视作全部交付。

## 续跑入口

个人自用补充：commit `f4744c7addcd3686bcece35e13909e8b06f90664` 的 [构建36855896887](https://github.com/Sunshine-D/i-sport/actions/runs/36855896887)全部通过，包括完整版与 `SELF_USE_BASIC` 基础版的未签名 arm64 编译、两个 IPA 打包和 artifact 上传。基础版编译条件下不构造 HKHealthStore、不访问 HealthKit；完整版仍保留健康实现。打包器使用临时 .app 验证 Payload 结构并拒绝模拟器平台输入。签名、iOS 27 安装、照片/钥匙串与真实 AI 尚未真机验证。

最新结果：下述无 Mac 补充与“未执行”说明保留初始阶段记录；GitHub 首次构建现已成功，详见上文云端更新与 evidence/cloud-build.txt。`verify-mac.sh` 已在 macos-26 runner 执行通过；签名与真机测试尚未执行。

2026-10-01 无 Mac 补充：提供 docs/NO-MAC.md、手动触发的 GitHub macOS 未签名编译配置，以及可选 LAN 静态预览。Node 服务器语法检查通过，24 项领域测试与工程静态检查复验通过；Windows 本机访问 `http://10.167.4.116:4174/` 的 LAN 服务返回 HTTP 200。未在用户 iPhone / iPad 上验证网络可达性或 Safari 行为。GitHub workflow 尚未运行，没有签名、上传或安装结果。此处验收只涉及本地服务配置，完整产品状态不变。

Windows 本机：`npm run dev`；领域检查：`npm test`；配置检查：`npm run check`。预览无运行依赖，Lucide 浏览器图标包随项目携带及保留许可证。

Mac：运行 `bash scripts/verify-mac.sh`。脚本调用 swift test 和无签名模拟器构建；若失败应修复后复验。然后打开 ios/LightMeal.xcodeproj 设置签名，逐项做相机、模型与健康真机验收。该脚本当前未在 Mac 执行，不能说它已通过。

小米/iCloud/端侧所缺前提和后续接口需求见 API.md，不将无来源的私有接口或示例结果作为解决方案。
