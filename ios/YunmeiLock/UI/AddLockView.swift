import SwiftUI
import Foundation

struct AddLockView: View {
    @EnvironmentObject private var store:LockStore
    @Environment(\.dismiss) private var dismiss
    @State private var raw=""
    @State private var candidate:Lock?
    @State private var label=""
    @State private var scan=false
    @State private var message=""
    @State private var showMessage=false
    init(initialLock:Lock?=nil) {
        _candidate=State(initialValue:initialLock)
        _label=State(initialValue:initialLock?.label ?? "")
    }
    var body: some View {
        Form {
            Section("添加门锁") {
                TextField("门锁信息",text:$raw,axis:.vertical).textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                Button("获取门锁") { decode(raw) }
                Button("扫码添加") { scan=true }
                NavigationLink("登录") { LoginView() }
            }
            if let lock=candidate {
                Section {
                    TextField("门锁",text:$label)
                    Text(lock.servUUID).font(.caption).textSelection(.enabled)
                    Text(lock.charUUID).font(.caption).textSelection(.enabled)
                    Button("确定") { add() }
                    Button("删除",role:.destructive) { candidate=nil; raw=""; label="" }
                }
            }
        }
        .navigationTitle("添加门锁")
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { dismiss() } } }
        .sheet(isPresented:$scan) {
            NavigationStack {
                QRScannerView { code in scan=false; decode(code) }
                    .navigationTitle("扫码添加")
                    .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { scan=false } } }
            }
        }
        .alert(message,isPresented:$showMessage) { Button("确定",role:.cancel) {} }
    }
    private func decode(_ value:String) {
        guard let lock=Lock(deepLink:value.removingPercentEncoding ?? value),lock.servUuid != nil,lock.charUuid != nil,!lock.secret.isEmpty else { report("未知错误"); return }
        candidate=lock; label=lock.label
    }
    private func add() {
        guard var lock=candidate else { return }
        let name=label.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty,!name.contains("|"),!lock.secret.contains("|"),lock.servUuid != nil,lock.charUuid != nil,!lock.secret.isEmpty else { report("未知错误"); return }
        lock.label=name
        do {
            try store.add(lock)
            if store.defaultLabel == nil { store.setDefault(lock) }
            dismiss()
        } catch { report(error.localizedDescription) }
    }
    private func report(_ text:String) { message=text; showMessage=true }
}
