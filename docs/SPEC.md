# 实现 Spec · V2

## 平台与模块

Swift 5、SwiftUI、UIKit 图片选择、PhotosUI、Charts、HealthKit、Security；最低 iOS 17，目标 iOS 27。不引入第三方原生 SDK。项目生成器使用 Python 标准库，生成 Xcode application target；纯数据模型单独 Swift Package 可测试。

原生根 App 创建 MealStore 和 HealthService，RootView 传给页面；所有 UI 状态修改在 MainActor。识别服务不持有 UI 状态。SwiftUI 使用 NavigationStack、sheet、confirmationDialog 和系统字体/SF Symbols。

## 数据定义

FoodItem: id UUID、name String、grams Double、kcal Double（照片中的完整份量）、consumedFraction Double、protein/fat/carbs Double?、assumption String。effectiveKcal=kcal×fraction；grams 同样乘 fraction；缺失营养值传播为 nil，不虚构总营养。

Meal: id UUID、date Date、kind breakfast/lunch/dinner/snack、foods、photoFileName?、note、version Int、healthStatus（notRequested/pending/synced/failed）、healthError?。仅保存确认过的合法 meal。编辑保持 UUID，version 增长；外部同步状态先变 pending，待成功再 synced。

Settings: goal（可选但首版默认 1800 为用户可改的记录目标，不是推荐）、displayName、modelEndpoint、modelName、writeHealth Bool。密钥不在 Settings、UserDefaults 或导出内。目标范围 500...10000，说明仅用于记录。

## 状态机

Capture: idle → selected → uploading → reviewing → saving → saved。uploading 失败回 selected，显示具体错误；关闭流程保留本次选图到 sheet 生命周期结束；中止不生成记录。手动入口直接到 reviewing。重试只分析，不先保存。

多图同餐暂未实现，第一版明确只接受单图；避免按钮存在而无法正确去重。结果页每项可编辑删除，添加必须创建合法食物，最终无食物禁止保存。用户点击保存期间禁用重复点击。

本机保存是独立事务，HealthKit 写入在其后异步执行。失败显示本机已保存/健康失败；不回滚餐食。app 重新进入同步页允许重试 pending/failed；删除餐食前健康删除失败需提示并允许保留重试记录。

## 各页面

- 今日：按当前本地日汇总；环图最大目标为 100%，超额用文字表述，不把角度无限累加。未读到基础/活动消耗显示 —，不计算虚假净缺口。数据同步入口可达。
- 日记：日期选择和周条、当日已记录摄入、餐食照片/条目。每餐进入详情编辑；删除需确认。
- 拍照：相机可用检测，相册 PhotosPicker。相机被拒绝提供相册/手动入口。图片压缩到 JPEG 后发送；第三方发送明确确认。
- 结果：食物名称、估算克重、分项 kcal 与实际摄入；可选宏量合计；按设置显示“确认并保存”或“保存并写入 Apple 健康”，不显示未接通小米的成功按钮。
- 趋势：周/月/年切换，按实际餐食日期聚合；未记录日留空。健康消耗图只展示已读取对应日期，不能拿今天的值填满历史。
- 我的：名称/目标、每日目标、数据同步、模型配置、导出、隐私。iCloud 与离线引擎为禁用说明，不显示假开关。
- 数据同步：请求权限、刷新真实数据、写健康开关、失败重试；小米复制说明。数据源标注 Apple 健康，不编造小米来源。

## 文件与恢复

Application Support/LightMeal 下存 meals.json 与照片；路径仅使用内部 UUID 名称，禁止任意路径注入。原子写入、completeUnlessOpen 文件保护与 excludedFromBackup。读取损坏文件时显示错误且不开放覆盖写入，直到显式恢复；不能偷偷清空记录。

## 视觉

忠实沿用用户 V2 的浅灰紫背景、圆角白卡、橙色动作和绿色消耗。原生系统状态栏由系统提供，底部 safeAreaInset 定制五入口。日期取设备本地值；不继续使用截图中固定 9 月 23 日。大字号及深色模式适配；图表有文字替代，交互区至少 44 pt。

## 预览界限

静态本机 Node 文件服务；纯浏览器模块使用 localStorage 保留演示餐食，照片保存失败必须显示容量提示。默认不伪造个人历史；显式“加载示例”才加入示例数据，示例标签持续可见。上传本地照片仅本地预览，不发送；演示识别返回固定且明确标记的样例；真实 AI 仅原生配置后运行。

## 验证

无自有 Mac 路线：`.github/workflows/ios-build.yml` main 推送与 workflow_dispatch 均可触发，默认 macos-26，允许选择 xcode-27 公开预览 runner。执行 verify-mac.sh 与未签名 iphoneos build；只读仓库权限，没有签名 secrets 或部署步骤，没有安装包产出。构建环境不是业务后台，云端与真机验收状态分别记录。`preview-server.mjs --lan --port=4174` 可选择同网访问静态预览，默认仍仅本机4173；不能因此认定跨端同步或 HealthKit 已实现。

Node 内置 test 验证真实预览领域模块：边界、有限值、比例、总营养缺失、UUID 去重、跨日、无记录留空、schema 与导出。突变计算检查证明测试会失败。Python 项目检查覆盖源文件引用、Info.plist 权限、签名能力、入口与 scheme。Swift XCTest 定义同类领域/解析测试，当前系统不能执行。Mac 运行 swift test 与 xcodebuild，再真机验相机、真实模型、HealthKit、重启持久化。

## 非交付承诺

没有签名 IPA；没有证明 App Store 可上架；没有小米餐食自动写入；没有个人健康 CloudKit 同步；没有已验证的端侧视觉模型。预览测试通过不能勾选这些验收。
