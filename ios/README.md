# 云美门锁 iOS

依据 ../docs/PORT-SPEC.md 移植 cc.xypp.yunmeiui 2.0.1。iOS 16.0+、SwiftUI、Apple 系统框架，无第三方运行时依赖。Lock.swift 和 UnlockFrame.swift 保持定稿版本。

## 文件清单

- App：YunmeiLock/App/YunmeiLockApp.swift、YunmeiLock/App/RootView.swift。
- Net：YunmeiLock/Net/MD5.swift、YunmeiLock/Net/HTTPClient.swift、YunmeiLock/Net/YunmeiAPI.swift。
- Store：YunmeiLock/Store/SecureStore.swift、YunmeiLock/Store/Settings.swift、YunmeiLock/Store/LockStore.swift。
- 硬件：YunmeiLock/Ble/BleUnlockService.swift、YunmeiLock/Location/LocationProvider.swift、YunmeiLock/NFC/NFCService.swift。
- QR：YunmeiLock/QR/QRGenerator.swift、YunmeiLock/QR/QRScannerView.swift。
- UI：YunmeiLock/UI/LoginView.swift、YunmeiLock/UI/MainView.swift、YunmeiLock/UI/LockInfoView.swift、YunmeiLock/UI/AddLockView.swift、YunmeiLock/UI/SettingsView.swift、YunmeiLock/UI/ShareQRView.swift。
- 配置与文档：YunmeiLock/Info.plist、project.yml、README.md。
- 测试：Tests/YunmeiLockTests/LockTests.swift、Tests/YunmeiLockTests/UnlockFrameTests.swift。

## 构建

在 macOS 安装 Xcode 并完成首次启动，在本目录运行：

    brew install xcodegen && xcodegen generate && open YunmeiLock.xcodeproj

Xcode 中选择 YunmeiLock scheme，签名和 Team 需自行填写。真机需要付费 Apple 开发者账号，并在 App ID 和 provisioning profile 启用 NFC Tag Reading；project.yml 会生成含 NDEF entitlement 的 YunmeiLock/YunmeiLock.entitlements。不可直接在 Windows 编译 iOS 工程。

测试：在 Xcode 中选择可用 iOS 模拟器并执行 Product → Test；或运行 xcodebuild -project YunmeiLock.xcodeproj -scheme YunmeiLock -destination 'platform=iOS Simulator,name=<本机模拟器名称>' test。测试包括 Lock 深链、旧格式、开锁帧、UTF-16 长度字段和 RFC1321 全部七条 MD5 向量；MD5 断言位于 LockTests.swift。蓝牙、NFC、定位和摄像头仍需真机验证，不以单元测试代替。

## 使用

登录并获取学校；多学校时选择学校，再添加本人的门锁。主页选择门锁后开锁，也可扫码或导入 yunmeiui:// 深链添加门锁。门锁详情可设默认、删除及经三次危险确认后分享二维码或写 NFC。二维码和 NFC 文本都含完整门锁密钥，只能向极信任的人线下分享。

BLE 用 Service UUID 过滤扫描，匹配 Characteristic UUID 后以 withResponse 分片写入，最后一次 didWriteValueFor 成功才显示完成。快速连接优先使用此前成功连接保存的 CBPeripheral.identifier；没有缓存则扫描。快速尝试失败仅回退一次常规扫描，开始写入后不再重试，避免重复开锁。

打卡位置询问中，“确定”重新定位，“打卡”使用上次位置，“放弃”取消。仅服务器导入且留有 schoolNo、lockNo 和学校会话的门锁可以打卡；分享数据不含这些字段，不猜测门锁编号。选择门锁会同步其学校及编号，避免向另一门锁打卡。

## iOS 限制与取舍

- iOS 不提供外设 MAC，也不允许按 MAC 扫描。mac 仅保留用于旧格式，开锁不使用它。后台蓝牙、锁屏静默开锁均未启用。
- 后台/锁屏贴 NFC 不能静默拉起并自动开锁，需要用户解锁并确认。此版按契约写 NDEF 文本记录而非 URI；文本记录不保证触发系统后台打开 App，自定义 scheme 也不等于 Universal Link。需通过能读取该文本的工具打开深链，或使用 App 内扫码。NFCReaderSession 没有为普通文本提供自动分发保证。
- CoreNFC 无通用的非 NDEF 标签格式化能力；不支持 NDEF、只读或容量不足均回报“标签不可写！”。本版没有扩展契约外的前台读标签入口。
- iOS 不支持 App 合规地自行退出。autoExit 仍保存并保留原文“开门完成，程序将自动退出”，但不会调用 exit、私有挂起 API 或假装已经退出；用户需自行离开 App。
- 密码及含密钥的锁列表、默认锁、会话放入本机解锁后可访问且不同步的 Keychain；其他列出的设置使用 UserDefaults。loginPsw 属性/键名不变，但不继续明文存 UserDefaults；存在旧值时迁移。
- 不新增全局 ATS 放宽。若学校只提供 HTTP 地址，应向运营方确认 HTTPS，或自行评估并配置特定域名例外。

## 规格中未明确的部分

- §1 未具体定义学校 serverUrl 含路径前缀时的拼接。实现去除连接处的多余斜线，保留 baseURL 原有路径前缀，不使用会丢弃前缀的绝对路径解析。
- sigLoc 仅给出 ask，未定义其他枚举值。实现 ask 为询问、current 为重新定位、last 为上次定位；未知值按重新定位处理。rel/lst 未说明格式，以前次/本次登录时间戳字符串保存。
- NFC 本地匹配的“两字段”未给出名称。lock_id 深链用 Service UUID + Characteristic UUID 匹配；优先同 label，否则必须只有一个候选；有歧义时拒绝开锁，并要求前台确认。
- §2 对 DATA_VER 的描述与已定稿 Lock.swift 有差异。严格保留定稿文件：读取第六段，但序列化固定回写 1.1；前缀解析和 Base64 容错也不改动。入口仅先做 URL 百分号解码，避免系统编码破坏 Base64。
- §9 只列出部分界面文案；其中列出的状态、错误和危险提示逐字保留，其余导航与字段名称采用 §7 所述功能的中文名称。
- **服务器学校列表格式已变更（2026-10 生产实测）**：`/userschool/getbyuserid` 实际返回**平铺**数组元素（`id`/`isDel`/`userId`/`schoolNo`/`isAdmin`/`token` 等），不再包含嵌套 `school` 对象。实现同时兼容平铺与嵌套两种格式：`schoolName` 缺失时留空，`serverUrl` 缺失时回退到基址 `https://base.yunmeitech.com/`（该基址当前可直接提供门锁/打卡接口）。
- 生产环境 `token` 是 JWT，声明里含 `SchoolName`/`UserAgent`/`LoginUser` 等信息；不要把 token 当固定格式解析，也不要只依赖 JSON 顶层的学校名字段。

## 交付检查

2026-10 已通过 GitHub Actions（macos-15 / Xcode 16.4 / iOS 18.5 SDK）**真实编译并跑单测**：模拟器 build 通过、XCTest 12/12 通过、真机 Release（未签名）构建通过。产物经 Sideloadly + 免费 Apple ID 装入 iPhone（iOS 27.0.1）实测：登录、学校/门锁列表、蓝牙开锁、打卡均成功；Sideloadly Daemon 自动续签已实测生效。NFC 写标签/贴标签需付费开发者账号，未验证（免费账号下入口置灰）。`Lock.swift`、`UnlockFrame.swift`、`UnlockFrameTests.swift` 的 SHA-256 与最初版本一致。
