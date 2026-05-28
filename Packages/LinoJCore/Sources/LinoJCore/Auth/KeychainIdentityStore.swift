// KeychainIdentityStore.swift
// V3：Sign in with Apple 身份的 Keychain 持久化实现（plan V3：user identifier 存 Keychain，敏感）。
//
// 存三项 generic password item（同 service，不同 account key）：
//   - account "userID"      → Apple 稳定 user identifier（credential.user）
//   - account "displayName" → 首次授权拿到的姓名（可缺省）
//   - account "email"       → 首次授权拿到的 email（可缺省）
//
// 设计：
//   - service 取 App bundle 风格命名前缀 "com.linocai.linoj.appleid"，两端共用同一逻辑（各自
//     Keychain 隔离，不跨 App 共享 —— 不开 keychain access group，避免引入额外 entitlement）。
//   - `kSecAttrAccessibleAfterFirstUnlock`：设备首次解锁后可读，覆盖后台启动校验场景。
//   - 所有 SecItem 操作失败时静默降级（load 返回 nil / save 尽力而为）—— 登录态丢失最多让用户
//     重新点一次 Sign in，不应 crash。
//
// 并发：`Sendable`（无可变状态，纯 Security framework 调用），可在 @MainActor service 持有。

import Foundation

#if canImport(Security)
import Security
#endif

public struct KeychainIdentityStore: AppleIDIdentityStore {

    /// Keychain service 标识。两端各自隔离（不共享 access group）。
    private let service: String

    private enum Account {
        static let userID = "userID"
        static let displayName = "displayName"
        static let email = "email"
    }

    public init(service: String = "com.linocai.linoj.appleid") {
        self.service = service
    }

    // MARK: - AppleIDIdentityStore

    public func save(userID: String, name: String?, email: String?) {
        setValue(userID, account: Account.userID)
        // name/email 可能 nil（后续登录）—— nil 时清掉该 item，避免残留旧值。
        if let name {
            setValue(name, account: Account.displayName)
        } else {
            deleteItem(account: Account.displayName)
        }
        if let email {
            setValue(email, account: Account.email)
        } else {
            deleteItem(account: Account.email)
        }
    }

    public func load() -> (userID: String, name: String?, email: String?)? {
        guard let userID = getValue(account: Account.userID) else {
            return nil
        }
        let name = getValue(account: Account.displayName)
        let email = getValue(account: Account.email)
        return (userID, name, email)
    }

    public func clear() {
        deleteItem(account: Account.userID)
        deleteItem(account: Account.displayName)
        deleteItem(account: Account.email)
    }

    // MARK: - SecItem helpers

    #if canImport(Security)
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// 写入 / 覆盖一条 generic password。
    /// 0.9.1 修订：先试 `SecItemUpdate`，item 不存在（errSecItemNotFound）再 `SecItemAdd`。
    /// 不再「先无条件 delete 再 add」——避免 delete 成功而 add 失败时丢身份（写失败旧值仍在）。
    private func setValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery(account: account)
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            // 尚无此 item —— 新增。
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            _ = SecItemAdd(attributes as CFDictionary, nil)
        }
        // 其它失败（极少）静默降级：旧值保留，最多让用户重登一次。
    }

    /// 读取一条 generic password 的字符串值；缺失 / 失败返回 nil。
    private func getValue(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 删除一条 generic password；不存在视为成功（noop）。
    private func deleteItem(account: String) {
        _ = SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
    #else
    // 非 Security 平台（不应发生）—— 空实现保接口完整。
    private func setValue(_ value: String, account: String) {}
    private func getValue(account: String) -> String? { nil }
    private func deleteItem(account: String) {}
    #endif
}
