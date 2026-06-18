// MainSampleRenderTests.swift
// v1.3 R0/R1 视觉自检：用 ImageRenderer 把 macOS Main 视觉件组合离屏渲染成 PNG，
// 供 builder 与 design_handoff_linoj_frontend 参考图并排对图（不依赖屏幕截图通道，锁屏下也能跑）。
//
// 注意：ImageRenderer 对 .regularMaterial / .ultraThinMaterial 的毛玻璃合成保真度有限
//（材质需背后内容合成，离屏渲染可能偏灰）；本样张主要验证布局 / 紫 urgent 左竖条 /
// 来源标签 / 紫 heads-up / orb 透出 / hairline 收边。玻璃材质真实模糊度真机定终态。
//
// 仅 macOS 跑；产物固定写到 /tmp/linoj_fe/app_main_sample.png。

#if os(macOS)
import SwiftUI
import Testing
@testable import LinoJCore

@MainActor
@Suite("v1.3 Main 视觉样张离屏渲染")
struct MainSampleRenderTests {

    @Test("渲染 macOS Main 样张 PNG 到 /tmp/linoj_fe/app_main_sample.png")
    func renderMainSample() throws {
        let view = MainVisualSample()
            .frame(width: 1240, height: 760)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        renderer.isOpaque = true

        guard let nsImage = renderer.nsImage else {
            Issue.record("ImageRenderer 未产出 nsImage")
            return
        }
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("PNG 编码失败")
            return
        }
        let url = URL(fileURLWithPath: "/tmp/linoj_fe/app_main_sample.png")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}

// MARK: - 样张 View（拼 R0/R1 视觉件，用真实模型实例）

private struct MainVisualSample: View {
    private let sampleEvent = Event(
        title: "与 Mei 的 1:1",
        start: Date().addingTimeInterval(600),
        end: Date().addingTimeInterval(2400),
        location: "Blue Bottle, Hayes"
    )

    private func todo(_ title: String, _ u: Urgency, _ s: Scope, project: String? = nil, done: Bool = false) -> Todo {
        let p = project.map { Project(title: $0, intro: "", notes: "", tag: "", createdAt: .now) }
        let t = Todo(title: title, urgency: u, scope: s, project: p, done: done)
        return t
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // v1.3 R1 重做：顶栏样张 —— 居中玻璃分段 pill + 右上 搜索/齿轮/头像簇。
                topBar
                HStack(spacing: 0) {
                    leftColumn
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    rightRail
                        .frame(width: 360)
                }
            }
        }
        .frame(width: 1240, height: 760)
        .ljScreenBackground(.macOS)
    }

    // MARK: - 顶栏样张（居中玻璃分段 pill + 右上图标簇）

    private var topBar: some View {
        HStack(spacing: 0) {
            HStack {
                Text(verbatim: "LinoJ")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.lj.inkMute)
                Spacer(minLength: 0)
            }
            .frame(width: 210)
            .padding(.leading, 64)

            // 居中玻璃分段 pill。
            HStack(spacing: 2) {
                navItem("主页", icon: "house.fill", active: true)
                Rectangle().fill(Color.lj.borderStrong).frame(width: 1, height: 18).padding(.horizontal, 5)
                navItem("个人", icon: "person", active: false)
                navItem("公司", icon: "building.2", active: false)
                navItem("日历", icon: "calendar", active: false)
                navItem("灵感", icon: "lightbulb", active: false)
            }
            .padding(4)
            .background { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.regularMaterial) }
            .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.lj.border, lineWidth: 0.5) }
            .overlay { LJTopHighlight(radius: 13) }
            .shadow(color: Color.lj.shadowCard, radius: 4, x: 0, y: 2)
            .frame(maxWidth: .infinity)

            HStack(spacing: LJSpacing.s8) {
                Spacer(minLength: 0)
                iconBtn("magnifyingglass")
                iconBtn("gearshape")
                Circle().fill(LJGradients.brand).frame(width: 30, height: 30)
                    .overlay { Text(verbatim: "L").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white) }
                    .shadow(color: Color.lj.brandGlow, radius: 3, x: 0, y: 2)
            }
            .frame(width: 210)
        }
        .padding(.horizontal, LJSpacing.s16)
        .frame(height: 52)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.lj.border).frame(height: 0.5) }
    }

    private func navItem(_ label: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.lj.accentDeep : Color.lj.inkSoft)
            Text(verbatim: label)
                .font(.system(size: 13.5, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.lj.ink : Color.lj.inkSoft)
        }
        .padding(.horizontal, 13).padding(.vertical, 6)
        .background { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(active ? Color.lj.navSelected : Color.clear) }
    }

    private func iconBtn(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .medium)).foregroundStyle(Color.lj.inkSoft)
            .frame(width: 32, height: 32)
            .background { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.regularMaterial) }
            .overlay { RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.lj.border, lineWidth: 0.5) }
            .overlay { LJTopHighlight(radius: 9) }
            .shadow(color: Color.lj.shadowCard, radius: 3, x: 0, y: 2)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: LJSpacing.s16) {
            HeadsUpAlert(event: sampleEvent, minutesUntil: 10)

            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s16) {
                Text(verbatim: "待办").ljDisplayTitleStyle()
                HStack(spacing: 0) {
                    Text(verbatim: "14 个待办").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.lj.inkSoft)
                    Text(verbatim: " · ").font(.system(size: 13)).foregroundStyle(Color.lj.inkDim)
                    Text(verbatim: "5").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.lj.blue)
                    Text(verbatim: " 个紧急").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.lj.inkSoft)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: LJSpacing.s18) {
                column(label: "紧急", urgent: true, items: [
                    todo("回复妈妈周六安排", .urgent, .personal),
                    todo("把存款转入高息账户", .urgent, .personal),
                    todo("提交 Q1 报销单", .urgent, .company, project: "LinoJ macOS"),
                    todo("敲定 macOS 侧栏规格", .urgent, .company, project: "LinoJ macOS"),
                ])
                column(label: "普通", urgent: false, items: [
                    todo("读《人类简史》第 3 章", .normal, .personal),
                    todo("续健身房会员", .normal, .personal),
                    todo("取干洗衣物", .normal, .personal),
                    todo("写发布说明草稿", .normal, .company, project: "Onboarding"),
                ])
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, LJSpacing.s28)
        .padding(.vertical, LJSpacing.s22)
    }

    private func column(label: String, urgent: Bool, items: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s10) {
            HStack(spacing: LJSpacing.s10) {
                Circle()
                    .fill(urgent ? Color.lj.blue : Color.lj.inkMute)
                    .frame(width: 8, height: 8)
                Text(verbatim: label)
                    .font(.lj.sectionHeader)
                    .foregroundStyle(urgent ? Color.lj.blueInk : Color.lj.ink)
                Text(verbatim: "\(items.count)")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.lj.inkMute)
                Spacer()
            }
            VStack(spacing: LJSpacing.s8) {
                ForEach(items, id: \.id) { t in
                    TodoBubble(todo: t, showSource: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var rightRail: some View {
        // v1.3 R1 重做样张：日分组格式（今日高亮圆角行 + 星期+日期号同行 + mono 时间+标题）
        // + 底部整合进同面板的「昨天遗漏」虚线框。
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "未来 7 天")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.lj.ink)
                .padding(.bottom, LJSpacing.s14)

            VStack(spacing: 2) {
                dayGroup("今天", "27", today: true, events: [("10:30", "与 Mei 的 1:1"), ("14:00", "设计评审 — 侧栏")])
                dayGroup("周三", "29", today: false, events: [("09:00", "Onboarding 评审"), ("11:30", "Q3 拍板评审")])
                dayGroup("周四", "30", today: false, events: [("10:00", "工程同步"), ("12:00", "与 Andrew 午餐")])
            }

            // 「昨天遗漏」整合进同面板底部（虚线框）。
            VStack(alignment: .leading, spacing: LJSpacing.s8) {
                Text(verbatim: "昨天遗漏")
                    .font(.system(size: 11, weight: .bold)).kerning(0.88).textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.lj.inkMute, lineWidth: 1.5).frame(width: 16, height: 16)
                    Text(verbatim: "16:00").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.lj.inkMute)
                    Text(verbatim: "团队复盘").font(.system(size: 12.5)).foregroundStyle(Color.lj.inkSoft)
                    Spacer()
                }
            }
            .padding(.horizontal, LJSpacing.s14).padding(.vertical, LJSpacing.s12)
            .background { RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous).fill(Color.lj.chip) }
            .ljDashedBorder()
            .padding(.top, LJSpacing.s14)
        }
        .padding(LJSpacing.s18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ljGlassPanel(radius: LJRadii.panel, padded: false)
        .padding(LJSpacing.s16)
    }

    private func dayGroup(_ label: String, _ date: String, today: Bool, events: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: LJSpacing.s8) {
                Text(verbatim: label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(today ? Color.lj.accentDeep : Color.lj.ink)
                Text(verbatim: date)
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(Color.lj.inkMute)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(events, id: \.0) { ev in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(verbatim: ev.0)
                            .font(.system(size: 11, weight: .medium, design: .monospaced)).monospacedDigit()
                            .foregroundStyle(today ? Color.lj.accent : Color.lj.inkSoft)
                            .frame(width: 34, alignment: .leading)
                        Text(verbatim: ev.1).font(.system(size: 12.5)).foregroundStyle(Color.lj.inkSoft).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { RoundedRectangle(cornerRadius: 9, style: .continuous).fill(today ? Color.lj.navSelected.opacity(0.62) : Color.clear) }
    }
}
#endif
