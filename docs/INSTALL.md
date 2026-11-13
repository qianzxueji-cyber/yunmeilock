# 怎么把它装到 iPhone 上

先说结论:**Windows 上没法直接编译/安装 iOS 应用**。iOS 的签名和打包只能在 macOS 上完成。下面三条路,按你的条件选一条。

---

## 路线 A(推荐,不用买 Mac):GitHub Actions 出未签名 ipa + Windows 侧载

原理:GitHub 免费提供 macOS 机器,把工程编成**未签名 ipa**,下载到 Windows,再用侧载工具用你自己的 Apple ID 签名后装进 iPhone。

### A1. 让 GitHub 编出 ipa

1. 把本仓库整个目录推到一个 GitHub 仓库(私有仓库也行,免费):
   ```bash
   cd <仓库根目录>
   git init
   git add .
   git commit -m "ios port"
   git remote add origin https://github.com/<你的账号>/yunmeilock-ios.git
   git push -u origin main
   ```
   注意:仓库根目录必须是包含 `ios/` 的那一层(即 `ios-port` 里直接有 `ios/` 和 `.github/`)。

2. 打开仓库 → **Actions** → 左侧 `ios-unsigned-ipa` → 右侧 **Run workflow**。
3. 等 5~10 分钟变绿,进入该次运行,页底 **Artifacts** 下载 `YunmeiLock-unsigned-ipa.zip`,解压得到 `YunmeiLock-unsigned.ipa`。

### A2. Windows 上侧载

1. 装 **iTunes**(或仅装 Apple 驱动)和 **Sideloadly**(sideloadly.io)。
2. iPhone 用数据线连电脑,手机上点「信任此电脑」。
3. 打开 Sideloadly:
   - **IPA** 选刚下载的 `YunmeiLock-unsigned.ipa`
   - **Apple ID** 填你的 Apple ID(免费账号即可)
   - 点 **Start**,按提示输入 Apple ID 密码(如开了双重认证,会要专用密码)
4. 装完后手机上:设置 → 通用 → VPN与设备管理 → 开发者应用 → **信任** 你的 Apple ID。
5. 桌面上出现「云美门锁」,点开即可。

### A3. 免费 Apple ID 的限制(必须知道)

| 项 | 免费账号 | 付费开发者账号(¥688/年) |
|---|---|---|
| 签名有效期 | **7 天**,过期要重新侧载 | 1 年 |
| 同时可装 App | 3 个 | 100 个 |
| **NFC 读写** | **不可用**(entitlements 申请不到) | 可用 |
| 蓝牙/定位/拍照 | 可用 | 可用 |

也就是说:**免费账号能测登录、门锁列表、蓝牙开锁、二维码、打卡,但「写 NFC 标签 / 贴标签开门」用不了**;要用 NFC 必须付费开发者账号,并在 Xcode 里给 App ID 勾上 NFC Tag Reading。

---

## 路线 B(有 Mac 或 Mac 虚拟机):Xcode 直接装

```bash
cd ios
brew install xcodegen
xcodegen generate
open YunmeiLock.xcodeproj
```

在 Xcode 里:
1. 左侧选中 `YunmeiLock` target → **Signing & Capabilities**
2. **Team** 选你的 Apple ID(免费账号选 Personal Team)
3. **Bundle Identifier** 改成全局唯一的,如 `com.你的名字.yunmeilock`(`cc.xypp.yunmeilock` 已被原开发者占用)
4. 要测 NFC:点 **+ Capability** → 加 **Near Field Communication Tag Reading**(付费账号才有)
5. 顶部设备选你的 iPhone(不是模拟器;模拟器没有蓝牙/NFC)→ **Run**(⌘R)
6. 首次运行手机会提示「不受信任的开发者」,去 设置 → 通用 → VPN与设备管理 里信任

命令行版(只想先验证能编译):

```bash
cd ios
./scripts/build-macos.sh test    # 跑单测:MD5、开锁帧、门锁串序列化
./scripts/build-macos.sh         # 出未签名构建
```

---

## 路线 C:租云 Mac(不想折腾 GitHub,也不想买 Mac)

- MacinCloud / MacStadium 之类,按小时或按月租,远程桌面进去走**路线 B** 的步骤。
- 优点:能直接连你 iPhone 吗?**不能**——云 Mac 无法 USB 连你的手机,只能编出 ipa 后再回到**路线 A2** 用 Sideloadly 装。
- 所以云 Mac 只解决"编译",不解决"装进手机";装进手机要么 USB 侧载,要么 TestFlight(需要付费开发者账号 + App Store Connect 上传)。

---

## 常见坑

1. **`xcodegen generate` 报错找不到 project.yml** → 必须在 `ios/` 目录里执行。
2. **编译报 `Signing for "YunmeiLock" requires a development team`** → 路线 A 的 workflow 已经加了 `CODE_SIGNING_ALLOWED=NO`,不用管;路线 B 必须选 Team。
3. **Sideloadly 报 `Provision.cpp:150` / 无法写入** → 手机没信任电脑、iTunes 没装好,或 Apple ID 开了双重认证没填专用密码。
4. **装上闪退** → 大概率是 `Info.plist` 里缺某个用途描述,或 entitlement 与签名不匹配(免费账号签了带 NFC 的包就会闪退,把 NFC 能力去掉再签)。
5. **模拟器里开锁一直转圈** → 正常,模拟器没有 CoreBluetooth 外设,必须真机。
6. **7 天后打不开** → 免费签名到期,重新走一遍 A2 的 Sideloadly 步骤即可(数据会保留)。

---

## 最短路径速查

| 你手上有什么 | 走哪条 | 能不能用 NFC |
|---|---|---|
| 只有 Windows | A(GitHub Actions + Sideloadly) | 免费账号不行 |
| Windows + 付费开发者账号 | A,并在 Xcode/App ID 开 NFC 能力 | 行 |
| 有 Mac | B | 看账号类型 |
| 什么都没有,只想看界面 | 云 Mac 跑模拟器 | 不行 |
