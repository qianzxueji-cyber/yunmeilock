import Foundation
import Combine
import CoreNFC

final class NFCService:NSObject,ObservableObject,NFCNDEFReaderSessionDelegate {
    @Published var message:String?
    @Published var finished=false

    private var session:NFCNDEFReaderSession?
    private var ndef:NFCNDEFMessage?
    private var onResult:((Bool,String)->Void)?
    private var onText:((String)->Void)?

    func write(lock:Lock) { write(lock:lock,onResult:nil) }
    func write(lock:Lock,onResult:((Bool,String)->Void)?) {
        guard session == nil else { return }
        self.onResult=onResult
        self.onText=nil
        guard NFCNDEFReaderSession.readingAvailable else { report(false,"当前设备不支持 NFC"); return }
        guard let record=NFCNDEFPayload.wellKnownTypeTextPayload(string:lock.deepLink,locale:Locale(identifier:"zh-CN")) else { report(false,"标签不可写！"); return }
        ndef=NFCNDEFMessage(records:[record])
        finished=false
        let reader=NFCNDEFReaderSession(delegate:self,queue:.main,invalidateAfterFirstRead:false)
        session=reader; reader.alertMessage="请将手机靠近门锁标签"; reader.begin()
    }

    func read(onText:@escaping (String)->Void) {
        self.onText=onText
        self.onResult=nil
        guard NFCNDEFReaderSession.readingAvailable else { report(false,"当前设备不支持 NFC"); return }
        ndef=nil
        let reader=NFCNDEFReaderSession(delegate:self,queue:.main,invalidateAfterFirstRead:false)
        session=reader; reader.alertMessage="请将手机靠近门锁标签"; reader.begin()
    }

    static func text(of payload:NFCNDEFPayload)->String? {
        if payload.typeNameFormat == .nfcWellKnown,payload.type == Data([0x54]) {
            let raw=payload.payload
            guard let status=raw.first else { return nil }
            let start=1+Int(status & 0x3F)
            guard raw.count>start else { return nil }
            return String(data:raw.subdata(in:start..<raw.count),encoding:.utf8)
        }
        return payload.wellKnownTypeURIPayload()?.absoluteString
    }

    private func report(_ ok:Bool,_ text:String) {
        DispatchQueue.main.async { [weak self] in
            self?.message=text
            self?.finished=true
            self?.onResult?(ok,text)
        }
    }

    func readerSession(_ session:NFCNDEFReaderSession,didDetectNDEFs messages:[NFCNDEFMessage]) {}

    func readerSession(_ session:NFCNDEFReaderSession,didInvalidateWithError error:Error) {
        guard self.session === session else { return }
        self.session=nil; ndef=nil
        if finished { return }
        let code=(error as? NFCReaderError)?.code
        if code == .readerSessionInvalidationErrorUserCanceled {
            report(false,"已取消")
        } else if code != .readerSessionInvalidationErrorFirstNDEFTagRead {
            report(false,error.localizedDescription)
        }
    }

    func readerSession(_ session:NFCNDEFReaderSession,didDetect tags:[NFCNDEFTag]) {
        guard self.session === session,let tag=tags.first,tags.count == 1 else { session.restartPolling(); return }
        session.connect(to:tag) { [weak self] error in
            guard let self=self else { return }
            guard error == nil else { self.fail(session); return }
            if let onText=self.onText {
                tag.readNDEF { message,error in
                    guard error == nil,let record=message?.records.first,let text=NFCService.text(of:record) else { self.fail(session); return }
                    self.onText=nil
                    DispatchQueue.main.async { onText(text) }
                    session.alertMessage="读取成功"
                    session.invalidate()
                }
                return
            }
            tag.queryNDEFStatus { status,capacity,error in
                guard error == nil,status == .readWrite,let ndef=self.ndef,capacity>=ndef.length else { self.fail(session); return }
                tag.writeNDEF(ndef) { error in
                    if error != nil { self.fail(session) }
                    else {
                        session.alertMessage="写入成功"
                        self.report(true,"写入成功")
                        session.invalidate()
                    }
                }
            }
        }
    }

    private func fail(_ session:NFCNDEFReaderSession) {
        DispatchQueue.main.async { [weak self] in
            session.invalidate(errorMessage:"标签不可写！")
            self?.message="标签不可写！"
            self?.finished=true
            self?.onResult?(false,"标签不可写！")
        }
    }
}
