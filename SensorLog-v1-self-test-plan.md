# SensorLog v1 工程实现规格

## Summary

- 构建一个 iPhone 本机传感器体检台，App 显示名暂定为 `SensorLog`。
- v1 目标：实时查看 iPhone 可用传感器数据、展示权限和设备支持状态、手动保存本地快照历史、分享单条快照 JSON。
- 最低系统：`iOS 17.0`。
- 目标设备：优先 iPhone 17 真机；模拟器仅用于 UI、导航、历史列表、本地化和空状态测试。
- 技术栈：原生 Xcode iOS App，SwiftUI + SwiftData + Core Location + Core Motion。
- 数据策略：全部数据仅保存在本机；不上传，不使用服务器，不接第三方 SDK。
- 语言：简体中文和英文，跟随系统语言或 iOS 单个 App 语言设置。
- v1 不做成熟 Sensor Logger 路线：不做后台连续记录、HTTP/MQTT、云同步、Apple Watch、HealthKit、地图、账号系统、App Store 上架材料。

## Development Setup

- 使用 Xcode 创建原生 iOS App 工程：
  - Interface: `SwiftUI`
  - Language: `Swift`
  - Storage: `SwiftData`
  - Minimum Deployments: `iOS 17.0`
- 使用 Xcode 自动签名：
  - Team 选择已登录 Apple Account / Personal Team。
  - Bundle Identifier 建议使用 `com.zhongbintao.SensorLog`，如被占用则使用同前缀的唯一值。
  - 勾选 `Automatically manage signing`。
- Xcode 命令行工具应指向完整 Xcode：
  - `xcode-select -p` 应显示 `/Applications/Xcode.app/Contents/Developer`。
  - 已安装 iOS Simulator runtime 后，`xcrun simctl list runtimes` 应能看到 iOS runtime。
- 真机测试前准备：
  - iPhone 用 USB 连接 Mac，并信任此电脑。
  - iPhone 开启 Developer Mode。
  - Xcode 顶部运行设备选择目标 iPhone。

## App Structure

- 使用 3 个主 Tab：
  - `Sensors`：实时传感器总览。
  - `History`：本地快照历史。
  - `Settings`：权限状态、传感器支持状态、数据管理、App 信息。
- 每个 Tab 内使用 `NavigationStack`。
- v1 使用系统原生控件和简洁列表/分组布局，不做复杂自定义视觉系统。
- 数值展示必须同时显示单位；暂无数据、权限受限、设备不支持时不得显示误导性的 `0`。

## Sensors Tab

- 页面目标：实时展示当前可用传感器状态和最新读数。
- 顶部提供 `Save Snapshot` / `保存快照` 操作，将当前实时状态保存到 SwiftData。
- 传感器按分组展示：
  - Location / 位置：纬度、经度、水平精度、速度、海拔、航向。
  - Motion / 运动：用户加速度、重力加速度、陀螺仪旋转率、设备姿态 roll/pitch/yaw。
  - Barometer / 气压：相对高度、气压。
  - Pedometer / 计步：步数、估算距离、上楼层数、下楼层数。
  - Activity / 活动识别：静止、走路、跑步、骑行、车载、未知。
  - Device / 设备状态：电量、是否充电、低电量模式、热状态。
- 权限按需申请：
  - 不在 App 启动时连续弹权限。
  - Sensors 页面展示权限状态和请求按钮。
  - 用户点击位置权限按钮时请求 `When In Use` 位置权限。
  - 用户点击运动相关权限按钮或开始读取运动数据时触发系统运动权限请求。
- 刷新策略：
  - Core Motion 运动数据以约 50Hz 采样。
  - UI 以约 10Hz 显示最新汇总值，避免文字高速抖动。
  - 位置、计步、活动识别按系统回调更新，不强行高频轮询。
- 状态展示：
  - `waiting`：等待第一条数据。
  - `available`：已有可用数据。
  - `unavailable`：当前设备或模拟器不支持。
  - `denied`：用户拒绝权限或系统权限受限。
  - `error`：读取失败或保存失败，显示本地错误说明。

## History Tab

- 页面目标：查看、管理、分享本地保存的快照。
- 列表按时间倒序显示快照。
- 每条列表项显示：
  - 保存时间。
  - 主要摘要：位置是否可用、运动是否可用、气压是否可用、计步是否可用。
  - 活动类型和电量状态，如有数据。
- 支持打开快照详情页。
- 详情页显示该快照的完整字段，按传感器分组。
- 支持删除单条快照。
- 支持清空全部快照，清空前必须二次确认。
- 支持分享单条快照 JSON。
- 历史数量上限为 500 条：
  - 保存新快照后，如果总数超过 500，删除最旧记录。
  - 删除最旧记录失败时，不得影响新快照保存结果，但应显示可理解的错误提示。

## Settings Tab

- 页面目标：集中展示权限、设备能力、数据和 App 信息。
- 权限状态：
  - Location：not determined、authorized when in use、denied、restricted。
  - Motion & Fitness：available、denied/restricted、unknown；iOS 对 Core Motion 权限状态不可完全等同于 Location，文案避免承诺能精确判断所有状态。
- 设备能力状态：
  - Device Motion 是否可用。
  - Gyroscope 是否可用。
  - Accelerometer 是否可用。
  - Barometer / Altimeter 是否可用。
  - Pedometer 是否可用。
  - Activity Recognition 是否可用。
- 数据管理：
  - 当前快照数量。
  - 清空全部快照。
- App 信息：
  - App 名称：`SensorLog`。
  - 版本：读取 bundle short version 和 build number。
  - 数据策略：只保存在本机，不上传，不接第三方 SDK。
  - 自测说明：模拟器不能用于判断真实传感器能力。

## Permissions And Info.plist

- 必须配置隐私说明：
  - `NSLocationWhenInUseUsageDescription`
  - `NSMotionUsageDescription`
- 不申请后台定位权限。
- 不配置 HealthKit、Bluetooth、NFC、Camera、Microphone、Contacts、Photos 权限。
- App 不应请求网络权限，也不应加入服务器地址、API Key 或第三方 SDK 初始化代码。

## Data Model

- 使用 SwiftData 保存快照模型 `SensorSnapshot`。
- `SensorSnapshot` 字段允许大量 optional，因为快照保存时可能只有部分传感器可用。
- 建议字段：
  - `id: UUID`
  - `createdAt: Date`
  - Location：`latitude`、`longitude`、`horizontalAccuracy`、`speed`、`altitude`、`course`
  - Motion：`userAccelerationX/Y/Z`、`gravityX/Y/Z`、`rotationRateX/Y/Z`、`roll`、`pitch`、`yaw`
  - Barometer：`relativeAltitude`、`pressure`
  - Pedometer：`stepCount`、`distance`、`floorsAscended`、`floorsDescended`
  - Activity：`activityType`、`activityConfidence`
  - Device：`batteryLevel`、`batteryState`、`isLowPowerModeEnabled`、`thermalState`
- 运行时状态建议拆分为非持久化类型：
  - `LiveSensorState`：表示每组传感器的实时读数和状态。
  - `SensorPermissionState`：表示位置和运动权限状态。
  - `SensorAvailability`：表示设备是否支持某类传感器。
- 保存快照时：
  - 读取当前 `LiveSensorState`。
  - 有数据的字段写入数值。
  - 无数据、不可用或未授权字段写入 `nil`。
  - 保存失败时显示本地错误提示。

## JSON Snapshot Export

- v1 只支持分享单条快照 JSON，不做连续记录导出。
- JSON 必须可读、稳定、包含 schema version。
- 建议顶层结构：

```json
{
  "schemaVersion": 1,
  "app": "SensorLog",
  "createdAt": "2026-07-09T12:00:00Z",
  "device": {
    "model": "iPhone",
    "systemName": "iOS",
    "systemVersion": "26.5"
  },
  "readings": {
    "location": {},
    "motion": {},
    "barometer": {},
    "pedometer": {},
    "activity": {},
    "device": {}
  }
}
```

- JSON 中缺失的传感器组可以为空对象，单个不可用字段可以省略或写 `null`，但同一版本内必须保持一致。
- 分享入口放在快照详情页。

## Localization

- 使用 String Catalog：`Localizable.xcstrings`。
- 支持：
  - English
  - Simplified Chinese
- UI 文案不得硬编码在业务逻辑中。
- 单位和状态文案必须本地化：
  - waiting / 等待数据
  - unavailable / 不可用
  - denied / 权限受限
  - error / 错误
  - save snapshot / 保存快照
  - clear history / 清空历史
- 数字格式遵循系统 locale；经纬度、米、米/秒、hPa、步数等单位要明确。

## Error Handling

- 权限拒绝：
  - 显示当前权限受限。
  - 提供打开系统设置的入口。
- 设备不支持：
  - 对应分组显示不可用。
  - 不影响其他传感器读取。
- 暂无数据：
  - 显示等待数据。
  - 不用 `0` 代替未知值。
- 保存失败：
  - 显示错误提示。
  - 不崩溃，不丢失当前实时显示。
- 分享失败：
  - 显示错误提示。
  - 不影响历史记录。

## Test Plan

### Simulator

- App 能构建、安装、启动。
- 3 个 Tab 导航正常。
- Sensors 页面可显示等待数据、不可用状态、权限提示。
- History 页面可使用测试数据验证列表、详情、删除、清空。
- Settings 页面可显示权限状态、设备能力状态、快照数量、App 信息。
- 中英文切换后主要文案正确。
- 模拟器测试不得作为真实传感器能力和准确性的判断依据。

### iPhone 17 Device

- App 能通过 Xcode Run 安装并启动。
- 首次进入不崩溃，权限按需触发。
- 拒绝位置权限后，Location 分组显示权限受限，其他分组继续工作。
- 允许位置权限后，经纬度、精度、速度、海拔、航向按可用性更新。
- 运动数据可在静止、移动、旋转设备时变化。
- 气压和相对高度在设备支持时显示；不支持时显示不可用。
- 计步在走路后更新；暂无数据时显示等待数据。
- 活动识别在静止、走路、跑步、车载等场景下按系统结果显示。
- 飞行模式下仍可查看可用传感器并保存历史。
- 低电量模式下 Device 分组能反映状态。
- 保存快照后 History 立即出现记录。
- 快照详情显示完整分组和 optional 字段状态。
- 单条删除和清空全部正常。
- 单条 JSON 分享内容完整且可读。
- 超过 500 条历史后最旧记录被清理。

## Acceptance Criteria

- 项目为原生 iOS SwiftUI App，最低支持 `iOS 17.0`。
- 不包含服务器请求、第三方 SDK、账号系统或远程配置。
- 不申请后台定位、HealthKit、蓝牙、NFC、相机、麦克风等 v1 非目标权限。
- App 数据只保存在本机 SwiftData。
- 传感器不可用、权限拒绝、暂无数据、保存失败都有明确 UI 状态。
- 真机安装可通过 Xcode Run 完成。
- 模拟器和真机测试结果按本计划记录。

## Future Versions

### V2 Offline Sensor Quality Plan

V2 目标：在不主动联网、不上传数据的前提下，把 App 从“传感器接口展示”升级为“离线传感器质量分析工具”。App 仍不加入服务器、第三方 SDK、API Key 或远程配置；定位可使用 iOS 系统定位服务在有网络时自动获得的系统辅助结果，但 App 本身不发网络请求。

#### P0

- 传感器可信度评分：
  - 为 Location、Motion、Barometer、Pedometer、Activity 增加 High / Medium / Low 质量状态。
  - Location 质量依据：水平精度、垂直精度、定位更新时间、速度有效性、航向有效性。
  - Motion 质量依据：采样稳定性、加速度噪声、陀螺仪噪声。
  - Barometer 质量依据：气压波动、相对高度漂移、设备支持状态。
- 静止检测：
  - 使用用户加速度模长、陀螺仪旋转率、短时间窗口方差判断设备是否静止。
  - 静止时解释小幅加速度变化为传感器噪声，不误判为真实运动。
- 原始值 / 平滑值切换：
  - 提供 Raw / Smoothed 显示模式。
  - 平滑算法优先使用指数移动平均或滑动平均。
  - 对低于阈值的微小加速度和角速度提供显示层归零。
- 定位质量面板：
  - 显示水平精度、垂直精度、定位更新时间、速度有效性、航向有效性。
  - 低质量定位时显示原因，例如精度差、数据过旧、速度低可信。
- 速度可信度判断：
  - 速度继续来自 `CLLocation.speed`，不自行伪造速度。
  - 当设备静止且定位漂移导致速度跳动时，标记为低可信或显示静止。

#### P1

- 姿态角中文化：
  - Roll：横滚角 (Roll)
  - Pitch：俯仰角 (Pitch)
  - Yaw：偏航角 (Yaw)
  - 支持 radians / degrees 单位切换。
- 采样稳定性统计：
  - 显示最近窗口内的实际采样频率、最小值、最大值、平均值、标准差。
  - 先覆盖 Motion 和 Barometer。
- 离线定位说明：
  - 说明 App 不主动联网。
  - 说明无网络时定位主要依赖 GPS/GNSS 和本机传感器，有网络时 iOS 系统定位服务可能使用 Wi-Fi / 蜂窝辅助。
- 异常标注：
  - 静止状态下速度不为 0：疑似定位漂移。
  - 水平精度或垂直精度过差：位置低可信。
  - 气压或相对高度突变：可能是环境变化或传感器波动。

#### P2

- App 打开期间的短窗口时间线：
  - 最近 30-60 秒加速度、陀螺仪、气压、相对高度、速度曲线。
- 离线移动状态融合：
  - 融合 Core Location speed、pedometer、activity recognition、acceleration variance、gyro variance。
  - 输出静止、手持移动、步行、跑步、车载、疑似定位漂移。
- 气压高度校准：
  - 支持用户手动输入当前海拔作为基准。
  - 后续显示相对高度变化和估算海拔。
- Snapshot JSON v2：
  - 增加 quality score、confidence、smoothing mode、sample window statistics、warnings。
- 本机诊断报告：
  - 汇总设备传感器支持、权限状态、当前读数可信度和低可信原因。

### Longer-Term Ideas

- 连续记录会话和 CSV 导出。
- 地图视图和轨迹显示。
- HealthKit 集成。
- Apple Watch 支持。
- 后台记录。
- HTTP/MQTT/WebSocket 实时输出。
- Shortcuts 集成。
- App Store 上架材料、隐私营养标签和 TestFlight 流程。

## Assumptions

- v1 是自测版，不准备 App Store 上架。
- App 自测阶段显示名继续使用 `SensorLog`；未来若上架，需重新评估命名，因为 App Store 已有同名成熟 App。
- 以 iPhone 真机测试为准，模拟器只验证界面和本地数据流程。
- JSON 分享只针对单条快照，不实现连续记录导出。
- 历史上限固定为 500 条。
- 运动数据采用约 50Hz 采样、约 10Hz UI 显示的策略。
