import Foundation
import Security

final class SecureStore {
    private let service="cc.xypp.yunmeilock"
    func set(_ key:String,_ value:String) {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key]
        if value.isEmpty { SecItemDelete(query as CFDictionary); return }
        let attributes:[String:Any]=[kSecValueData as String:Data(value.utf8)]
        let status=SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item=query.merging(attributes) { _,new in new }
            item[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(item as CFDictionary,nil)
        }
    }
    func get(_ key:String) -> String? {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:key,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess,let data=result as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
}
