import SwiftUI
import Foundation
import CoreNFC

struct LockInfoView: View {
    let lock:Lock
    @EnvironmentObject private var store:LockStore
    @Environment(\.dismiss) private var dismiss
    @State private var delete=false
    @State private var danger=false
    @State private var dangerStep=1
    @State private var writeNFC=false
    @State private var showQR=false
    @State private var nfc=NFCService()
    private var dangerTitle:String { dangerStep == 1 ? "危险操作提醒" : dangerStep == 2 ? "危险操作再次提醒" : "最后提醒" }
    private let warning="警告！您正在执行一项非常危险的操作！\n分享您的门锁信息这一行为是不可逆的，门锁的保密数据理论上会伴随一个账号从创建到注销，一旦数据被获取，将会是安全数据的永久性泄露。\n您只应该于您非常非常信任的人或者您自己的其他设备线下共享该信息。\n确定要执行该操作吗？"
    var body: some View {
        Form {
            Section("门锁信息") {
                Text(lock.label)
                if store.defaultLabel == lock.label { Text("【默认门锁】") }
                Text(lock.servUUID).textSelection(.enabled)
                Text(lock.charUUID).textSelection(.enabled)
                if !lock.mac.isEmpty { Text(lock.mac).textSelection(.enabled) }
            }
            Section {
                Button("设为默认") { store.setDefault(lock) }
                Button("分享门锁") { writeNFC=false; dangerStep=1; danger=true }
                Button("写入 NFC") { writeNFC=true; dangerStep=1; danger=true }.disabled(!NFCNDEFReaderSession.readingAvailable)
                Button("删除门锁",role:.destructive) { delete=true }
            }
        }
        .navigationTitle("门锁信息")
        .alert("确认删除",isPresented:$delete) {
            Button("放弃",role:.cancel) {}
            Button("确定",role:.destructive) { store.remove(label:lock.label); dismiss() }
        } message: { Text(lock.label) }
        .alert(dangerTitle,isPresented:$danger) {
            Button("放弃",role:.cancel) { dangerStep=1 }
            Button("确定") {
                if dangerStep<3 {
                    dangerStep+=1
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { danger=true }
                } else if writeNFC { nfc.write(lock:lock) }
                else { showQR=true }
            }
        } message: { Text(warning) }
        .sheet(isPresented:$showQR) { NavigationStack { ShareQRView(lock:lock) } }
    }
}
