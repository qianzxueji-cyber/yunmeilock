import XCTest
@testable import YunmeiLock

final class UnlockFrameTests: XCTestCase {
    func testKnownVectorAscii() {
        let got = UnlockFrame.payload(secret: "abc", nonce: 123456789)
        let want: [UInt8] = [0xD0, 0x11, 0x61, 0x62, 0x63, 0xA5, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x49, 0x44, 0x30, 0x31, 0xA7]
        XCTAssertEqual(got, want)
        XCTAssertEqual(UnlockFrame.hex(got), "D0 11 61 62 63 A5 09 08 07 06 05 04 49 44 30 31 A7")
    }

    func testEmptySecret() {
        let got = UnlockFrame.payload(secret: "", nonce: 0)
        XCTAssertEqual(got, [0xD0, 0x0E, 0xA5, 0, 0, 0, 0, 0, 0, 0x49, 0x44, 0x30, 0x31, 0xA7])
    }

    func testUuidSecret() {
        let secret = "0000fff2-0000-1000-8000-00805f9b34fb"
        let got = UnlockFrame.payload(secret: secret, nonce: 987654321)
        XCTAssertEqual(got.count, 50)
        XCTAssertEqual(got[0], 0xD0)
        XCTAssertEqual(got[1], 0x32)
        XCTAssertEqual(Array(got[2..<(2 + secret.utf8.count)]), Array(secret.utf8))
        XCTAssertEqual(got[2 + secret.utf8.count], 0xA5)
        XCTAssertEqual(Array(got.suffix(5)), [0x49, 0x44, 0x30, 0x31, 0xA7])
    }

    func testLengthUsesUTF16Count() {
        let got = UnlockFrame.payload(secret: "密钥", nonce: 1)
        XCTAssertEqual(got[1], 16)
        XCTAssertEqual(got.count, 1 + 1 + 6 + 1 + 6 + 5)
    }

    func testNonceDigitsLittleEndian() {
        let got = UnlockFrame.payload(secret: "x", nonce: 120345)
        XCTAssertEqual(Array(got[4..<10]), [5, 4, 3, 0, 2, 1])
    }

    func testRandomNonceInRange() {
        for _ in 0..<50 {
            let got = UnlockFrame.payload(secret: "x")
            XCTAssertEqual(got[0], 0xD0)
            XCTAssertEqual(Array(got.suffix(5)), [0x49, 0x44, 0x30, 0x31, 0xA7])
            XCTAssertTrue(got[4..<10].allSatisfy { $0 < 10 })
        }
    }
}
