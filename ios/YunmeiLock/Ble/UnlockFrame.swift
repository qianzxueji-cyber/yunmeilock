import Foundation

enum UnlockFrame {
    static let head: UInt8 = 0xD0
    static let mid: UInt8 = 0xA5
    static let tail: [UInt8] = [0x49, 0x44, 0x30, 0x31, 0xA7]

    static func payload(secret: String, nonce: Int) -> [UInt8] {
        var out: [UInt8] = [head]
        out.append(UInt8((secret.utf16.count + 14) & 0xFF))
        out.append(contentsOf: Array(secret.utf8))
        out.append(mid)
        var n = abs(nonce) % 1_000_000_000
        for _ in 0..<6 {
            out.append(UInt8(n % 10))
            n /= 10
        }
        out.append(contentsOf: tail)
        return out
    }

    static func payload(secret: String) -> [UInt8] {
        payload(secret: secret, nonce: Int.random(in: 0..<1_000_000_000))
    }

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
