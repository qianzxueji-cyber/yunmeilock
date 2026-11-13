import Foundation

struct Lock: Codable, Hashable, Identifiable {
    var label: String = "未添加门锁"
    var mac: String = ""
    var charUUID: String = ""
    var servUUID: String = ""
    var secret: String = ""
    var dataVer: String = "1.1"

    var id: String { label }

    init() {}

    init(label: String, mac: String, charUUID: String, servUUID: String, secret: String) {
        self.label = label
        self.mac = mac
        self.charUUID = charUUID
        self.servUUID = servUUID
        self.secret = secret
    }

    static let scheme = "yunmeiui"
    static let prefixes = ["lock_info/", "lockInfo/", "lock_id/", "addlock/"]

    var serialized: String {
        [label, mac, charUUID, servUUID, secret, "1.1"].joined(separator: "|")
    }

    var deepLink: String {
        let b64 = Data(serialized.utf8).base64EncodedString()
        return secret.isEmpty ? "yunmeiui://lock_id/\(b64)" : "yunmeiui://lock_info/\(b64)"
    }

    init?(deepLink raw: String) {
        var payload = raw
        for p in Lock.prefixes where raw.contains(p) {
            if let r = raw.range(of: p) {
                payload = String(raw[r.upperBound...])
                break
            }
        }
        guard let data = Lock.decodeBase64(payload), let text = String(data: data, encoding: .utf8) else { return nil }
        var parts = text.components(separatedBy: "|")
        if parts.count == 4 { parts.insert("account", at: 0) }
        guard parts.count >= 5 else { return nil }
        self.label = parts[0]
        self.mac = parts[1]
        self.charUUID = parts[2]
        self.servUUID = parts[3]
        self.secret = parts[4]
        if parts.count > 5 { self.dataVer = parts[5] }
    }

    static func decodeBase64(_ s: String) -> Data? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = t.firstIndex(of: "%") { t = String(t[..<p]) }
        t = t.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)
    }

    var servUuid: UUID? { UUID(uuidString: servUUID) }
    var charUuid: UUID? { UUID(uuidString: charUUID) }
}
