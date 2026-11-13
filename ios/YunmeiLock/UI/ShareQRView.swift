import SwiftUI
import CoreNFC

struct ShareQRView: View {
    let lock:Lock
    @Environment(\.dismiss) private var dismiss
    @State private var nfc=NFCService()
    var body: some View {
        VStack(spacing:24) {
            Text(lock.label).font(.headline)
            if let image=QRGenerator.image(lock.deepLink,size:900) {
                Image(uiImage:image).interpolation(.none).resizable().scaledToFit().padding().background(.white).accessibilityLabel(lock.label).privacySensitive()
            } else { Text("未知错误") }
            ShareLink("分享门锁",item:lock.deepLink)
            Button("写入 NFC") { nfc.write(lock:lock) }.disabled(!NFCNDEFReaderSession.readingAvailable)
            if !NFCNDEFReaderSession.readingAvailable { Text("标签不可写！") }
            Spacer()
        }
        .padding().navigationTitle("二维码")
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { dismiss() } } }
    }
}
