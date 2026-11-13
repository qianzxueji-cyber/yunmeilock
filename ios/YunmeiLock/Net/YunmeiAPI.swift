import Foundation

struct School: Identifiable, Hashable {
    let schoolNo,schoolName,serverUrl,token:String
    var id:String { schoolNo }
}

final class YunmeiAPI {
    private static let base="https://base.yunmeitech.com/"
    private let secure=SecureStore()
    private var client:any HTTPClient
    init() { client=URLSessionHTTPClient(baseURL:Self.base) }
    func login(user:String,passwordMD5:String) async throws -> (token:String,userId:String) {
        client.baseURL=Self.base; client.token=nil; client.userId=nil
        let text=try await client.post("/login",form:["userName":user,"userPwd":passwordMD5])
        let object=try dictionary(text)
        guard object["success"] as? Bool == true,let session=object["o"] as? [String:Any] else { throw AppError.message(object["msg"] as? String ?? "发生了未知错误，请尝试重新提交") }
        let token=try string(session,"token"),userId=try string(session,"userId")
        guard !token.isEmpty,!userId.isEmpty else { throw AppError.message("未知错误") }
        client.token=token; client.userId=userId
        secure.set("session.token",token); secure.set("session.userId",userId)
        return (token,userId)
    }
    func schools(userId:String) async throws -> [School] {
        client.baseURL=Self.base; client.token=secure.get("session.token"); client.userId=userId
        let text=try await client.post("/userschool/getbyuserid",form:["userId":userId])
        return try array(text).map { item in
            let nested=item["school"] as? [String:Any]
            func value(_ key:String)->String? {
                for object in [item,nested ?? [:]] {
                    if let v=object[key] { if let s=v as? String { return s }; if let n=v as? NSNumber { return n.stringValue } }
                }
                return nil
            }
            guard let schoolNo=value("schoolNo"),let token=value("token"),!token.isEmpty else { throw AppError.message("未知错误") }
            return School(schoolNo:schoolNo,schoolName:value("schoolName") ?? "",serverUrl:value("serverUrl") ?? Self.base,token:token)
        }
    }
    func locks(schoolNo:String,userId:String,school:School) async throws -> [Lock] {
        client.baseURL=school.serverUrl; client.token=school.token; client.userId=userId
        let text=try await client.post("/dormuser/getuserlock",form:["schoolNo":schoolNo,"userId":userId])
        let rows=try array(text)
        let entries=try rows.map { item -> (Lock,String) in
            let lock=try Lock(label:string(item,"buildName")+"-"+string(item,"dormNo"),mac:"",charUUID:string(item,"lockCharacterUuid"),servUUID:string(item,"lockServiceUuid"),secret:string(item,"lockSecret"))
            guard lock.servUuid != nil,lock.charUuid != nil,!lock.secret.isEmpty else { throw AppError.message("门锁获取失败") }
            return (lock,try string(item,"lockNo"))
        }
        for (lock,number) in entries {
            let key=MD5.hex(lock.serialized)
            secure.set("lock.school.\(key)",schoolNo)
            secure.set("lock.number.\(key)",number)
        }
        secure.set("school.url.\(schoolNo)",school.serverUrl)
        secure.set("school.token.\(schoolNo)",school.token)
        return entries.map { $0.0 }
    }
    func sign(schoolNo:String,lockNo:String,location:String) async throws -> (ok:Bool,msg:String) {
        guard let server=secure.get("school.url.\(schoolNo)"),let token=secure.get("school.token.\(schoolNo)"),let userId=secure.get("session.userId"),!schoolNo.isEmpty,!lockNo.isEmpty else { throw AppError.message("打卡时出错！") }
        client.baseURL=server; client.token=token; client.userId=userId
        let text=try await client.post("/signrecord/signbyschool",form:["schoolNo":schoolNo,"lockNo":lockNo,"location":location])
        let object=try dictionary(text)
        guard let success=object["success"] as? Bool else { throw AppError.message("打卡时出错！") }
        return (success,object["msg"] as? String ?? (success ? "打卡" : "打卡时出错！"))
    }
    private func dictionary(_ text:String) throws -> [String:Any] {
        guard let object=try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any] else { throw AppError.message("未知错误") }
        return object
    }
    private func array(_ text:String) throws -> [[String:Any]] {
        guard let array=try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [[String:Any]] else {
            let object=try? dictionary(text)
            throw AppError.message(object?["msg"] as? String ?? "门锁获取失败")
        }
        return array
    }
    private func string(_ object:[String:Any],_ key:String) throws -> String {
        if let value=object[key] as? String { return value }
        if let value=object[key] as? NSNumber { return value.stringValue }
        throw AppError.message("未知错误")
    }
}
