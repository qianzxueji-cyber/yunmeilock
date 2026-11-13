# YunmeiUI → iOS 移植规格书

来源样本:Android 应用 `cc.xypp.yunmeiui` 2.0.1(versionCode 8,compileSdk 31)
分析方法:AndroidManifest 二进制 XML 解析 + dex 类/字段/方法表 + 指令级反汇编(androguard 4.x)。
本文件里所有"事实"都来自样本;所有"推算"都标 `[推算]`。

## 0. 一句话

校园宿舍**蓝牙门锁**客户端:账号登录(密码 MD5)→ 选择学校 → 拉取本人门锁列表 → 靠近门锁用 BLE 写一段固定帧开门;支持门锁信息用 Base64 + deep link 分享(二维码 / NFC 标签),以及在门锁处**打卡**(GPS + lockNo 上报)。

## 1. 账号/会话

| 项 | 值 |
|---|---|
| 基址 | `https://base.yunmeitech.com/`(硬编码于 `YunmeiAPI`) |
| 关于页 | `https://yunmei.xypp.cc/` |
| 登录 | `POST /login` body `userName`,`userPwd`(= `MD5(明文密码)`) |
| 登录响应 | `{success:bool, o:{token:string, userId:string}, msg?:string}`;失败抛 `msg` |
| 学校列表 | `POST /userschool/getbyuserid` body `{userId}`,响应为 JSON 数组,元素 `{schoolNo, school:{schoolName, serverUrl, token}}` |
| 门锁列表 | `POST /dormuser/getuserlock` body `{schoolNo, userId}`,响应为 JSON 数组 |
| 打卡 | `POST /signrecord/signbyschool` body `{schoolNo, lockNo, location}` → `{success, msg}` |
| 请求头 | `token_data: <token>`,`token_userId: <userId>`,`tokenUserId: <userId>`(三者同时带;代码里 `tokenUserId` 与 `token_userId` 各写一次) |
| 学校切换 | `setSchool(i)` 后把该学校的 `serverUrl` 设为 baseURL、`token` 设为 token |

门锁对象字段(JSON):`buildName`,`dormNo`,`lockSecret`,`lockCharacterUuid`,`lockServiceUuid`,`lockNo`。
映射到本地实体:`label = String.format("%s-%s", buildName, dormNo)`,`D_SEC = lockSecret`,`D_CHAR = lockCharacterUuid`,`D_SERV = lockServiceUuid`,`lockNo` 存进设置。

> **2026-10 生产实测差异**（以实测为准）：`/userschool/getbyuserid` 实际返回的数组元素是**平铺字段**——`id`、`isDel`、`userId`、`schoolNo`、`isAdmin`、`token` 等，**不再包含嵌套 `school` 对象**；`schoolName` 也可能只出现在 JWT `token` 的声明里，`serverUrl` 可能缺失。iOS 实现已同时兼容平铺与嵌套两种格式（`YunmeiAPI.schools`），`serverUrl` 缺失时回退到基址 `https://base.yunmeitech.com/`。维护时不要假设响应一定是本文原先记录的嵌套结构。

**MD5**:`MD5Utils.stringToMD5(String)` → 标准 MD5 小写 32 位十六进制(`"md5"` / `"没有这个md5算法！"` 两条常量对应算法名与异常)。

## 2. 本地实体 Lock

字段:`label`,`D_Mac`,`D_CHAR`,`D_SERV`,`D_SEC`,`DATA_VER`。

序列化 `toString()`:
```
label + "|" + D_Mac + "|" + D_CHAR + "|" + D_SERV + "|" + D_SEC + "|" + "1.1"
```
→ Base64(标准,带 padding)→
- `D_SEC == ""` 时前缀 `yunmeiui://lock_id/`
- 否则前缀 `yunmeiui://lock_info/`

解析 `Lock(String)`(四条前缀都认,取最长匹配先判断):`addlock/`(偏移 +8)、`lock_id/`(+8)、`lock_info/`(+10)、`lockInfo/`(+9) → Base64 解码 → `split("\\|")`:
- 若切出 4 段:视为旧格式,前面补 `"account"` 成为 5 段
- 段数 ≥5 时:`[0]=label`,`[1]=D_Mac`,`[2]=D_CHAR`,`[3]=D_SERV`,`[4]=D_SEC`
- `DATA_VER` 不被解析(第 6 段"1.1"仅回写时使用)

默认构造:`label="未添加门锁"`,其余空串。

## 3. 本地存储键

`SharedPreferences("storage")` 明文 + `SecureStorage`(EncryptedSharedPreferences)两套:

| 键 | 类型 | 用途 |
|---|---|---|
| `loginUsr` | String | 用户名 |
| `loginPsw` | String | 密码(明文存,样本如此) |
| `schoolNo` | String | 当前学校号 |
| `lockNo` | String | 当前门锁号(打卡用) |
| `rel` | String | 上次登录标记 |
| `lst` | String | 上次登录标记 |
| `lstLoca` | String | 上次定位 `lat,lng` 字符串 |
| `autoCon` | Bool | 快速连接 |
| `autoExit` | Bool | 开门完成后自动退出 |
| `sigLoc` | String | 打卡位置策略(`"ask"` 等) |
| `locks` | Set<String> | 全部门锁(存 `Lock.toString()` 的 deep link 串) |
| `lock_default` | String | 默认门锁(同上) |

`LockManageUtil`:add 时若 `label` 重复则 `RuntimeException("%s 已存在")`;getAll 反序列化;getDef 空串→null;remove(label);setDef;setMac。

## 4. BLE 开锁(核心)

依赖 FastBle。iOS 侧映射到 CoreBluetooth。

流程:
1. `scan()`:请求定位权限 → `BleScanRuleConfig.setServiceUuids([UUID.fromString(D_SERV)])` → `scanAndConnect`
2. `onScanFinished(device)`:null → `setpss(0,"设备未找到",true)` + `end()`;否则 `setpss(40,"设备已找到")`
3. `onConnectSuccess`:`connectedDevice=device`;`sendMsg()`;`setpss(50,"连接成功")`
4. `onConnectFail`:`setpss(1,"连接失败",true)` + `end()`
5. `sendMsg()`:`BleManager.write(device, D_SERV, D_CHAR, getPwd(D_SEC), cb)`
6. `onWriteSuccess(current,total,data)`:若 `current == total` → `setpss(100,"开门完成")`;若 `!quickConnect` → `lock.D_Mac = device.getMac()`,保存门锁
7. `onWriteFailure`:`setpss(0,"开门失败",true)` + `end()`

`getPwd(String sec)` 逐字节:
```
0xD0
(byte)(sec.length() + 14)
sec.getBytes()                        // 逐字节原样
0xA5
6 个字节:随机数 n = floor(Math.random() * 1e9);循环 6 次 { write(n % 10); n /= 10 }
0x49 0x44 0x30 0x31 0xA7             // ASCII "ID01" + 0xA7
```
`[推算]` 长度字段只看 `sec.length()`(UTF-16 码元数),若密钥含非 ASCII 会与字节数不符;样本密钥为 UUID/ASCII,故等价。

快速连接失败重试:`quickConnect` 为真且连接失败时,`setpss(2,"快速连接失败，使用常规模式尝试")` 后置 `quickConnect=false` 重试 `scan()`。`[推算]` 依据 `UnlockService$2` 常量与 `access$302`。

Callback 语义(用于 UI 状态机):`start()` 开锁开始、`setpss(int,String)` 进度、`setpss(int,String,boolean)` 带"是否终态"、`end()` 结束。

## 5. NFC

`NfcActivity`:
- 写:把 `Lock.toString()`(即 `yunmeiui://...` 串)作为 **NDEF 文本记录**写入标签;标签不可写时 toast `"标签不可写！"`;非 NDEF 但可格式化时先 `formatTag`。
- 读:`ACTION_NDEF_DISCOVERED`,遍历 `NdefMessage.getRecords()`,取 TNF/type 匹配的文本记录 payload(UTF-8,跳过语言码前缀),若以 `yunmeiui://lock_id/` 开头则反序列化成 Lock,与本地列表比对(`Objects.equals` 两字段),命中后带 `Intent(action="cc.xypp.yunmeiui.unlock", data=Uri.parse(toString()))` 启动开锁。
- 启动:前台 `enableForegroundDispatch`,优先级高于系统分发。

## 6. 二维码

- 生成:`QRUtils.createQRCodeBitmap(str,w,h)`,`QrActivity` 把 `getIntent().getDataString()`(即 deep link 串)渲染成二维码。
- 扫描:设置页 `scanQR` 与添加门锁页,用 ZXing(`journeyapps` `CaptureActivity`)。
- 分享:锁详情 `shareLock` 弹出**危险操作**二次确认(见附录文案),确认后展示二维码/NFC 写入。

## 7. 页面与交互

| 页面 | 类 | 关键控件/动作 |
|---|---|---|
| 登录 | `loginActivity` | 用户名、密码、保存为默认勾选、「登录」、「获取门锁」;多学校时弹「选择要添加门锁的学校」;无学校 → 「账号不属于任何一所学校，请检查后重新添加」 |
| 主页 | `MainActivity` | 门锁下拉(spinner)、大号「开锁」按钮 `btn_unlock`、圆形进度 `circleProgress`、`config_quickConnect`;动作 `openDoorClick/openDoorPss`、`clickSign/signPss`、`loginClick`、`settingClick`;`reloadLocks`;双击返回退出(`exitOnce`) |
| 锁详情 | `lockInfoActivity` | `showLock`、`setDefault`(显示「【默认门锁】」)、`deleteLock`(「确认删除」)、`shareLock`、`createNFC` |
| 添加门锁 | `addLockActivity` | `getLockNameAuto`、扫码添加、`delete`、`close`;字段 `locksList`/`toAdd` |
| 设置 | `settingActivity` | `autoCon`/`autoExit`/`sigLoc` 开关、`scanQR`、`clickCheckInfo`、`clickClearInfo`、`ClickSigLoc`、`about`;危险操作二次/三次确认(`checkDanger`、`alertAgain`、`alertLast`) |
| NFC | `NfcActivity` | 见 §5 |
| 二维码 | `QrActivity` | 见 §6 |

权限(Android):NFC、BLUETOOTH(_ADMIN/_CONNECT/_SCAN)、ACCESS_COARSE/FINE_LOCATION、INTERNET、CAMERA。

## 8. iOS 映射与硬约束

| Android | iOS | 说明 |
|---|---|---|
| FastBle `scanAndConnect` 按 service UUID | `CBCentralManager.scanForPeripherals(withServices:[D_SERV])` | Service UUID 过滤可直接搬 |
| 按 `D_Mac` 识别设备 | **不可用** | iOS 不暴露外设 MAC,也不允许按 MAC 扫描。识别一律用 Service UUID + 后续可选的 `CBPeripheral.identifier` 持久化 |
| `write(service, char, bytes)` | `CBPeripheral.writeValue(_:for:type:.withResponse)` | `D_CHAR` 需在发现后按 UUID 匹配;`current==total` → `didWriteValueFor` 即完成 |
| EncryptedSharedPreferences | Keychain(`kSecClassGenericPassword`) | 密码/密钥落地到 Keychain |
| SharedPreferences | `UserDefaults` | 开关类设置 |
| `LocationManager` | `CLLocationManager` | 打卡取经纬度 |
| NDEF 读写 | `CoreNFC` `NFCNDEFReaderSession` / `NFCNDEFTag.write` | 写入需要 App ID 带 NFC Tag Reading 能力,真机 + 付费开发者账号 |
| `yunmeiui://` deep link | `CFBundleURLSchemes` 注册同名 scheme | NFC/扫码拉起同一 scheme |
| ZXing 扫描 | `AVCaptureSession` + `AVMetadataObject.ObjectType.qr` | |
| ZXing 生成 | `CIFilter.qrCodeGenerator()` | |
| `CircleProgress` | SwiftUI `Circle().trim(to:)` | |

必须如实告知的限制:
1. iOS 无法读取外设 MAC,`D_Mac` 字段在 iOS 端仅作遗留字段保留(读写不影响开锁)。
2. 后台/锁屏直接贴 NFC 标签自动开锁:iOS 需要用户解锁设备并确认,不能像 Android 那样静默 `startActivity`。NFC 只能弱化为"贴标签 → 系统提示 → 打开 App 对应锁"。
3. 无 Mac/Xcode 环境无法本地编译;交付物是可 `xcodegen generate` 的源码工程 + 构建说明。

## 9. 附录:原文案(照抄,勿翻译)

- 「未添加门锁」「【默认门锁】」「确认删除」「无门锁」「当前账号不存在任何门锁」
- 「您拒绝了权限请求」「连接失败」「设备未找到」「设备已找到」「连接成功」「开门失败」「开门完成」「开门完成，程序将自动退出」
- 「快速连接失败，使用常规模式尝试」「标签不可写！」
- 「账号不属于任何一所学校，请检查后重新添加」「发生了未知错误，请尝试重新提交」「门锁获取失败」「未知错误」
- 「警告！您正在执行一项非常危险的操作！\n分享您的门锁信息这一行为是不可逆的，门锁的保密数据理论上会伴随一个账号从创建到注销，一旦数据被获取，将会是安全数据的永久性泄露。\n您只应该于您非常非常信任的人或者您自己的其他设备线下共享该信息。\n确定要执行该操作吗？」
- 「危险操作提醒」「危险操作再次提醒」「最后提醒」「放弃」「确定」
- 「打卡」「正在定位」「定位完成」「定位服务不可用」「上次定位信息不存在，请重新定位」「打卡位置询问」「打卡时出错！」
