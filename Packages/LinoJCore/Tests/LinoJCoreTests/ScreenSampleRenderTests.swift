// ScreenSampleRenderTests.swift
// v1.3 R2–R6 视觉自检：用 ImageRenderer 把各重建屏的视觉件组合离屏渲染成 PNG，
// 供 builder 与 design_handoff_linoj_frontend 参考图并排对图（不依赖屏幕截图通道，锁屏下也能跑）。
//
// 与 MainSampleRenderTests 同思路（真实 R0/R1/R2–R6 件 + 真实模型实例，按原型布局拼）：
//   真实 App 屏的 VM 在 `.task` 中初始化，ImageRenderer 同步快照不触发 `.task` → 渲染不出内容，
//   故沿用 R1 的「手拼视觉样张」路线，验证布局 / 结构 / 配色 / 玻璃件，而非跑活 View。
//   材质毛玻璃真实模糊度离屏保真有限（偏白实），真机定终态。
//
// 仅 macOS 跑；产物固定写到 /tmp/linoj_fe/app_<screen>_sample.png。

#if os(macOS)
import SwiftUI
import Testing
@testable import LinoJCore

@MainActor
@Suite("v1.3 R2–R6 屏视觉样张离屏渲染")
struct ScreenSampleRenderTests {

    private func renderPNG(_ view: some View, w: CGFloat, h: CGFloat, name: String) throws {
        let renderer = ImageRenderer(content: view.frame(width: w, height: h))
        renderer.scale = 2.0
        renderer.isOpaque = true
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            Issue.record("PNG 编码失败：\(name)")
            return
        }
        let url = URL(fileURLWithPath: "/tmp/linoj_fe/\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("R2 Personal 样张")
    func renderPersonal() throws {
        try renderPNG(PersonalSample(), w: 1240, h: 760, name: "app_personal_sample")
    }

    @Test("R3 Company 样张")
    func renderCompany() throws {
        try renderPNG(CompanySample(), w: 1240, h: 760, name: "app_company_sample")
    }

    @Test("R4 Calendar 样张")
    func renderCalendar() throws {
        try renderPNG(CalendarSample(), w: 1240, h: 760, name: "app_calendar_sample")
    }

    @Test("R5 Inspiration 样张")
    func renderInspiration() throws {
        try renderPNG(InspirationSample(), w: 1240, h: 760, name: "app_inspiration_sample")
    }

    @Test("R6 QuickAdd 样张")
    func renderQuickAdd() throws {
        try renderPNG(QuickAddSample(), w: 760, h: 620, name: "app_quickadd_sample")
    }
}

// MARK: - 共享 helpers

private func todo(_ title: String, _ u: Urgency, _ s: Scope, project: String? = nil, done: Bool = false) -> Todo {
    let p = project.map { Project(title: $0, intro: "", notes: "", tag: "", createdAt: .now) }
    return Todo(title: title, urgency: u, scope: s, project: p, done: done)
}

/// 子页头部标题 + 计数行 + 品牌渐变主按钮（R2/R3 通用）。
private struct ScreenHeaderSample: View {
    let title: String
    let counts: [(String, Color)]
    let buttonTitle: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title).ljDisplayTitleStyle()
                HStack(spacing: 0) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { i, c in
                        if i > 0 {
                            Text(verbatim: " · ").font(.system(size: 13)).foregroundStyle(Color.lj.inkDim)
                        }
                        Text(verbatim: c.0).font(.system(size: 13, weight: .medium)).foregroundStyle(c.1)
                    }
                }
            }
            Spacer(minLength: 16)
            LJPrimaryButton(LocalizedStringResource(stringLiteral: buttonTitle)) {}
        }
    }
}

private struct KanbanColumnSample: View {
    let label: String
    let urgent: Bool
    let items: [Todo]
    let showSource: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(urgent ? Color.lj.blue : Color.lj.inkMute).frame(width: 8, height: 8)
                Text(verbatim: label).font(.lj.sectionHeader).foregroundStyle(urgent ? Color.lj.blueInk : Color.lj.ink)
                Text(verbatim: "\(items.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.lj.inkMute)
                Spacer()
            }
            VStack(spacing: 8) {
                ForEach(items, id: \.id) { TodoBubble(todo: $0, showSource: showSource) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - R2 Personal

private struct PersonalSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScreenHeaderSample(
                title: "个人",
                counts: [("3 个待办", Color.lj.inkSoft), ("2 个紧急", Color.lj.blue), ("2 已完成", Color.lj.inkSoft)],
                buttonTitle: "新建个人待办"
            )
            HStack(alignment: .top, spacing: 18) {
                KanbanColumnSample(label: "紧急", urgent: true, items: [
                    todo("回复妈妈", .urgent, .personal),
                    todo("把存款转入高息账户", .urgent, .personal),
                ], showSource: false)
                KanbanColumnSample(label: "普通", urgent: false, items: [
                    todo("读《人类简史》第 3 章", .normal, .personal),
                    todo("续健身房会员", .normal, .personal),
                    todo("取干洗衣物", .normal, .personal),
                ], showSource: false)
            }
            // completed box（虚线框）。
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(verbatim: "已完成 (2)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.lj.inkSoft)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.lj.inkMute)
                }
            }
            .padding(14)
            .ljCompletedBoxStyle()
            .frame(maxWidth: 1100, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 28).padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ljScreenBackground(.macOS)
    }
}

// MARK: - R3 Company

private struct CompanySample: View {
    private func sampleProject() -> Project {
        let p = Project(title: "LinoJ macOS v1", intro: "原生 Swift 计划工具。个人、工作、时间汇成一个安静工作台。",
                        notes: "", tag: "6月发布",
                        members: [Person(name: "Lino"), Person(name: "Mei"), Person(name: "Alex")], createdAt: .now)
        let t1 = todo("敲定 macOS 侧栏规格", .urgent, .company); t1.project = p
        let t2 = todo("打磨空状态", .normal, .company); t2.project = p
        let t3 = todo("审计颜色 token", .normal, .company); t3.project = p
        p.todos = [t1, t2, t3]
        let e1 = Event(title: "设计评审 — 侧栏", start: .now, end: .now.addingTimeInterval(3600), location: "会议室 A"); e1.project = p
        let e2 = Event(title: "LinoJ kickoff v2", start: .now, end: .now.addingTimeInterval(3600), location: "会议室 A"); e2.project = p
        p.events = [e1, e2]
        return p
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeaderSample(
                title: "公司",
                counts: [("9 个待办", Color.lj.inkSoft), ("3 个紧急", Color.lj.blue), ("3 个项目", Color.lj.inkSoft)],
                buttonTitle: "新建公司事项"
            )
            // scope chips。
            HStack(spacing: 6) {
                chip("全部", selected: true)
                chip("独立", selected: false)
                chip("LinoJ", selected: false)
                chip("Onboarding 改版", selected: false)
                Spacer()
            }
            HStack(alignment: .top, spacing: 18) {
                KanbanColumnSample(label: "紧急", urgent: true, items: [
                    todo("提交 Q1 报销单", .urgent, .company),
                    todo("敲定 macOS 侧栏规格", .urgent, .company, project: "LinoJ"),
                ], showSource: false)
                KanbanColumnSample(label: "普通", urgent: false, items: [
                    todo("审阅法务红线", .normal, .company),
                    todo("批准设计系统 PR", .normal, .company),
                ], showSource: false)
            }
            HStack(alignment: .center, spacing: 10) {
                Text(verbatim: "项目").font(.system(size: 12, weight: .semibold)).kerning(0.48).textCase(.uppercase).foregroundStyle(Color.lj.inkMute)
                Spacer()
                LJSecondaryButton(LJStrings.newProject) {}
            }
            ProjectCard(project: sampleProject(), variant: .macFull)
            Spacer()
        }
        .padding(.horizontal, 28).padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ljScreenBackground(.macOS)
    }
    private func chip(_ label: String, selected: Bool) -> some View {
        Text(verbatim: label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(selected ? Color.white : Color.lj.inkSoft)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background { Capsule().fill(selected ? AnyShapeStyle(Color.lj.ink) : AnyShapeStyle(.ultraThinMaterial)) }
            .overlay { if !selected { Capsule().strokeBorder(Color.lj.borderStrong, lineWidth: 0.5) } }
    }
}

// MARK: - R4 Calendar（周网格玻璃面板片段）

private struct CalendarSample: View {
    private let days = ["周二","周三","周四","周五","周六","周日","周一"]
    private let dates = ["27","28","29","30","31","1","2"]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "日历").ljDisplayTitleStyle()
                    Text(verbatim: "未来 7 天 16 场事件").font(.system(size: 12.5, weight: .medium)).foregroundStyle(Color.lj.inkSoft)
                }
                Spacer()
                Text(verbatim: "5月27 — 6月2").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.lj.ink)
                LJPrimaryButton(LJStrings.newEventTitle) {}
            }
            .padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 16)

            // 玻璃面板内：表头行 + 网格。
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: 52, height: 1)
                    ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                        let isToday = i == 0
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: isToday ? "今天" : d.uppercased())
                                .font(.system(size: 10.5, weight: .semibold)).kerning(0.63)
                                .foregroundStyle(isToday ? Color.lj.accentDeep : Color.lj.inkMute)
                            Text(verbatim: dates[i]).font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isToday ? Color.lj.accentDeep : Color.lj.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
                Rectangle().fill(Color.lj.border).frame(height: 0.5)
                gridBody
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ljGlassPanel(radius: LJRadii.panel, padded: false)
            .padding(.horizontal, 28).padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ljScreenBackground(.macOS)
    }
    private var gridBody: some View {
        let pxPerHour: CGFloat = 44
        let total = pxPerHour * 6
        return HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(7..<13, id: \.self) { h in
                    Text(verbatim: "\(h) AM").font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.lj.inkMute).frame(height: pxPerHour, alignment: .top)
                }
            }
            .frame(width: 52)
            ForEach(0..<7, id: \.self) { col in
                ZStack(alignment: .topLeading) {
                    if col == 0 { Color.lj.navSelected.opacity(0.4).frame(height: total) }
                    Rectangle().fill(Color.lj.border).frame(width: 0.5, height: total)
                    if col == 0 {
                        eventBlock("9:30", "晨会", project: true).offset(y: 22)
                        eventBlock("14:00", "设计评审 — 侧栏", project: true).offset(y: 44 * 3 + 2)
                    } else if col == 1 {
                        eventBlock("10:00", "Onboarding 评审", project: true).offset(y: 44 * 1 + 2)
                    } else if col == 2 {
                        eventBlock("12:00", "与 Andrew 午餐", project: false).offset(y: 44 * 2 + 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading).frame(height: total)
            }
        }
    }
    private func eventBlock(_ time: String, _ title: String, project: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle().fill(project ? Color.lj.purpleDot : Color.lj.inkMute).frame(width: 2.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: time).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).foregroundStyle(Color.lj.inkSoft)
                Text(verbatim: title).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color.lj.ink).lineLimit(1)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .background { RoundedRectangle(cornerRadius: 8).fill(Color.lj.panel) }
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.lj.border, lineWidth: 0.5) }
        .shadow(color: Color.lj.shadowCard, radius: 2, y: 1)
        .padding(.horizontal, 4)
    }
}

// MARK: - R5 Inspiration（masonry 笔记墙）

private struct InspirationSample: View {
    private func note(_ title: String, _ body: String, pinned: Bool = false) -> Note {
        let n = Note(body: AttributedString("\(title)\n\(body)"))
        n.isPinned = pinned
        return n
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "灵感").ljDisplayTitleStyle()
                    Text(verbatim: "随手记下的念头、清单与片段").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.lj.inkSoft)
                }
                Spacer(minLength: 16)
                LJPrimaryButton(LJStrings.recordIdea) {}
            }
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    NoteCard(note: note("产品命名", "LinoJ 留着。J = Journal + Join，把日志和连接合在一起。", pinned: true))
                    NoteCard(note: note("配色实验", "靛蓝→紫渐变在深色下更亮；亮色要压一档饱和度。"))
                }.frame(maxWidth: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: 16) {
                    NoteCard(note: note("一句话灵魂", "把「时间」和「待办」彻底分开——有钟点的是日程，没钟点的是待办。"))
                    NoteCard(note: note("周末读书", "《Thinking in Systems》《人类简史》第四部分。"))
                }.frame(maxWidth: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: 16) {
                    NoteCard(note: note("1:1 模板", "上周高光 · 当前卡点 · 这周重点 · 需要我的支持。"))
                    NoteCard(note: note("空状态文案", "别用「暂无数据」。要像朋友说话。"))
                }.frame(maxWidth: .infinity, alignment: .top)
            }
            Spacer()
        }
        .padding(.horizontal, 28).padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ljScreenBackground(.macOS)
    }
}

// MARK: - R6 QuickAdd modal

private struct QuickAddSample: View {
    var body: some View {
        // scrim + 居中玻璃卡。
        ZStack {
            Color.black.opacity(0.32)
            VStack(spacing: 0) {
                // header：标题 + scope pill。
                HStack(spacing: 12) {
                    Text(verbatim: "New").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.lj.ink)
                    Text(verbatim: "公司").font(.system(size: 10.5, weight: .bold)).kerning(0.5).foregroundStyle(Color.lj.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background { RoundedRectangle(cornerRadius: 6).fill(Color.lj.scopeCompanyBg) }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                Divider().overlay(Color.lj.border)
                VStack(alignment: .leading, spacing: 14) {
                    Text(verbatim: "敲定 macOS 侧栏规格").font(.system(size: 22, weight: .semibold)).foregroundStyle(Color.lj.ink)
                    HStack(spacing: 8) {
                        pill("紧急", on: true, brand: true)
                        pill("普通", on: false, brand: false)
                        Divider().frame(height: 18).overlay(Color.lj.border)
                        pill("个人", on: false, brand: false)
                        pill("公司", on: true, brand: false)
                    }
                    Spacer()
                }
                .padding(18)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                Divider().overlay(Color.lj.border)
                HStack(spacing: 8) {
                    Text(verbatim: "esc 取消 · ⌘↵ 创建").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.lj.inkMute)
                    Spacer()
                    Text(verbatim: "创建").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.lj.bg)
                        .padding(.horizontal, 22).padding(.vertical, 7)
                        .background { RoundedRectangle(cornerRadius: 7).fill(Color.lj.ink) }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.lj.bgSoft)
            }
            .frame(width: 520, height: 460)
            .background(.regularMaterial)
            .overlay { LJTopHighlight(radius: LJRadii.modalMac) }
            .clipShape(RoundedRectangle(cornerRadius: LJRadii.modalMac, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: LJRadii.modalMac, style: .continuous).strokeBorder(Color.lj.border, lineWidth: 0.5) }
            .shadow(color: Color.black.opacity(0.4), radius: 40, y: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ljScreenBackground(.macOS)
    }
    private func pill(_ label: String, on: Bool, brand: Bool) -> some View {
        HStack(spacing: 5) {
            if brand && on { Circle().fill(Color.lj.blue).frame(width: 6, height: 6) }
            Text(verbatim: label).font(.system(size: 11.5, weight: on ? .bold : .medium))
                .foregroundStyle(on ? (brand ? Color.lj.blueInk : Color.lj.ink) : Color.lj.inkSoft)
        }
        .padding(.horizontal, 11).padding(.vertical, 4)
        .background { RoundedRectangle(cornerRadius: 999).fill(on ? (brand ? Color.lj.blueSoft : Color.lj.chip) : Color.clear) }
        .overlay { RoundedRectangle(cornerRadius: 999).strokeBorder(on ? (brand ? Color.lj.blueBorder : Color.lj.borderStrong) : Color.lj.border, lineWidth: 0.5) }
    }
}
#endif
