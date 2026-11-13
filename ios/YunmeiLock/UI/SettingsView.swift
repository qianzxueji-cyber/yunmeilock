import SwiftUI
import Foundation

struct SettingsView: View {
    @EnvironmentObject private var settings:Settings
    @EnvironmentObject private var store:LockStore
    @EnvironmentObject private var ble:BleUnlockService
    @State private var scan=false
    @State private var scanned=""
    @State private var imported:Lock?
    @State private var danger=false
    @State private var dangerStep=1
    @State private var clear=false
    @State private var credentials=false
    @State private var invalid=false
    private var dangerTitle:String { dangerStep == 1 ? "危险操作提醒" : dangerStep == 2 ? "危险操作再次提醒" : "最后提醒" }
    private let warning="警告！您正在执行一项非常危险的操作！\n分享您的门锁信息这一行为是不可逆的，门锁的保密数据理论上会伴随一个账号从创建到注销，一旦数据被获取，将会是安全数据的永久性泄露。\n您只应该于您非常非常信任的人或者您自己的其他设备线下共享该信息。\n确定要执行该操作吗？"
    var body: some View {
        Form {
            Section {
                Toggle("快速连接",isOn:$settings.autoCon)
                Toggle("开门完成，程序将自动退出",isOn:$settings.autoExit)
                Picker("打卡",selection:$settings.sigLoc) {
                    Text("打卡位置询问").tag("ask")
                    Text("正在定位").tag("current")
                    Text("定位完成").tag("last")
                }
            }
            Section {
                NavigationLink("登录") { LoginView() }
                Button("扫码添加") { scanned=""; scan=true }
                Button("查看信息") { clear=false; dangerStep=1; danger=true }
                Button("清除信息",role:.destructive) { clear=true; dangerStep=1; danger=true }
                Link("关于",destination:URL(string:"https://yunmei.xypp.cc/")!)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented:$scan,onDismiss:decode) {
            NavigationStack {
                QRScannerView { code in scanned=code; scan=false }
                    .navigationTitle("扫码添加")
                    .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { scan=false } } }
            }
        }
        .sheet(item:$imported) { lock in NavigationStack { AddLockView(initialLock:lock) } }
        .sheet(isPresented:$credentials) {
            NavigationStack {
                Form {
                    Text(settings.loginUsr)
                    Text(settings.loginPsw).privacySensitive()
                    Text(settings.schoolNo)
                    Text(settings.lockNo)
                }
                .navigationTitle("查看信息")
                .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { credentials=false } } }
            }
        }
        .alert("未知错误",isPresented:$invalid) { Button("确定",role:.cancel) {} }
        .alert(dangerTitle,isPresented:$danger) {
            Button("放弃",role:.cancel) { dangerStep=1 }
            Button("确定") {
                if dangerStep<3 {
                    dangerStep+=1
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { danger=true }
                } else if clear { clearInfo() }
                else { credentials=true }
            }
        } message: { Text(warning) }
    }
    private func decode() {
        guard !scanned.isEmpty else { return }
        defer { scanned="" }
        guard let lock=Lock(deepLink:scanned.removingPercentEncoding ?? scanned),lock.servUuid != nil,lock.charUuid != nil,!lock.secret.isEmpty else { invalid=true; return }
        imported=lock
    }
    private func clearInfo() {
        ble.cancel()
        let secure=SecureStore()
        let locks=store.locks
        for lock in locks {
            let key=MD5.hex(lock.serialized)
            if let school=secure.get("lock.school.\(key)") { secure.set("school.url.\(school)",""); secure.set("school.token.\(school)","") }
            store.remove(label:lock.label)
        }
        secure.set("session.token",""); secure.set("session.userId","")
        settings.loginUsr=""; settings.loginPsw=""; settings.schoolNo=""; settings.lockNo=""
        settings.rel=""; settings.lst=""; settings.lstLoca=""
    }
}
