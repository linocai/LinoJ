// HapticsTests.swift
// P6：验证 LinoJHaptics 跨平台编译 + macOS 上无副作用调用。
//
// iOS 真机才会真正触发 UIImpactFeedbackGenerator；本测试只验证：
//   1. macOS / SwiftPM test 环境下调用 lightTap() 不崩；
//   2. 多次连续调用稳定，无 actor 隔离/线程问题。

import Testing
@testable import LinoJCore

@Suite("LinoJHaptics — cross-platform no-op safety")
struct HapticsTests {

    @Test("lightTap() does not crash on macOS test context")
    @MainActor
    func lightTapNoCrashOnMacOS() {
        // 在 macOS 测试上下文里这是一个 no-op；只要不抛、不崩即视为通过。
        LinoJHaptics.lightTap()
    }

    @Test("repeated lightTap() calls remain stable")
    @MainActor
    func repeatedLightTapStability() {
        for _ in 0..<10 {
            LinoJHaptics.lightTap()
        }
        // 没有任何状态需要断言；走到这里就说明 10 次连续调用都没崩。
        #expect(Bool(true))
    }
}
