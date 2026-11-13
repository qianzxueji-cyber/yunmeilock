import SwiftUI
import Foundation

struct RootView: View {
    @EnvironmentObject private var store:LockStore
    @EnvironmentObject private var settings:Settings
    @EnvironmentObject private var ble:BleUnlockService
    @State private var selectedLabel=""
    @State private var incoming:Lock?
    @State private var pendingUnlock:Lock?
    @State private var showUnlock=false
    @State private var showError=false
    var body: some View {
        NavigationStack { MainView(selectedLabel:$selectedLabel) }
            .onOpenURL { receive($0) }
            .sheet(item:$incoming) { lock in NavigationStack { AddLockView(initialLock:lock) } }
            .alert("开锁",isPresented:$showUnlock) {
                Button("放弃",role:.cancel) { pendingUnlock=nil }
                Button("确定") {
                    if let lock=pendingUnlock { selectedLabel=lock.label; ble.unlock(lock:lock,quickConnect:settings.autoCon) }
                    pendingUnlock=nil
                }
            } message: { Text(pendingUnlock?.label ?? "未添加门锁") }
            .alert("未知错误",isPresented:$showError) { Button("确定",role:.cancel) {} }
    }
    private func receive(_ url:URL) {
        guard url.scheme?.lowercased() == Lock.scheme,let lock=Lock(deepLink:url.absoluteString.removingPercentEncoding ?? url.absoluteString),lock.servUuid != nil,lock.charUuid != nil else { showError=true; return }
        if lock.secret.isEmpty {
            let matches=store.locks.filter { $0.servUuid == lock.servUuid && $0.charUuid == lock.charUuid && !$0.secret.isEmpty }
            if let exact=matches.first(where:{ $0.label == lock.label }) { pendingUnlock=exact }
            else if matches.count == 1 { pendingUnlock=matches[0] }
            else { showError=true; return }
            showUnlock=true
        } else { incoming=lock }
    }
}
