import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    var onCode:(String)->Void
    func makeUIViewController(context:Context) -> ScannerController { ScannerController(onCode:onCode) }
    func updateUIViewController(_ controller:ScannerController,context:Context) {}
    static func dismantleUIViewController(_ controller:ScannerController,coordinator:()) { controller.stop() }

    final class ScannerController: UIViewController,AVCaptureMetadataOutputObjectsDelegate {
        private let onCode:(String)->Void
        private let session=AVCaptureSession()
        private let queue=DispatchQueue(label:"cc.xypp.yunmeilock.camera")
        private var preview:AVCaptureVideoPreviewLayer?
        private var visible=false
        private var configured=false
        private var delivered=false
        init(onCode:@escaping (String)->Void) { self.onCode=onCode; super.init(nibName:nil,bundle:nil) }
        required init?(coder:NSCoder) { fatalError() }
        override func viewDidLoad() {
            super.viewDidLoad(); view.backgroundColor = .black
            let layer=AVCaptureVideoPreviewLayer(session:session)
            layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer); preview=layer
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews(); preview?.frame=view.bounds
            if let scene=view.window?.windowScene,let connection=preview?.connection,connection.isVideoOrientationSupported {
                switch scene.interfaceOrientation {
                case .landscapeLeft: connection.videoOrientation = .landscapeLeft
                case .landscapeRight: connection.videoOrientation = .landscapeRight
                case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
                default: connection.videoOrientation = .portrait
                }
            }
        }
        override func viewDidAppear(_ animated:Bool) {
            super.viewDidAppear(animated)
            queue.async { self.visible=true; self.start() }
        }
        override func viewWillDisappear(_ animated:Bool) { super.viewWillDisappear(animated); stop() }
        func stop() {
            queue.async { self.visible=false; if self.session.isRunning { self.session.stopRunning() } }
        }
        private func start() {
            guard visible else { return }
            switch AVCaptureDevice.authorizationStatus(for:.video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for:.video) { granted in
                    self.queue.async { if granted { self.start() } else { self.showError("您拒绝了权限请求") } }
                }
            case .authorized:
                if !configured {
                    do {
                        guard let device=AVCaptureDevice.default(for:.video) else { showError("未知错误"); return }
                        let input=try AVCaptureDeviceInput(device:device)
                        let output=AVCaptureMetadataOutput()
                        session.beginConfiguration()
                        guard session.canAddInput(input),session.canAddOutput(output) else { session.commitConfiguration(); showError("未知错误"); return }
                        session.addInput(input); session.addOutput(output)
                        output.setMetadataObjectsDelegate(self,queue:.main)
                        guard output.availableMetadataObjectTypes.contains(.qr) else { session.commitConfiguration(); showError("未知错误"); return }
                        output.metadataObjectTypes=[.qr]
                        session.commitConfiguration(); configured=true
                    } catch { showError("未知错误"); return }
                }
                if !session.isRunning { session.startRunning() }
            default: showError("您拒绝了权限请求")
            }
        }
        private func showError(_ text:String) {
            DispatchQueue.main.async {
                let label=UILabel(); label.text=text; label.textColor = .white; label.textAlignment = .center
                label.frame=self.view.bounds; label.autoresizingMask=[.flexibleWidth,.flexibleHeight]
                self.view.addSubview(label)
            }
        }
        func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput metadataObjects:[AVMetadataObject],from connection:AVCaptureConnection) {
            guard !delivered,let object=metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first(where:{ $0.type == .qr }),let code=object.stringValue else { return }
            delivered=true; stop(); onCode(code)
        }
    }
}
