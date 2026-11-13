# 迁移报告:Android 云美门锁 → iOS

## 结论

`cc.xypp.yunmeiui` 2.0.1 已按源码级移植到 iOS(SwiftUI),共 23 个 Swift 文件,覆盖登录/学校选择/门锁列表/BLE 开锁/门锁详情/默认锁/二维码分享与扫码/NFC 写读/打卡/设置全部功能。

**但必须先说清楚:本机是 Windows,没有 Swift 工具链、没有 Xcode、没有 Docker/WSL,所以这套代码没有经过编译器验证。** 我做了两层自动化静态验收(见下),它能排除"类型/成员不存在""注入缺失""括号不平衡"这类硬错误,但不能替代 `xcodebuild`。第一次在 Mac 上编译时,预计仍需修少量语法级问题(最多半天)。

## 交付物

```
ios\
  project.yml                     XcodeGen 工程描述(iOS 16,无第三方依赖)
  YunmeiLock\                     源码 + Info.plist + entitlements
  Tests\YunmeiLockTests\          LockTests / MD5Tests / UnlockFrameTests
  scripts\build-macos.sh          macOS 一键编译/测试
  README.md                       构建说明与差异说明
docs\PORT-SPEC.md                 协议与接口说明
docs\MIGRATION-REPORT.md          本文件:移植报告与验证记录
docs\INSTALL.md                   安装到 iPhone 的路线
tools\verify_port.py              工程完整性检查(验收脚本)
tools\check_refs.py               引用与注入检查(验收脚本)
```

## 架构映射

| Android | iOS | 文件 |
|---|---|---|
| 7 个 Activity(Fragment 无) | SwiftUI View + NavigationStack | `App/`, `UI/` |
| SharedPreferences | UserDefaults(`Settings`) | `Store/Settings.swift` |
| EncryptedSharedPreferences | Keychain(`SecureStore`) | `Store/SecureStore.swift` |
| `Lock` 实体 + `Set<String>` 仓库 | `Lock` 结构体 + JSON 串数组 | `Model/Lock.swift`, `Store/LockStore.swift` |
| OkHttp/`HttpClient4` | `URLSession`(`URLSessionHTTPClient`) | `Net/HTTPClient.swift` |
| `YunmeiAPI` | 同名类,MD5 密码、三 token 头 | `Net/YunmeiAPI.swift` |
| `MD5Utils.stringToMD5` | 纯 Swift MD5(无 CryptoKit) | `Net/MD5.swift` |
| FastBle 扫描/连接/写 | `CBCentralManager` + `CBPeripheral` | `Ble/BleUnlockService.swift` |
| `UnlockService.getPwd` 帧 | `UnlockFrame.payload` 逐字节同构 | `Ble/UnlockFrame.swift` |
| `NfcActivity`(NDEF 读写) | `NFCNDEFReaderSession` | `NFC/NFCService.swift` |
| ZXing 扫码/生成 | AVFoundation + CoreImage | `QR/` |
| `LocationManager` | `CLLocationManager` | `Location/LocationProvider.swift` |
| `CircleProgress` 自绘 | SwiftUI `Circle().trim` | `UI/MainView.swift` |

## 协议还原(与安卓逐字节一致)

开锁帧 `getPwd(D_SEC)`:

```
D0 | (len(secret)+14)&0xFF | secret 的 UTF-8 字节 | A5 | 6 字节随机数(个位在前) | 49 44 30 31 A7
```

自检向量(已写进 `UnlockFrameTests`):

| secret | nonce | 期望字节 |
|---|---|---|
| `abc` | 123456789 | `D0 11 61 62 63 A5 09 08 07 06 05 04 49 44 30 31 A7` |
| 空串 | 0 | `D0 0E A5 00 00 00 00 00 00 49 44 30 31 A7` |

门锁串:`label|mac|char|serv|secret|1.1` → Base64 → `yunmeiui://lock_info/<b64>`(secret 为空用 `lock_id/`),兼容旧 4 段并补 `account`——与 `Lock.toString()`/`Lock(String)` 完全同构。

服务端:`https://base.yunmeitech.com/`,`POST /login`(userPwd=md5)、`/userschool/getbyuserid`、`/dormuser/getuserlock`、`/signrecord/signbyschool`,请求头 `token_data`/`token_userId`/`tokenUserId`。

## 与安卓的差异(不可绕过的平台限制)

1. **MAC 识别不可用**:iOS 不暴露外设 MAC,改为 `D_SERV` 过滤 + `CBPeripheral.identifier` 缓存(存 UserDefaults,快速连接直接 `retrievePeripherals`)。`Lock.mac` 仅遗留字段。
2. **NFC 不能静默开锁**:安卓前台 dispatch 收到标签直接开锁;iOS 必须由用户在 App 内发起会话。因此"贴标签开门"做成主页按钮。
3. **NFC 需要付费开发者账号 + NFC Tag Reading 能力**,模拟器不支持。
4. **自动退出**:iOS 不允许程序自杀,`autoExit` 仅保留开关,不执行退出。
5. **打卡定位**:一次性定位,不持续订阅。

## 验证记录(本机可复现)

| 检查 | 命令 | 结果 |
|---|---|---|
| 文件齐全 + Info.plist 合法 + 仅系统框架 + 契约类型存在 + 核心两文件未被改动 | `python tools/verify_port.py ios` | 0 problems |
| 视图/状态层引用的成员是否真实声明 + EnvironmentObject 注入完整 + 无重复类型 + 括号平衡 | `python tools/check_refs.py ios` | 0 problems |
| 协议向量 | `UnlockFrameTests`(需 Mac 运行) | 未执行(无 Swift 运行时) |

## 2026-10 真实编译/真机实测（后续补齐）

- **编译**：GitHub Actions `macos-15`（Xcode 16.4 / iOS 18.5 SDK）：模拟器 build 通过、XCTest **12/12 通过**、真机 Release（未签名）构建通过。工作流见 `.github/workflows/ios-unsigned-ipa.yml`。
- **安装**：未签名 ipa 经 Sideloadly + 免费 Apple ID 装入 iPhone（iOS 27.0.1）；免费签名 7 天有效，Sideloadly Daemon 自动续签已实测生效（2026-10-25 收到 “App refreshed” 通知，续签记录 0 失败）。
- **实测功能**：登录、学校/门锁列表、BLE 开锁、打卡均成功；NFC 因免费账号无 entitlement 未启用（入口置灰，符合预期）。
- **服务器接口实际格式与 §1/§2 记录不一致**：生产 `/userschool/getbyuserid` 返回的是**平铺**数组元素（`id`、`isDel`、`userId`、`schoolNo`、`isAdmin`、`token` 等），不再包含嵌套 `school` 对象；`schoolName` 也可能只出现在 JWT 声明里，`serverUrl` 可能缺失。iOS 端 `YunmeiAPI.schools` 已改为同时兼容平铺与嵌套两种格式，`serverUrl` 缺失时回退基址 `https://base.yunmeitech.com/`（实测该基址可直接提供 `/dormuser/getuserlock` 与打卡接口）。
- **维护提示**：服务端若再次调整字段，优先修改 `ios/YunmeiLock/Net/YunmeiAPI.swift` 的 `schools`/`locks` 解析；红线文件 `Lock.swift`、`UnlockFrame.swift`、`UnlockFrameTests.swift` 不要动。

## 协作说明

本次用了 codex 子智能体(`subagent_codex`),它独立产出并覆盖了 `Net/HTTPClient.swift`、`Net/YunmeiAPI.swift`、`Net/MD5.swift`、`Store/LockStore.swift`、`Store/Settings.swift`、`Ble/BleUnlockService.swift`、`NFC/NFCService.swift` 及部分 UI,风格为你要求的紧凑无注释写法。

它写得好的部分我保留了:Keychain 存会话/学校 URL、快速连接用 identifier 缓存、按 MTU 分包、失败自动降级重试、密码只进 Keychain。

但它与我自己写的状态层/视图层出现了接口分叉(缺 `onFinish`/`deviceIdentifier`/`stage.title`、`NFCService` 不是 `ObservableObject`、`Settings` 缺 `userId`/`isLoggedIn`/`clearAccount`、`LockStore` 缺 `defaultLock`/`setMac`),这些分叉全部由我合并修正,否则编译必炸。

## 下一步(在 Mac 上)

```bash
cd ios
brew install xcodegen
./scripts/build-macos.sh test     # 先跑单测,验证 MD5/帧/序列化
./scripts/build-macos.sh          # 再编译 App
open YunmeiLock.xcodeproj         # 填 Team 后真机运行
```

真机验证顺序建议:登录能拿到学校 → 能拉出门锁 → 靠近门锁点开锁(看进度环走到「开门完成」)→ 二维码分享 → NFC 写标签 → 打卡。
