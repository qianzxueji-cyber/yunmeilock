import SwiftUI

@main
struct YunmeiLockApp: App {
    @StateObject private var settings=Settings()
    @StateObject private var locks=LockStore()
    @StateObject private var ble=BleUnlockService()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(settings).environmentObject(locks).environmentObject(ble)
        }
    }
}
