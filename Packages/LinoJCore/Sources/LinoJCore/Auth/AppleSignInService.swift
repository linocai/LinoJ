// AppleSignInService.swift
// V3：Sign in with Apple 的 App 级登录状态服务（plan v1.0 V3 契约）。
//
// 职责：
//   - 持有当前登录态 `state`（signedOut / signedIn(userID, displayName, email)），驱动 Settings
//     Account 行展示（未登录显示 SignInWithAppleButton，已登录显示姓名 / email）。
//   - 接收 SwiftUI `SignInWithAppleButton` 的 `onCompletion` 结果，从
//     `ASAuthorizationAppleIDCredential` 取 user / fullName / email。
//   - **首次授权才返回 fullName / email，之后只返回稳定的 user identifier**（Apple 规则）。
//     因此首次拿到的姓名 / email 必须持久化，后续仅凭 user identifier 恢复展示。
//   - 启动时 `refreshCredentialState()` 用 `ASAuthorizationAppleIDProvider.getCredentialState`
//     校验凭据：`.authorized` 保留登录态；`.revoked` / `.notFound` 则登出（清持久化）。
//   - `signOut()` 清持久化身份，state → .signedOut。**不动 SwiftData / CloudKit**
//     （SIWA 与系统 iCloud 是两套身份；本 App 数据同步绑定系统 iCloud，不绑 SIWA —— plan V3 决策）。
//
// 持久化方案：Keychain（plan V3 明确「user identifier 存 Keychain（不是 UserDefaults——敏感）」）。
//   - 内部走 `AppleIDIdentityStore` 协议，生产用 `KeychainIdentityStore`，测试注入内存桩，
//     单测不触真 Keychain（headless / CI 友好）。
//
// 并发：`@MainActor @Observable`，状态变更始终在主线程，配合 SwiftUI 订阅刷新。
//
// 跨平台：`AuthenticationServices` 同时支持 macOS / iOS。`ASAuthorization` 解析与
//   `getCredentialState` 两端 API 一致。

import Foundation
import Observation

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@Observable
@MainActor
public final class AppleSignInService {

    /// 登录状态机（plan V3 契约）。
    public enum State: Equatable, Sendable {
        /// 未登录 —— Account 行显示 SignInWithAppleButton。
        case signedOut
        /// 已登录 —— 携带稳定 user identifier + 首次缓存的姓名 / email（后者可能 nil）。
        case signedIn(userID: String, displayName: String?, email: String?)
    }

    /// 当前登录状态，驱动 Settings Account 行展示。
    public private(set) var state: State = .signedOut

    /// 便捷只读：是否已登录。
    public var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// 便捷只读：已登录时的 user identifier，未登录 nil。
    public var userID: String? {
        if case let .signedIn(userID, _, _) = state { return userID }
        return nil
    }

    /// 便捷只读：已登录时缓存的展示名，未登录 / 无名 nil。
    public var displayName: String? {
        if case let .signedIn(_, name, _) = state { return name }
        return nil
    }

    /// 便捷只读：已登录时缓存的 email，未登录 / 无 email nil。
    public var email: String? {
        if case let .signedIn(_, _, email) = state { return email }
        return nil
    }

    /// 身份持久化后端。生产 `KeychainIdentityStore`，测试注入内存桩。
    private let store: any AppleIDIdentityStore

    /// - Parameter store: 身份持久化后端。默认 Keychain（plan V3：敏感数据存 Keychain）。
    ///   测试传入 `InMemoryIdentityStore()` 避免触真 Keychain。
    public init(store: any AppleIDIdentityStore = KeychainIdentityStore()) {
        self.store = store
        // init 不主动读 store —— 由 App 启动 `.task` 调 `restoreState()` 显式恢复，
        // 保证恢复时机可控（与 refreshCredentialState 配合）。
    }

    // MARK: - 启动恢复

    /// App 启动早期从持久化恢复登录态（不校验凭据有效性 —— 那是 `refreshCredentialState` 的活）。
    /// 让 UI 立即反映「上次已登录」，随后 `refreshCredentialState` 异步校验是否被撤销。
    public func restoreState() {
        if let saved = store.load() {
            state = .signedIn(userID: saved.userID, displayName: saved.name, email: saved.email)
        } else {
            state = .signedOut
        }
    }

    // MARK: - 授权回调（SignInWithAppleButton onCompletion）

    #if canImport(AuthenticationServices)
    /// 处理 `SignInWithAppleButton` 的 `onCompletion` 结果。
    /// 成功 → 从 `ASAuthorizationAppleIDCredential` 取 user / fullName / email，持久化并置 signedIn。
    /// 失败（含用户取消 `.canceled`）→ 保持当前 state 不变（不打扰已登录态，也不误把取消当登录）。
    public func handleAuthorization(_ result: Result<ASAuthorization, any Error>) {
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                // 非 AppleID 凭据（理论不会发生，scope 只请求 AppleID）—— 忽略。
                return
            }
            let userID = credential.user
            let name = Self.formatName(credential.fullName)
            let email = credential.email
            applyCredential(userID: userID, name: name, email: email)

        case .failure:
            // 用户取消 / 系统错误：不改变现有状态。SignInWithAppleButton 会在 UI 上自行复位。
            break
        }
    }

    /// 把 `PersonNameComponents` 拼成展示名（"Tim Cook"）。components 全空时返回 nil。
    nonisolated private static func formatName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    #endif

    /// 应用一次凭据：持久化 + 置 signedIn。
    /// **首次授权才有 name/email**；后续登录 credential 的 name/email 为 nil，此时沿用已持久化的旧值，
    /// 避免把展示名 / email 覆盖成空。`internal` 也作为测试钩子（无需真跑 ASAuthorizationController）。
    func applyCredential(userID: String, name: String?, email: String?) {
        // 合并：新值优先，缺失则回退到已存旧值（首次拿到后永久缓存）。
        let existing = store.load()
        let mergedName = name ?? (existing?.userID == userID ? existing?.name : nil)
        let mergedEmail = email ?? (existing?.userID == userID ? existing?.email : nil)

        store.save(userID: userID, name: mergedName, email: mergedEmail)
        state = .signedIn(userID: userID, displayName: mergedName, email: mergedEmail)
    }

    // MARK: - 凭据状态校验

    #if canImport(AuthenticationServices)
    /// 启动时校验当前持久化身份的凭据状态。
    /// `.authorized` → 维持登录态；`.revoked` / `.notFound` → 登出（清持久化）。
    /// 无持久化身份（未登录）则直接返回。
    public func refreshCredentialState() async {
        guard let userID = userID ?? store.load()?.userID else {
            // 未登录，无需校验。
            state = .signedOut
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        let credentialState: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }

        switch credentialState {
        case .authorized:
            // 仍有效：确保 state 反映持久化身份（若 restoreState 未先跑，这里兜底恢复）。
            if let saved = store.load() {
                state = .signedIn(userID: saved.userID, displayName: saved.name, email: saved.email)
            }
        case .revoked, .notFound:
            // 被撤销 / 不存在：登出并清持久化（plan V3 验收：下次启动检测到 revoked 回登出态）。
            signOut()
        default:
            // `.transferred` 等未来枚举值：保守维持现状，不擅自登出。
            break
        }
    }
    #else
    /// 非 AuthenticationServices 平台（不应发生于 macOS/iOS）—— 空实现保接口完整。
    public func refreshCredentialState() async {}
    #endif

    // MARK: - 登出

    /// 登出：清持久化身份，state → .signedOut。
    /// **不动 SwiftData / CloudKit**（plan V3 决策：SIWA 与系统 iCloud 是两套身份，登出不清库）。
    public func signOut() {
        store.clear()
        state = .signedOut
    }
}

// MARK: - 身份持久化后端

/// Sign in with Apple 身份的持久化抽象。生产 Keychain，测试用内存桩。
public protocol AppleIDIdentityStore: Sendable {
    /// 保存稳定 user identifier + 首次缓存的姓名 / email（后两者可 nil）。
    func save(userID: String, name: String?, email: String?)
    /// 读已存身份；无则 nil。
    func load() -> (userID: String, name: String?, email: String?)?
    /// 清除已存身份。
    func clear()
}

/// 测试 / preview 用内存身份桩，不触真 Keychain。
public final class InMemoryIdentityStore: AppleIDIdentityStore, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: (userID: String, name: String?, email: String?)?

    public init() {}

    public func save(userID: String, name: String?, email: String?) {
        lock.lock(); defer { lock.unlock() }
        saved = (userID, name, email)
    }

    public func load() -> (userID: String, name: String?, email: String?)? {
        lock.lock(); defer { lock.unlock() }
        return saved
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        saved = nil
    }
}
