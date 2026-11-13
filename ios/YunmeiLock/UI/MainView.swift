import SwiftUI
import Foundation
import CoreNFC

struct MainView: View {
    @EnvironmentObject private var settings:Settings
    @EnvironmentObject private var store:LockStore
    @EnvironmentObject private var ble:BleUnlockService
    @Binding var selectedLabel:String
    @State private var location=LocationProvider()
    @State private var signing=false
    @State private var signStatus=""
    @State private var askLocation=false
    @State private var message=""
    @State private var showMessage=false
    @State private var nfc=NFCService()
    private var selected:Lock? { store.locks.first { $0.label == selectedLabel } }
    private var unlocking:Bool {
        switch ble.stage {
        case .requesting,.scanning,.found,.connected,.writing: return true
        case .failed(let text): return text == "快速连接失败，使用常规模式尝试"
        default: return false
        }
    }
    private var status:String {
        switch ble.stage {
        case .idle: return selected?.label ?? "未添加门锁"
        case .requesting,.scanning: return "开锁"
        case .found: return "设备已找到"
        case .connected: return "连接成功"
        case .writing: return "开锁"
        case .done: return settings.autoExit ? "开门完成，程序将自动退出" : "开门完成"
        case .failed(let text): return text
        }
    }
    var body: some View {
        VStack(spacing:24) {
            Group {
                if store.locks.isEmpty { Text("无门锁") }
                else {
                    Picker("门锁",selection:$selectedLabel) {
                        ForEach(store.locks) { lock in Text(lock.label+(store.defaultLabel == lock.label ? "【默认门锁】" : "")).tag(lock.label) }
                    }.pickerStyle(.menu).disabled(unlocking || signing)
                }
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.15),lineWidth:14)
                    Circle().trim(from:0,to:min(1,max(0,ble.progress))).stroke(Color.accentColor,style:StrokeStyle(lineWidth:14,lineCap:.round)).rotationEffect(.degrees(-90))
                    Button("开锁") {
                        if let lock=selected { ble.unlock(lock:lock,quickConnect:settings.autoCon) }
                    }.font(.largeTitle.bold()).disabled(selected == nil || unlocking || signing)
                }.frame(width:220,height:220).padding(.top,12)
            }
            Text(status).multilineTextAlignment(.center).accessibilityLabel(status)
            if unlocking { Button("放弃") { ble.cancel() } }
            Toggle("快速连接",isOn:$settings.autoCon)
            Button("打卡") {
                if settings.sigLoc == "ask" { askLocation=true }
                else { Task { await sign(useLast:settings.sigLoc == "last") } }
            }.buttonStyle(.borderedProminent).disabled(selected == nil || unlocking || signing)
            Button("贴标签开门") { nfc.read { resolveTag($0) } }
                .disabled(unlocking || signing || !NFCNDEFReaderSession.readingAvailable)
            if signing { ProgressView(signStatus) }
            if let lock=selected { NavigationLink("门锁信息") { LockInfoView(lock:lock) } }
            Spacer()
            HStack {
                NavigationLink("登录") { LoginView() }
                Spacer()
                NavigationLink("添加门锁") { AddLockView() }
                Spacer()
                NavigationLink("设置") { SettingsView() }
            }.disabled(unlocking || signing)
        }
        .padding().navigationTitle("云美门锁")
        .onAppear { synchronize() }
        .onChange(of:store.locks) { _ in synchronize() }
        .onChange(of:selectedLabel) { _ in updateContext() }
        .alert("打卡位置询问",isPresented:$askLocation) {
            Button("确定") { Task { await sign(useLast:false) } }
            Button("打卡") { Task { await sign(useLast:true) } }
            Button("放弃",role:.cancel) {}
        } message: { Text(settings.lstLoca.isEmpty ? "上次定位信息不存在，请重新定位" : settings.lstLoca) }
        .alert(message,isPresented:$showMessage) { Button("确定",role:.cancel) {} }
    }
    private func synchronize() {
        if selected == nil { selectedLabel=store.defaultLabel ?? store.locks.first?.label ?? "" }
        updateContext()
    }
    private func updateContext() {
        guard let lock=selected else { settings.schoolNo=""; settings.lockNo=""; return }
        let key=MD5.hex(lock.serialized)
        settings.schoolNo=SecureStore().get("lock.school.\(key)") ?? ""
        settings.lockNo=SecureStore().get("lock.number.\(key)") ?? ""
    }
    @MainActor private func sign(useLast:Bool) async {
        guard !signing else { return }
        guard selected != nil,!settings.schoolNo.isEmpty,!settings.lockNo.isEmpty else { report("打卡时出错！"); return }
        let schoolNo=settings.schoolNo,lockNo=settings.lockNo
        signing=true; signStatus="正在定位"
        defer { signing=false }
        do {
            let coordinates:String
            if useLast {
                let parts=settings.lstLoca.split(separator:",")
                guard parts.count == 2,let latitude=Double(String(parts[0])),let longitude=Double(String(parts[1])),latitude.isFinite,longitude.isFinite,(-90...90).contains(latitude),(-180...180).contains(longitude) else { throw AppError.message("上次定位信息不存在，请重新定位") }
                coordinates=settings.lstLoca
            } else {
                let point=try await location.requestOnce()
                coordinates="\(point.lat),\(point.lng)"; settings.lstLoca=coordinates
            }
            signStatus="定位完成"
            let response=try await YunmeiAPI().sign(schoolNo:schoolNo,lockNo:lockNo,location:coordinates)
            report(response.msg.isEmpty ? (response.ok ? "打卡" : "打卡时出错！") : response.msg)
        } catch { report(error.localizedDescription) }
    }
    private func resolveTag(_ text:String) {
        DispatchQueue.main.async {
            guard let parsed=Lock(deepLink:text),parsed.servUuid != nil,parsed.charUuid != nil else { report("未找到门锁"); return }
            let matches=store.locks.filter { $0.servUuid == parsed.servUuid && $0.charUuid == parsed.charUuid }
            let target=matches.first(where:{ $0.label == parsed.label }) ?? (matches.count == 1 ? matches[0] : nil)
            guard let lock=target else { report("未找到门锁"); return }
            selectedLabel=lock.label
            updateContext()
            ble.unlock(lock:lock,quickConnect:settings.autoCon)
        }
    }
    private func report(_ text:String) { message=text; showMessage=true }
}
