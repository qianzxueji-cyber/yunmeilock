import XCTest
@testable import YunmeiLock

final class LockTests: XCTestCase {
    func testSerializeAndParse() {
        let l = Lock(label: "1栋-101", mac: "AA:BB:CC:DD:EE:FF",
                     charUUID: "0000fff2-0000-1000-8000-00805f9b34fb",
                     servUUID: "0000fff0-0000-1000-8000-00805f9b34fb",
                     secret: "S3CRET")
        XCTAssertEqual(l.serialized, "1栋-101|AA:BB:CC:DD:EE:FF|0000fff2-0000-1000-8000-00805f9b34fb|0000fff0-0000-1000-8000-00805f9b34fb|S3CRET|1.1")
        XCTAssertTrue(l.deepLink.hasPrefix("yunmeiui://lock_info/"))
        let back = Lock(deepLink: l.deepLink)
        XCTAssertEqual(back?.label, l.label)
        XCTAssertEqual(back?.secret, l.secret)
        XCTAssertEqual(back?.servUUID, l.servUUID)
        XCTAssertEqual(back?.charUUID, l.charUUID)
    }

    func testEmptySecretUsesLockId() {
        let l = Lock(label: "A-1", mac: "", charUUID: "c", servUUID: "s", secret: "")
        XCTAssertTrue(l.deepLink.hasPrefix("yunmeiui://lock_id/"))
    }

    func testLegacyFourFieldFormat() {
        // 旧格式 4 段: mac|char|serv|secret(无 label、无 dataVer),解析时补 "account" 作为 label
        let raw = "AA:BB|CHAR|SERV|SEC"
        let b64 = Data(raw.utf8).base64EncodedString()
        let l = Lock(deepLink: "yunmeiui://lockInfo/\(b64)")
        XCTAssertEqual(l?.label, "account")
        XCTAssertEqual(l?.mac, "AA:BB")
        XCTAssertEqual(l?.charUUID, "CHAR")
        XCTAssertEqual(l?.servUUID, "SERV")
        XCTAssertEqual(l?.secret, "SEC")
    }

    func testAddLockPrefix() {
        let raw = "X-9|m|c|s|sec|1.1"
        let b64 = Data(raw.utf8).base64EncodedString()
        XCTAssertEqual(Lock(deepLink: "yunmeiui://addlock/\(b64)")?.label, "X-9")
    }

    func testRejectsGarbage() {
        XCTAssertNil(Lock(deepLink: "https://example.com/x"))
        XCTAssertNil(Lock(deepLink: "yunmeiui://lock_info/not-base64!!"))
    }
}

final class MD5Tests: XCTestCase {
    func testVectors() {
        XCTAssertEqual(MD5.hex(""), "d41d8cd98f00b204e9800998ecf8427e")
        XCTAssertEqual(MD5.hex("abc"), "900150983cd24fb0d6963f7d28e17f72")
        XCTAssertEqual(MD5.hex("message digest"), "f96b697d7cb7938d525a2f31aaf161d0")
        XCTAssertEqual(MD5.hex("abcdefghijklmnopqrstuvwxyz"), "c3fcd3d76192e4007dfb496cca67e13b")
        XCTAssertEqual(MD5.hex("123456"), "e10adc3949ba59abbe56e057f20f883e")
    }
}
