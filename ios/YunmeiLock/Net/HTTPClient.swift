import Foundation

protocol HTTPClient {
    var baseURL:String { get set }
    var token:String? { get set }
    var userId:String? { get set }
    func post(_ path:String,form:[String:String]) async throws -> String
    func get(_ path:String) async throws -> String
}

enum AppError: LocalizedError {
    case message(String)
    var errorDescription:String? {
        switch self { case .message(let text): return text }
    }
}

final class URLSessionHTTPClient: HTTPClient {
    var baseURL:String
    var token:String?
    var userId:String?
    init(baseURL:String,token:String?=nil,userId:String?=nil) {
        self.baseURL=baseURL; self.token=token; self.userId=userId
    }
    func post(_ path:String,form:[String:String]) async throws -> String { try await request(path,form:form) }
    func get(_ path:String) async throws -> String { try await request(path,form:nil) }
    private func request(_ path:String,form:[String:String]?) async throws -> String {
        let base=baseURL.trimmingCharacters(in:.whitespacesAndNewlines).trimmingCharacters(in:CharacterSet(charactersIn:"/"))
        let relative=path.trimmingCharacters(in:CharacterSet(charactersIn:"/"))
        guard let url=URL(string:base+"/"+relative),["https","http"].contains(url.scheme?.lowercased() ?? ""),url.host != nil else { throw AppError.message("未知错误") }
        var request=URLRequest(url:url,timeoutInterval:25)
        request.httpMethod=form == nil ? "GET" : "POST"
        request.setValue(token ?? "",forHTTPHeaderField:"token_data")
        request.setValue(userId ?? "",forHTTPHeaderField:"token_userId")
        request.setValue(userId ?? "",forHTTPHeaderField:"tokenUserId")
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        if let form=form {
            let allowed=CharacterSet(charactersIn:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
            let body=form.keys.sorted().map { key in
                let name=key.addingPercentEncoding(withAllowedCharacters:allowed) ?? ""
                let value=(form[key] ?? "").addingPercentEncoding(withAllowedCharacters:allowed) ?? ""
                return name+"="+value
            }.joined(separator:"&")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8",forHTTPHeaderField:"Content-Type")
            request.httpBody=Data(body.utf8)
        }
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse else { throw AppError.message("未知错误") }
        guard (200..<300).contains(response.statusCode) else {
            let object=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            throw AppError.message(object?["msg"] as? String ?? "发生了未知错误，请尝试重新提交")
        }
        guard let text=String(data:data,encoding:.utf8) else { throw AppError.message("未知错误") }
        return text
    }
}
