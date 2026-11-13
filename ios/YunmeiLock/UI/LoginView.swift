import SwiftUI
import Foundation

struct LoginView: View {
    @EnvironmentObject private var settings:Settings
    @EnvironmentObject private var store:LockStore
    @State private var user=""
    @State private var password=""
    @State private var remember=true
    @State private var busy=false
    @State private var schools:[School]=[]
    @State private var fetched:[Lock]=[]
    @State private var userId=""
    @State private var chooseSchool=false
    @State private var message=""
    @State private var showMessage=false
    private let api=YunmeiAPI()
    var body: some View {
        Form {
            Section {
                TextField("用户名",text:$user).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("密码",text:$password).textContentType(.password)
                Toggle("保存为默认",isOn:$remember)
                Button("登录") { Task { await load() } }.disabled(busy || user.isEmpty || password.isEmpty)
                Button("获取门锁") { Task { await load() } }.disabled(busy || user.isEmpty || password.isEmpty)
                if busy { ProgressView() }
            }
            if !fetched.isEmpty {
                Section("获取门锁") {
                    ForEach(fetched) { lock in
                        HStack {
                            Text(lock.label)
                            Spacer()
                            Button("确定") { add([lock]) }
                        }
                    }
                    Button("确定") { add(fetched) }
                }
            }
        }
        .navigationTitle("登录")
        .onAppear { user=settings.loginUsr; password=settings.loginPsw }
        .confirmationDialog("选择要添加门锁的学校",isPresented:$chooseSchool,titleVisibility:.visible) {
            ForEach(schools,id:\.schoolNo) { school in Button(school.schoolName) { Task { await fetch(school) } } }
            Button("放弃",role:.cancel) {}
        }
        .alert(message,isPresented:$showMessage) { Button("确定",role:.cancel) {} }
    }
    @MainActor private func load() async {
        busy=true; fetched=[]
        defer { busy=false }
        do {
            let session=try await api.login(user:user,passwordMD5:MD5.hex(password))
            userId=session.userId
            settings.loginUsr=remember ? user : ""; settings.loginPsw=remember ? password : ""
            settings.rel=settings.lst; settings.lst=String(Date().timeIntervalSince1970)
            schools=try await api.schools(userId:userId)
            if schools.isEmpty { report("账号不属于任何一所学校，请检查后重新添加") }
            else if schools.count == 1 { await fetch(schools[0]) }
            else { chooseSchool=true }
        } catch { report(error.localizedDescription) }
    }
    @MainActor private func fetch(_ school:School) async {
        busy=true
        defer { busy=false }
        do {
            fetched=try await api.locks(schoolNo:school.schoolNo,userId:userId,school:school)
            if fetched.isEmpty { report("当前账号不存在任何门锁") }
        } catch { report(error.localizedDescription) }
    }
    private func add(_ locks:[Lock]) {
        do {
            if let duplicate=locks.first(where:{ candidate in store.locks.contains(where:{ $0.label == candidate.label }) }) { throw AppError.message("\(duplicate.label) 已存在") }
            for lock in locks { try store.add(lock) }
            if store.defaultLabel == nil,let first=locks.first { store.setDefault(first) }
            if let first=locks.first {
                let key=MD5.hex(first.serialized)
                settings.schoolNo=SecureStore().get("lock.school.\(key)") ?? ""
                settings.lockNo=SecureStore().get("lock.number.\(key)") ?? ""
            }
            fetched.removeAll { candidate in locks.contains(where:{ $0.label == candidate.label }) }
        } catch { report(error.localizedDescription) }
    }
    private func report(_ text:String) { message=text; showMessage=true }
}
