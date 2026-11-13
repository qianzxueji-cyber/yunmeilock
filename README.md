# YunmeiLock · 云莓智能（非官方 iOS 客户端）

> 校园宿舍「蓝牙门锁 + 打卡」App 的非官方 iOS 客户端 · SwiftUI · 无第三方依赖

*Unofficial iOS client for the Yunmei campus dormitory BLE door-lock service — SwiftUI, CoreBluetooth, CoreNFC, zero third-party dependencies.*

本项目用 SwiftUI + Apple 系统框架实现了云莓智能（Yunmei）校园门锁服务的常用功能：登录、学校/门锁列表、蓝牙开锁、二维码/NFC 分享、打卡。协议行为基于原 Android 客户端 `cc.xypp.yunmeiui` 2.0.1 的公开分析，并按 iOS 平台限制重新设计交互。

## 功能

| 功能 | 说明 |
|---|---|
| 账号登录 | 云莓账号登录（密码以 MD5 提交），会话保存至 Keychain |
| 学校 / 门锁列表 | 拉取所属学校与本人门锁，支持多学校选择、默认门锁标记 |
| 蓝牙开锁 | 按 Service UUID 扫描门锁，匹配 Characteristic 后写入开锁帧，进度环展示「搜索 → 连接 → 开门」 |
| 二维码分享 / 导入 | 门锁信息编码为 `yunmeiui://lock_info/<base64>`，分享前三次危险确认 |
| NFC 标签 | 写入 NDEF 文本记录；主页「贴标签开门」读取标签并按 UUID 匹配本地门锁 |
| 打卡 | GPS 定位 + 门锁编号上报，支持「每次询问 / 重新定位 / 用上次位置」三种策略 |
| 设置 | 快速连接、自动退出开关、打卡位置策略、清除本地信息 |

## 技术栈

- **UI**：SwiftUI（iOS 16.0+），无第三方运行时依赖
- **蓝牙**：CoreBluetooth（Service / Characteristic UUID 匹配，`CBPeripheral.identifier` 缓存快速连接）
- **NFC**：CoreNFC（NDEF 读写，需付费开发者账号）
- **二维码**：AVFoundation（扫描）+ CoreImage（生成）
- **定位**：CoreLocation（一次性定位）
- **存储**：Keychain（密码 / 密钥 / 会话）+ UserDefaults（设置）
- **MD5**：纯 Swift 实现（CryptoKit 不含 MD5）

## 构建

需要 macOS + Xcode 16+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
cd ios
xcodegen generate
xcodebuild -project YunmeiLock.xcodeproj -scheme YunmeiLock \
  -destination 'generic/platform=iOS Simulator' build
```

一键脚本（macOS）：

```bash
cd ios
bash scripts/build-macos.sh test   # 单元测试
bash scripts/build-macos.sh        # 未签名构建
bash scripts/build-macos.sh ipa    # 打包未签名 ipa
```

### CI：GitHub Actions

推送 `ios/**` 或 workflow 变更后，macOS-15 runner 自动执行：模拟器构建 → 单元测试（12/12）→ 真机 Release（不签名）→ 打包未签名 ipa 并上传 Artifact（保留 14 天）。

工作流：[.github/workflows/ios-unsigned-ipa.yml](.github/workflows/ios-unsigned-ipa.yml)

## 安装到 iPhone

本项目未上架 App Store，需侧载安装（如 [Sideloadly](https://sideloadly.io/)）：

1. 从 Actions Artifact 下载 `YunmeiLock-unsigned.ipa`（或自行构建）；
2. Sideloadly 拖入 ipa → 填自己的 Apple ID → Start；
3. iPhone：设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID。

> 免费 Apple ID 限制：签名 7 天有效、最多 3 个自签 App、**NFC 不可用**（需付费开发者账号）。
> 详细路线见 [docs/INSTALL.md](docs/INSTALL.md)。

## 目录结构

```
ios/
  project.yml               XcodeGen 工程描述（iOS 16+，无第三方依赖）
  YunmeiLock/               SwiftUI 源码：App / UI / Net / Ble / NFC / QR / Store / Model
  Tests/YunmeiLockTests/    纯逻辑单测：开锁帧 / 门锁串 / MD5
  scripts/build-macos.sh    一键 test / build / ipa
docs/
  PORT-SPEC.md              协议与接口说明
  MIGRATION-REPORT.md       移植报告、平台限制与验证记录
  INSTALL.md                安装到 iPhone 的路线
tools/
  verify_port.py            工程完整性检查
  check_refs.py             引用与注入检查
```

## 兼容性与已知限制

- 服务器学校列表实际返回**平铺字段**（`schoolNo` / `token` 在数组元素顶层）；代码同时兼容平铺与嵌套两种格式，`serverUrl` 缺失时回退基址。
- iOS 无法获取蓝牙外设 MAC：扫描按 Service UUID 过滤，缓存 `CBPeripheral.identifier` 做快速连接。
- NFC 不能静默开锁：后台贴标签不会自动拉起 App，需在 App 内主动发起「贴标签开门」会话。
- App 不能自行退出：iOS 禁止程序自杀，`autoExit` 仅保存设置，不执行退出。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/PORT-SPEC.md](docs/PORT-SPEC.md) | 协议、接口与页面说明 |
| [docs/MIGRATION-REPORT.md](docs/MIGRATION-REPORT.md) | 架构映射、平台限制、验证记录 |
| [docs/INSTALL.md](docs/INSTALL.md) | 安装到 iPhone（含纯 Windows 侧载路线） |

## 验证状态（2026-10）

| 项目 | 状态 |
|---|---|
| GitHub Actions（macos-15 / Xcode 16.4 / iOS 18.5 SDK） | ✅ 模拟器构建、真机 Release 构建通过 |
| 单元测试 | ✅ 12/12 通过 |
| 真机实测（iPhone，iOS 27.0.1，免费 Apple ID） | ✅ 登录、学校 / 门锁列表、BLE 开锁、打卡 |
| NFC 写标签 / 贴标签开门 | ⚠️ 未验证（免费账号无 NFC 权限） |

## 来源、隐私与免责

- **来源**：协议行为基于原 Android 客户端 `cc.xypp.yunmeiui` 2.0.1 的公开分析重写；参考了社区项目 [zxy19/yunmei_unintelligent](https://github.com/zxy19/yunmei_unintelligent)（MIT）。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- **隐私**：本项目不运营自有服务器、不收集遥测；账号密码仅用于向云莓服务认证，门锁密钥在运行时获取并存于本机 Keychain。详见 [PRIVACY.md](PRIVACY.md)。
- **免责**：非官方客户端，与云莓智能及其原厂无关；用户只能操作自己有权访问的账号和门锁，使用风险自负，请遵守学校与设备管理规定。

## License

[MIT](LICENSE)
