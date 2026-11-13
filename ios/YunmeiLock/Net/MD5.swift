import Foundation

enum MD5 {
    static func hex(_ s:String) -> String {
        var bytes=Array(s.utf8)
        let bitCount=UInt64(bytes.count)&*8
        bytes.append(0x80)
        while bytes.count%64 != 56 { bytes.append(0) }
        for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:bitCount>>shift)) }
        let rotations:[UInt32]=[7,12,17,22,5,9,14,20,4,11,16,23,6,10,15,21]
        let constants:[UInt32]=[
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
            0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
            0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
            0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
            0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
            0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
        ]
        var state:[UInt32]=[0x67452301,0xefcdab89,0x98badcfe,0x10325476]
        for offset in stride(from:0,to:bytes.count,by:64) {
            var words=[UInt32](repeating:0,count:16)
            for index in 0..<16 {
                for byte in 0..<4 { words[index] |= UInt32(bytes[offset+index*4+byte])<<(byte*8) }
            }
            var first=state[0],second=state[1],third=state[2],fourth=state[3]
            for index in 0..<64 {
                let mixed:UInt32
                let wordIndex:Int
                switch index {
                case 0..<16: mixed=(second&third)|(~second&fourth); wordIndex=index
                case 16..<32: mixed=(fourth&second)|(~fourth&third); wordIndex=(5*index+1)%16
                case 32..<48: mixed=second^third^fourth; wordIndex=(3*index+5)%16
                default: mixed=third^(second|(~fourth)); wordIndex=(7*index)%16
                }
                let sum=first&+mixed&+constants[index]&+words[wordIndex]
                let shift=rotations[(index/16)*4+index%4]
                let rotated=(sum<<shift)|(sum>>(32-shift))
                first=fourth; fourth=third; third=second; second=second&+rotated
            }
            state[0]=state[0]&+first; state[1]=state[1]&+second
            state[2]=state[2]&+third; state[3]=state[3]&+fourth
        }
        return state.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded:word>>($0*8)) } }.map { String(format:"%02x",$0) }.joined()
    }
}
