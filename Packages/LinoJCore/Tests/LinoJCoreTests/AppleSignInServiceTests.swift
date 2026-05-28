// AppleSignInServiceTests.swift
// V3：验证 AppleSignInService 的登录状态机 + 持久化（不真跑 ASAuthorizationController / Keychain）。
//
// 测试策略：
//   - 注入 `InMemoryIdentityStore` 替代真 Keychain（headless / CI 友好，不触系统 Keychain）。
//   - 用 internal 测试钩子 `applyCredential(userID:name:email:)` 模拟一次成功授权，避免构造
//     真实的 ASAuthorization（其 credential 无法在测试里 mock）。
//   - 覆盖：初始登出态、应用凭据后登录态 + 字段、首次后再登录的 name/email 合并、signOut
//     清除状态 + 持久化、restoreState 从持久化恢复。

import Foundation
import Testing
@testable import LinoJCore

@Suite("V3 AppleSignInService 登录状态机与持久化")
@MainActor
struct AppleSignInServiceTests {

    @Test("初始：未登录，isSignedIn == false，所有便捷字段 nil")
    func initialSignedOut() {
        let service = AppleSignInService(store: InMemoryIdentityStore())
        #expect(service.state == .signedOut)
        #expect(service.isSignedIn == false)
        #expect(service.userID == nil)
        #expect(service.displayName == nil)
        #expect(service.email == nil)
    }

    @Test("应用凭据后：isSignedIn == true，userID/name/email 字段正确，已持久化")
    func applyCredentialSignsIn() {
        let store = InMemoryIdentityStore()
        let service = AppleSignInService(store: store)

        service.applyCredential(userID: "user-abc", name: "Tim Cook", email: "tim@apple.com")

        #expect(service.isSignedIn == true)
        #expect(service.userID == "user-abc")
        #expect(service.displayName == "Tim Cook")
        #expect(service.email == "tim@apple.com")
        #expect(service.state == .signedIn(userID: "user-abc", displayName: "Tim Cook", email: "tim@apple.com"))

        // 已写入持久化后端。
        let saved = store.load()
        #expect(saved?.userID == "user-abc")
        #expect(saved?.name == "Tim Cook")
        #expect(saved?.email == "tim@apple.com")
    }

    @Test("首次登录后再登录（Apple 只回 userID，name/email 为 nil）：沿用首次缓存值，不被覆盖成空")
    func subsequentLoginKeepsCachedNameEmail() {
        let store = InMemoryIdentityStore()
        let service = AppleSignInService(store: store)

        // 首次：拿到 name + email。
        service.applyCredential(userID: "user-xyz", name: "Jane Doe", email: "jane@icloud.com")
        // 之后：同一 userID，Apple 只回 userID（name/email nil）。
        service.applyCredential(userID: "user-xyz", name: nil, email: nil)

        #expect(service.isSignedIn == true)
        #expect(service.userID == "user-xyz")
        // 沿用首次缓存的 name/email，不被覆盖成 nil。
        #expect(service.displayName == "Jane Doe")
        #expect(service.email == "jane@icloud.com")
        #expect(store.load()?.name == "Jane Doe")
        #expect(store.load()?.email == "jane@icloud.com")
    }

    @Test("signOut() 后：isSignedIn == false，状态回 signedOut，持久化已清")
    func signOutClearsEverything() {
        let store = InMemoryIdentityStore()
        let service = AppleSignInService(store: store)
        service.applyCredential(userID: "user-1", name: "A B", email: "a@b.com")
        #expect(service.isSignedIn == true)

        service.signOut()

        #expect(service.isSignedIn == false)
        #expect(service.state == .signedOut)
        #expect(service.userID == nil)
        // 持久化被清空 —— 下次 restoreState 不会再恢复出登录态。
        #expect(store.load() == nil)
    }

    @Test("restoreState()：从已存身份恢复登录态")
    func restoreStateFromStore() {
        let store = InMemoryIdentityStore()
        // 预置一个已存身份（模拟上次登录的持久化结果）。
        store.save(userID: "user-restored", name: "Restored User", email: "r@example.com")

        let service = AppleSignInService(store: store)
        // init 不自动读 store —— 显式 restore 后才反映登录态。
        #expect(service.isSignedIn == false)

        service.restoreState()

        #expect(service.isSignedIn == true)
        #expect(service.userID == "user-restored")
        #expect(service.displayName == "Restored User")
        #expect(service.email == "r@example.com")
    }

    @Test("restoreState()：无持久化身份时维持未登录")
    func restoreStateEmptyStaysSignedOut() {
        let service = AppleSignInService(store: InMemoryIdentityStore())
        service.restoreState()
        #expect(service.isSignedIn == false)
        #expect(service.state == .signedOut)
    }

    @Test("不同 userID 登录：不沿用上一身份的 name/email（缓存仅对同一 userID 生效）")
    func differentUserIDDoesNotInheritCachedFields() {
        let store = InMemoryIdentityStore()
        let service = AppleSignInService(store: store)

        // 用户 A 首次登录带 name + email。
        service.applyCredential(userID: "user-A", name: "Alice", email: "alice@a.com")
        #expect(service.displayName == "Alice")

        // 切换到完全不同的 userID B，只回 userID（name/email nil）。
        // 不应把 A 的 name/email 张冠李戴给 B —— 合并只对同一 userID 回退。
        service.applyCredential(userID: "user-B", name: nil, email: nil)
        #expect(service.userID == "user-B")
        #expect(service.displayName == nil)
        #expect(service.email == nil)
        #expect(store.load()?.userID == "user-B")
        #expect(store.load()?.name == nil)
    }

    @Test("空 store 上首次 applyCredential 只回 userID：name/email 维持 nil（无旧值可回退）")
    func firstCredentialWithoutNameStaysNil() {
        let store = InMemoryIdentityStore()
        let service = AppleSignInService(store: store)

        service.applyCredential(userID: "user-bare", name: nil, email: nil)
        #expect(service.isSignedIn == true)
        #expect(service.userID == "user-bare")
        #expect(service.displayName == nil)
        #expect(service.email == nil)
    }
}
