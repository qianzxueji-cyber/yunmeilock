import Foundation
import Combine

final class Settings: ObservableObject {
    private let defaults=UserDefaults.standard
    private let secure=SecureStore()
    @Published var loginUsr:String { didSet { defaults.set(loginUsr,forKey:"loginUsr") } }
    @Published var loginPsw:String { didSet { secure.set("loginPsw",loginPsw); defaults.removeObject(forKey:"loginPsw") } }
    @Published var userId:String { didSet { defaults.set(userId,forKey:"userId") } }
    @Published var schoolNo:String { didSet { defaults.set(schoolNo,forKey:"schoolNo") } }
    @Published var lockNo:String { didSet { defaults.set(lockNo,forKey:"lockNo") } }
    @Published var rel:String { didSet { defaults.set(rel,forKey:"rel") } }
    @Published var lst:String { didSet { defaults.set(lst,forKey:"lst") } }
    @Published var lstLoca:String { didSet { defaults.set(lstLoca,forKey:"lstLoca") } }
    @Published var autoCon:Bool { didSet { defaults.set(autoCon,forKey:"autoCon") } }
    @Published var autoExit:Bool { didSet { defaults.set(autoExit,forKey:"autoExit") } }
    @Published var sigLoc:String { didSet { defaults.set(sigLoc,forKey:"sigLoc") } }
    var isLoggedIn:Bool { !loginUsr.isEmpty && !loginPsw.isEmpty }
    func clearAccount() {
        loginUsr=""; loginPsw=""; userId=""; schoolNo=""; lockNo=""; rel=""; lst=""
    }
    init() {
        loginUsr=defaults.string(forKey:"loginUsr") ?? ""
        loginPsw=secure.get("loginPsw") ?? defaults.string(forKey:"loginPsw") ?? ""
        userId=defaults.string(forKey:"userId") ?? ""
        schoolNo=defaults.string(forKey:"schoolNo") ?? ""
        lockNo=defaults.string(forKey:"lockNo") ?? ""
        rel=defaults.string(forKey:"rel") ?? ""
        lst=defaults.string(forKey:"lst") ?? ""
        lstLoca=defaults.string(forKey:"lstLoca") ?? ""
        autoCon=defaults.bool(forKey:"autoCon")
        autoExit=defaults.bool(forKey:"autoExit")
        sigLoc=defaults.string(forKey:"sigLoc") ?? "ask"
        if !loginPsw.isEmpty { secure.set("loginPsw",loginPsw); defaults.removeObject(forKey:"loginPsw") }
    }
}
