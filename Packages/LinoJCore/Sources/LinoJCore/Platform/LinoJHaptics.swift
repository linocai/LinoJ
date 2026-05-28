// LinoJHaptics.swift
// 跨平台的轻量 haptic feedback 抽象 —— plan P6 「iOS haptics」要求。
//
// 设计要点：
//   - iOS 上调用 `UIImpactFeedbackGenerator(style: .light).impactOccurred()` 触发轻震动；
//   - macOS / 其它平台上为空实现（no-op），保证 LinoJCore 跨平台编译通过；
//   - 接口稳定不变，调用方（ViewModel）只 import LinoJCore 即可用；
//   - 标 @MainActor 因为 UIFeedbackGenerator 必须在主线程访问。
//
// 调用点：
//   - PersonalViewModel.toggleDone / toggleUrgency
//   - MainViewModel.toggleDone / confirmAttended
//   - CompanyViewModel.toggleDone
//   - ProjectDetailViewModel.toggleDone / toggleUrgency
//   - QuickAddViewModel.submit

import Foundation
#if canImport(UIKit) && os(iOS)
import UIKit
#endif

/// 轻量 haptic feedback —— 用户操作 toggle / 创建对象时调一下。
///
/// iOS 真机上会产生 ~10ms 轻震动；macOS / iOS 模拟器 / 其它平台无副作用。
@MainActor
public enum LinoJHaptics {

    /// 触发 light impact haptic（iOS 真机有效，其它平台 no-op）。
    public static func lightTap() {
        #if canImport(UIKit) && os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}
