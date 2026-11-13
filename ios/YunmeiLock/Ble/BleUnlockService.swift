import Foundation
import Combine
import CoreBluetooth

enum UnlockStage: Equatable {
    case idle,requesting,scanning,found,connected,writing,done,failed(String)

    var title:String {
        switch self {
        case .idle:return ""
        case .requesting:return "申请权限"
        case .scanning:return "正在搜索门锁"
        case .found:return "设备已找到"
        case .connected:return "连接成功"
        case .writing:return "正在开门"
        case .done:return "开门完成"
        case .failed(let text):return text
        }
    }
    var isTerminal:Bool {
        switch self {
        case .done,.failed:return true
        default:return false
        }
    }
}

final class BleUnlockService:NSObject,ObservableObject,CBCentralManagerDelegate,CBPeripheralDelegate {
    @Published var stage:UnlockStage = .idle
    @Published var progress:Double=0
    @Published var deviceIdentifier:String?
    var onFinish:((Bool,String)->Void)?

    private var central:CBCentralManager!
    private var activeLock:Lock?
    private var peripheral:CBPeripheral?
    private var quick=false
    private var timeout:DispatchWorkItem?
    private var generation=0
    private var chunks:[Data]=[]
    private var chunkIndex=0

    override init() {
        super.init()
        central=CBCentralManager(delegate:self,queue:.main)
    }

    func unlock(lock:Lock,quickConnect:Bool) {
        cancel()
        guard lock.servUuid != nil,lock.charUuid != nil,!lock.secret.isEmpty else { fail("门锁信息无效"); return }
        activeLock=lock; quick=quickConnect; deviceIdentifier=nil
        stage = .requesting
        switch central.state {
        case .poweredOn: beginAttempt()
        case .unauthorized: fail("您拒绝了权限请求")
        case .poweredOff,.unsupported: fail("连接失败")
        default: armTimeout("连接失败",seconds:10)
        }
    }

    func cancel() {
        generation+=1; activeLock=nil
        disconnect(); stage = .idle; progress=0
    }

    private var cacheKey:String {
        guard let lock=activeLock else { return "" }
        return "ble.identifier.\(lock.label).\(lock.servUUID).\(lock.charUUID)"
    }

    private func beginAttempt() {
        guard let lock=activeLock,let service=lock.servUuid else { return }
        timeout?.cancel(); progress=0
        if quick,let raw=UserDefaults.standard.string(forKey:cacheKey),let identifier=UUID(uuidString:raw),let cached=central.retrievePeripherals(withIdentifiers:[identifier]).first {
            connect(cached)
        } else {
            stage = .scanning
            central.scanForPeripherals(withServices:[CBUUID(nsuuid:service)],options:[CBCentralManagerScanOptionAllowDuplicatesKey:false])
            armTimeout("设备未找到",seconds:12)
        }
    }

    private func connect(_ device:CBPeripheral) {
        central.stopScan(); timeout?.cancel()
        peripheral=device; device.delegate=self
        stage = .found; progress=0.4
        central.connect(device,options:nil)
        armTimeout("连接失败",seconds:10)
    }

    private func armTimeout(_ message:String,seconds:Double) {
        timeout?.cancel()
        let current=generation
        let work=DispatchWorkItem { [weak self] in
            guard let self=self,self.generation == current,self.activeLock != nil else { return }
            self.attemptFailed(message)
        }
        timeout=work; DispatchQueue.main.asyncAfter(deadline:.now()+seconds,execute:work)
    }

    private func attemptFailed(_ message:String) {
        guard activeLock != nil else { return }
        if quick {
            quick=false; generation+=1
            disconnect()
            stage = .failed("快速连接失败，使用常规模式尝试"); progress=0.02
            let current=generation
            let retry=DispatchWorkItem { [weak self] in
                guard let self=self,self.generation == current,self.activeLock != nil else { return }
                self.beginAttempt()
            }
            timeout=retry; DispatchQueue.main.asyncAfter(deadline:.now()+0.6,execute:retry)
        } else { fail(message) }
    }

    private func fail(_ message:String) {
        generation+=1; activeLock=nil
        disconnect(); progress=0; stage = .failed(message)
        onFinish?(false,message)
    }

    private func complete() {
        activeLock=nil; generation+=1
        disconnect(); progress=1; stage = .done
        onFinish?(true,"开门完成")
    }

    private func disconnect() {
        timeout?.cancel(); timeout=nil
        if central != nil,central.state == .poweredOn { central.stopScan() }
        let device=peripheral
        peripheral=nil; chunks=[]; chunkIndex=0
        device?.delegate=nil
        if let device=device { central.cancelPeripheralConnection(device) }
    }

    func centralManagerDidUpdateState(_ central:CBCentralManager) {
        guard activeLock != nil else { return }
        switch central.state {
        case .poweredOn: beginAttempt()
        case .unauthorized: fail("您拒绝了权限请求")
        case .poweredOff,.unsupported: fail("连接失败")
        default: break
        }
    }

    func centralManager(_ central:CBCentralManager,didDiscover peripheral:CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber) {
        guard activeLock != nil,self.peripheral == nil else { return }
        guard case .scanning=stage else { return }
        connect(peripheral)
    }

    func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral) {
        guard peripheral === self.peripheral,let uuid=activeLock?.servUuid else { return }
        timeout?.cancel(); stage = .connected; progress=0.5
        deviceIdentifier=peripheral.identifier.uuidString
        peripheral.discoverServices([CBUUID(nsuuid:uuid)])
        armTimeout("连接失败",seconds:10)
    }

    func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?) {
        guard peripheral === self.peripheral else { return }
        attemptFailed("连接失败")
    }

    func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?) {
        guard peripheral === self.peripheral,activeLock != nil else { return }
        if case .writing=stage { fail("开门失败") } else { attemptFailed("连接失败") }
    }

    func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard peripheral === self.peripheral,let lock=activeLock,let serviceUUID=lock.servUuid,let charUUID=lock.charUuid else { return }
        guard error == nil,let service=peripheral.services?.first(where:{ $0.uuid == CBUUID(nsuuid:serviceUUID) }) else { attemptFailed("连接失败"); return }
        peripheral.discoverCharacteristics([CBUUID(nsuuid:charUUID)],for:service)
    }

    func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard peripheral === self.peripheral,let lock=activeLock,let uuid=lock.charUuid else { return }
        guard error == nil,let characteristic=service.characteristics?.first(where:{ $0.uuid == CBUUID(nsuuid:uuid) }),characteristic.properties.contains(.write) else { attemptFailed("开门失败"); return }
        let bytes=Data(UnlockFrame.payload(secret:lock.secret))
        let maximum=peripheral.maximumWriteValueLength(for:.withResponse)
        guard maximum>0 else { fail("开门失败"); return }
        chunks=stride(from:0,to:bytes.count,by:maximum).map { bytes.subdata(in:$0..<min($0+maximum,bytes.count)) }
        chunkIndex=0
        stage = .writing; progress=0.6
        armTimeout("开门失败",seconds:10)
        peripheral.writeValue(chunks[0],for:characteristic,type:.withResponse)
    }

    func peripheral(_ peripheral:CBPeripheral,didWriteValueFor characteristic:CBCharacteristic,error:Error?) {
        guard peripheral === self.peripheral,let uuid=activeLock?.charUuid,characteristic.uuid == CBUUID(nsuuid:uuid) else { return }
        guard case .writing=stage else { return }
        guard error == nil else { fail("开门失败"); return }
        chunkIndex+=1; progress=0.6+0.4*Double(chunkIndex)/Double(max(chunks.count,1))
        if chunkIndex<chunks.count {
            armTimeout("开门失败",seconds:10)
            peripheral.writeValue(chunks[chunkIndex],for:characteristic,type:.withResponse)
        } else {
            UserDefaults.standard.set(peripheral.identifier.uuidString,forKey:cacheKey)
            complete()
        }
    }
}
