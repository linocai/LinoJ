// ColorTokensTests.swift
// 校验 `Color.lj.*` 的 light / dark 数值与 README 一致。
//
// 实现思路（重要）：
//   测试 host（swift test 在 CLI 下运行）的 NSAppearance 不一定是 Aqua；
//   实测 host 把 dynamic color 解析到 darkAqua 分支，因此对 `Color.lj.bg`
//   直接做 light hex 比对会失败。
//
//   于是用「分两路验证」策略：
//   1. 对 light / dark 端的 hex 字面量做 `Color(hex:)` round-trip 校验
//      （证明源头数字写对了 + 解析无误）；
//   2. 在 macOS 上把 `NSAppearance.aqua` / `NSAppearance.darkAqua` 显式
//      `performAsCurrentDrawingAppearance { }` 包住 NSColor 解析，强制
//      取到对应 appearance 的分支值，比对 `Color.lj.*` 实际 token。
//   这样 light & dark 双 set 都能在 CLI 上稳定校验。

import SwiftUI
import Testing
@testable import LinoJCore

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Suite("Color token hex 校验")
@MainActor
struct ColorTokensTests {

    // MARK: - Hex round-trip (light + dark 字面量都得能正确解析)

    @Test("Light bg hex #fafaf9 parses correctly")
    func lightBgHexParses() {
        assertHexRGB(Color(hex: 0xfafaf9), r: 0xfa, g: 0xfa, b: 0xf9, label: "light bg")
    }

    @Test("Light bgSoft hex #f3f2ef parses correctly")
    func lightBgSoftHexParses() {
        assertHexRGB(Color(hex: 0xf3f2ef), r: 0xf3, g: 0xf2, b: 0xef, label: "light bgSoft")
    }

    @Test("Light panel hex #ffffff parses correctly")
    func lightPanelHexParses() {
        assertHexRGB(Color(hex: 0xffffff), r: 0xff, g: 0xff, b: 0xff, label: "light panel")
    }

    @Test("Light ink hex #0a0a0a parses correctly")
    func lightInkHexParses() {
        assertHexRGB(Color(hex: 0x0a0a0a), r: 0x0a, g: 0x0a, b: 0x0a, label: "light ink")
    }

    // v1.3：紫蓝强调（无橙）。blue 系列改值 —— accent #6E63E6 / accentDeep #5B5BD6 / 紫点 #8A6DF0。
    @Test("Light blue (accent) hex #6E63E6 parses correctly")
    func lightBlueHexParses() {
        assertHexRGB(Color(hex: 0x6E63E6), r: 0x6E, g: 0x63, b: 0xE6, label: "light blue/accent")
    }

    @Test("Light blueInk (accentDeep) hex #5B5BD6 parses correctly")
    func lightBlueInkHexParses() {
        assertHexRGB(Color(hex: 0x5B5BD6), r: 0x5B, g: 0x5B, b: 0xD6, label: "light blueInk/accentDeep")
    }

    @Test("Light purpleDot hex #8A6DF0 parses correctly")
    func lightPurpleDotHexParses() {
        assertHexRGB(Color(hex: 0x8A6DF0), r: 0x8A, g: 0x6D, b: 0xF0, label: "light purpleDot")
    }

    @Test("Brand gradient ends #5B8DEF / #8A6DF0 parse correctly")
    func brandGradientEndsParse() {
        assertHexRGB(Color(hex: 0x5B8DEF), r: 0x5B, g: 0x8D, b: 0xEF, label: "brandBlue")
        assertHexRGB(Color(hex: 0x8A6DF0), r: 0x8A, g: 0x6D, b: 0xF0, label: "brandPurple")
    }

    @Test("Light iosMainBg hex #f4f3ef parses correctly")
    func lightIosMainBgHexParses() {
        assertHexRGB(Color(hex: 0xf4f3ef), r: 0xf4, g: 0xf3, b: 0xef, label: "iosMainBg")
    }

    @Test("Dark bg hex #0d0d0e parses correctly")
    func darkBgHexParses() {
        assertHexRGB(Color(hex: 0x0d0d0e), r: 0x0d, g: 0x0d, b: 0x0e, label: "dark bg")
    }

    @Test("Dark blue (accent) hex #9D93F2 parses correctly")
    func darkBlueHexParses() {
        assertHexRGB(Color(hex: 0x9D93F2), r: 0x9D, g: 0x93, b: 0xF2, label: "dark blue/accent")
    }

    @Test("Dark ink hex #f6f6f5 parses correctly")
    func darkInkHexParses() {
        assertHexRGB(Color(hex: 0xf6f6f5), r: 0xf6, g: 0xf6, b: 0xf5, label: "dark ink")
    }

    @Test("Dark panel hex #181819 parses correctly")
    func darkPanelHexParses() {
        assertHexRGB(Color(hex: 0x181819), r: 0x18, g: 0x18, b: 0x19, label: "dark panel")
    }

    // MARK: - Dynamic token resolution（macOS only）

    /// macOS：强制以 aqua / darkAqua 解析 `Color.lj.*`，
    /// 验证 light / dark 两条分支都用对了 hex。
    /// iOS test host 上没有等价 API（UITraitCollection.current 不可写），跳过即可。
    #if os(macOS)

    @Test("Color.lj.bg in aqua resolves to light hex")
    func bgResolvesLight() {
        let c = resolveSRGB(Color.lj.bg, appearance: .aqua)
        expectRGB(c, r: 0xfa, g: 0xfa, b: 0xf9, label: "bg aqua")
    }

    @Test("Color.lj.bg in darkAqua resolves to dark hex")
    func bgResolvesDark() {
        let c = resolveSRGB(Color.lj.bg, appearance: .darkAqua)
        expectRGB(c, r: 0x0d, g: 0x0d, b: 0x0e, label: "bg darkAqua")
    }

    @Test("Color.lj.panel in aqua = white, in darkAqua = #181819")
    func panelResolves() {
        let lc = resolveSRGB(Color.lj.panel, appearance: .aqua)
        expectRGB(lc, r: 0xff, g: 0xff, b: 0xff, label: "panel aqua")
        let dc = resolveSRGB(Color.lj.panel, appearance: .darkAqua)
        expectRGB(dc, r: 0x18, g: 0x18, b: 0x19, label: "panel darkAqua")
    }

    @Test("Color.lj.ink in aqua = #0a0a0a, in darkAqua = #f6f6f5")
    func inkResolves() {
        let lc = resolveSRGB(Color.lj.ink, appearance: .aqua)
        expectRGB(lc, r: 0x0a, g: 0x0a, b: 0x0a, label: "ink aqua")
        let dc = resolveSRGB(Color.lj.ink, appearance: .darkAqua)
        expectRGB(dc, r: 0xf6, g: 0xf6, b: 0xf5, label: "ink darkAqua")
    }

    @Test("Color.lj.blue (accent) in aqua = #6E63E6, in darkAqua = #9D93F2")
    func blueResolves() {
        let lc = resolveSRGB(Color.lj.blue, appearance: .aqua)
        expectRGB(lc, r: 0x6E, g: 0x63, b: 0xE6, label: "blue/accent aqua")
        let dc = resolveSRGB(Color.lj.blue, appearance: .darkAqua)
        expectRGB(dc, r: 0x9D, g: 0x93, b: 0xF2, label: "blue/accent darkAqua")
    }

    @Test("Color.lj.accent == Color.lj.blue, accentDeep == blueInk (语义别名)")
    func accentAliases() {
        let acc = resolveSRGB(Color.lj.accent, appearance: .aqua)
        expectRGB(acc, r: 0x6E, g: 0x63, b: 0xE6, label: "accent aqua")
        let deep = resolveSRGB(Color.lj.accentDeep, appearance: .aqua)
        expectRGB(deep, r: 0x5B, g: 0x5B, b: 0xD6, label: "accentDeep aqua")
        let dot = resolveSRGB(Color.lj.purpleDot, appearance: .aqua)
        expectRGB(dot, r: 0x8A, g: 0x6D, b: 0xF0, label: "purpleDot aqua")
    }

    /// 用指定 NSAppearance 解析 SwiftUI Color 到 sRGB 分量。
    /// 关键是 `performAsCurrentDrawingAppearance` —— 在闭包里临时把 currentDrawingAppearance
    /// 切到目标 appearance，再实例化 NSColor，让 dynamic provider 取对应分支。
    private func resolveSRGB(
        _ color: Color,
        appearance name: NSAppearance.Name
    ) -> (r: Double, g: Double, b: Double, a: Double) {
        let appearance = NSAppearance(named: name) ?? NSAppearance.currentDrawing()
        var result: NSColor = .white
        appearance.performAsCurrentDrawingAppearance {
            result = NSColor(color).usingColorSpace(.sRGB) ?? .white
        }
        return (
            Double(result.redComponent),
            Double(result.greenComponent),
            Double(result.blueComponent),
            Double(result.alphaComponent)
        )
    }

    private func expectRGB(
        _ c: (r: Double, g: Double, b: Double, a: Double),
        r: Int, g: Int, b: Int,
        label: String,
        tolerance: Double = 0.005
    ) {
        #expect(abs(c.r - Double(r) / 255.0) < tolerance, "\(label) R: \(c.r)")
        #expect(abs(c.g - Double(g) / 255.0) < tolerance, "\(label) G: \(c.g)")
        #expect(abs(c.b - Double(b) / 255.0) < tolerance, "\(label) B: \(c.b)")
    }
    #endif

    // MARK: - Helpers

    /// 校验一个静态 Color（`Color(hex:)` 直接构造的）的 sRGB 分量。
    private func assertHexRGB(
        _ color: Color,
        r: Int, g: Int, b: Int,
        label: String,
        tolerance: Double = 0.005
    ) {
        let c = components(color)
        #expect(abs(c.r - Double(r) / 255.0) < tolerance, "\(label) R: \(c.r)")
        #expect(abs(c.g - Double(g) / 255.0) < tolerance, "\(label) G: \(c.g)")
        #expect(abs(c.b - Double(b) / 255.0) < tolerance, "\(label) B: \(c.b)")
    }

    /// 取一个 Color 的 sRGB (r,g,b,a) 分量（不切 appearance；用于静态 hex round-trip）。
    private func components(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(AppKit)
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        return (
            Double(ns.redComponent),
            Double(ns.greenComponent),
            Double(ns.blueComponent),
            Double(ns.alphaComponent)
        )
        #elseif canImport(UIKit)
        let ui = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        return (0, 0, 0, 1)
        #endif
    }
}
