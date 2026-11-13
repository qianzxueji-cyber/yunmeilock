import Foundation
import Combine

final class LockStore: ObservableObject {
    private let secure=SecureStore()
    @Published var locks:[Lock] { didSet { persist() } }
    @Published private var defaultLink:String
    var defaultLabel:String? { Lock(deepLink:defaultLink)?.label }
    init() {
        let saved=secure.get("locks")
        let links=saved.flatMap { try? JSONDecoder().decode([String].self,from:Data($0.utf8)) } ?? UserDefaults.standard.stringArray(forKey:"locks") ?? []
        locks=links.compactMap { Lock(deepLink:$0) }.sorted { $0.label<$1.label }
        defaultLink=secure.get("lock_default") ?? UserDefaults.standard.string(forKey:"lock_default") ?? ""
        if !locks.contains(where:{ $0.label == Lock(deepLink:defaultLink)?.label }) { defaultLink="" }
        persist(); secure.set("lock_default",defaultLink)
        UserDefaults.standard.removeObject(forKey:"locks")
        UserDefaults.standard.removeObject(forKey:"lock_default")
    }
    func add(_ l:Lock) throws {
        guard !locks.contains(where:{ $0.label == l.label }) else { throw AppError.message("\(l.label) 已存在") }
        locks.append(l)
    }
    func remove(label:String) {
        let removed=locks.first { $0.label == label }
        locks.removeAll { $0.label == label }
        if defaultLabel == label { defaultLink=""; secure.set("lock_default","") }
        if let removed=removed {
            let key=MD5.hex(removed.serialized)
            secure.set("lock.school.\(key)",""); secure.set("lock.number.\(key)","")
        }
    }
    var defaultLock:Lock? { locks.first { $0.label == defaultLabel } }
    func setMac(_ l:Lock,mac:String) {
        guard let i=locks.firstIndex(where:{ $0.label == l.label }) else { return }
        var copy=locks[i]; copy.mac=mac; locks[i]=copy
    }
    func update(_ l:Lock) {
        guard let i=locks.firstIndex(where:{ $0.label == l.label }) else { return }
        locks[i]=l
    }
    func remove(_ l:Lock) { remove(label:l.label) }
    func setDefault(_ l:Lock) {
        guard locks.contains(where:{ $0.label == l.label }) else { return }
        defaultLink=l.deepLink; secure.set("lock_default",defaultLink)
    }
    private func persist() {
        guard let data=try? JSONEncoder().encode(locks.map(\.deepLink)),let value=String(data:data,encoding:.utf8) else { return }
        secure.set("locks",value)
    }
}
