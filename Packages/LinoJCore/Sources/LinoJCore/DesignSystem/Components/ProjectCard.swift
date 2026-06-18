// ProjectCard.swift
// Project 卡片，四种 variant：macStrip / macFull / iosMini / iosFull。
//
// P2 阶段只渲染 placeholder 数据（"0 todos · 0 events"），等 P3.3 引入 ViewModel
// 后由调用方自己注入真实计数。

import SwiftUI

public struct ProjectCard: View {
    public enum Variant: Hashable {
        case macStrip
        case macFull
        case iosMini
        case iosFull
    }

    private let project: Project
    private let variant: Variant
    /// P6：macFull 响应式开关 —— 调用方（CompanyView）读窗口宽度，
    /// < 1200pt 传 compact=true，渲染为 2-row 布局；其它情况保持原 3-col。
    /// 仅对 `.macFull` 有效，其它 variant 忽略。
    private let compact: Bool

    public init(project: Project, variant: Variant, compact: Bool = false) {
        self.project = project
        self.variant = variant
        self.compact = compact
    }

    public var body: some View {
        switch variant {
        case .macStrip: macStripBody
        case .macFull:  macFullBody
        case .iosMini:  iosMiniBody
        case .iosFull:  iosFullBody
        }
    }

    // MARK: macOS strip row（Main 底部 pinned）

    private var macStripBody: some View {
        // README 规定 1fr 200pt 110pt grid。SwiftUI 没有 native grid 列权重，
        // 这里用 HStack + 固定宽度近似。
        HStack(alignment: .top, spacing: LJSpacing.s16) {
            // 左：title + intro + tag
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: LJSpacing.s8) {
                    Text(project.title).ljCardTitleStyle()
                    Text(project.tag).ljTagPill()
                }
                Text(project.intro)
                    .ljCaptionStyle()
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 中：mono stats（P2 placeholder）
            Text("0 todos · 0 events")
                .ljMonoStyle()
                .frame(width: 200, alignment: .leading)

            // 右：AvatarStack
            AvatarStack(people: project.members ?? [])
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, LJSpacing.s10)
        .contentShape(Rectangle())
        .ljHoverLift()
    }

    // MARK: macOS full rich card（Company tab 主体）

    /// v1.3 R3（对原型重建）：富项目卡 = 容器玻璃面板（圆角 16 + hairline + 顶高光 + 柔投影），
    /// 网格 `1.5fr 1fr 1fr`（左 tag+标题+intro+avatar / 中 todos 点列表 / 右 linked events 紫点），
    /// 列间 0.5px hairline 竖分隔。
    /// P6 响应式：compact=true 走 2-row 布局（上行 hero / 下行 todos|events 横向二分 + 竖分隔）。
    /// 由调用方（CompanyView）从外层 GeometryReader 读窗口宽度后决定 —— 不用本组件内 GeometryReader。
    @ViewBuilder
    private var macFullBody: some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: LJSpacing.s14) {
                    heroBlock()
                    Rectangle().fill(Color.lj.border).frame(height: 0.5)
                    HStack(alignment: .top, spacing: 0) {
                        todosBlock()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, LJSpacing.s16)
                        columnDivider()
                        eventsBlock()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, LJSpacing.s16)
                    }
                }
            } else {
                // 1.5fr | 1fr | 1fr 三列，列间 0.5px 竖 hairline（原型 grid-template-columns:1.5fr 1fr 1fr gap:22）。
                HStack(alignment: .top, spacing: 0) {
                    heroBlock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1.5)
                        .padding(.trailing, LJSpacing.s22)
                    columnDivider()
                    todosBlock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LJSpacing.s22)
                    columnDivider()
                    eventsBlock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, LJSpacing.s22)
                }
            }
        }
        // 容器级玻璃面板（圆角 16 + hairline + 顶高光 + 柔投影），从底色 / orb 上浮起。
        .ljGlassPanel(radius: 16)
        .ljHoverLift()
    }

    /// 富卡列间 0.5px 竖 hairline 分隔（原型列分隔）。
    @ViewBuilder
    private func columnDivider() -> some View {
        Rectangle()
            .fill(Color.lj.border)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
    }

    /// macFull 左列 / 上行 —— status tag + title + intro + members + member 计数。
    @ViewBuilder
    private func heroBlock() -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            // 状态 tag（原型：uppercase #6E63E6 on scopeCompanyBg 软底，10px/700/0.05em，圆角 5）。
            statusTag(project.tag)
            Text(project.title)
                .font(.system(size: 17, weight: .semibold, design: .default))
                .kerning(-0.34)
                .foregroundStyle(Color.lj.ink)
            Text(project.intro)
                .font(.system(size: 12.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(3)
            Spacer(minLength: LJSpacing.s8)
            HStack(spacing: LJSpacing.s10) {
                AvatarStack(people: project.members ?? [])
                Text("\(project.memberCount) member\(project.memberCount == 1 ? "" : "s")")
                    .font(.system(size: 11.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
            }
        }
    }

    /// 状态 tag 胶囊（原型富卡：紫字 + scopeCompanyBg 软底 + 圆角 5 + uppercase）。
    @ViewBuilder
    private func statusTag(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 10, weight: .bold, design: .default))
            .kerning(0.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.lj.accent)
            .padding(.horizontal, LJSpacing.s8)
            .padding(.vertical, 2)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.lj.scopeCompanyBg)
            }
    }

    /// macFull 中列 / 下行左半 —— Todos 计数 + 点列表预览（对原型重建）。
    /// 原型：「待办 N · 紧急 M」单行 header（N accent / 11px/600/0.03em）+ 13px 方框 outline + 标题点列表。
    @ViewBuilder
    private func todosBlock() -> some View {
        // 实时读项目关系上的 todos。
        let openTodos = (project.todos ?? []).filter { !$0.done }
        let urgentTodos = openTodos.filter { $0.urgency == .urgent }

        VStack(alignment: .leading, spacing: LJSpacing.s10) {
            // header：「待办 N · 紧急 M」（N accent；中英语序由词条吞）。
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(LJStrings.todos)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .kerning(0.33)
                    .foregroundStyle(Color.lj.inkMute)
                Text("\(openTodos.count)")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color.lj.accent)
                Text(verbatim: " · ")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkDim)
                Text(LJStrings.statUrgent)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .kerning(0.33)
                    .foregroundStyle(Color.lj.inkMute)
                Text("\(urgentTodos.count)")
                    .font(.system(size: 11, weight: .bold, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach((project.todos ?? []).prefix(4), id: \.id) { todo in
                    HStack(alignment: .top, spacing: LJSpacing.s8) {
                        // 13px 方框 outline（原型 13×13 圆角4 1.5px rgba(60,60,67,0.28)）。
                        ZStack {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(
                                    todo.urgency == .urgent ? Color.lj.accent.opacity(0.55) : Color.lj.inkMute,
                                    lineWidth: 1.5
                                )
                                .frame(width: 13, height: 13)
                            if todo.done {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(todo.urgency == .urgent ? Color.lj.accent : Color.lj.ink)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        .padding(.top, 1)
                        Text(todo.title)
                            .font(.system(
                                size: 12.5,
                                weight: todo.urgency == .urgent ? .semibold : .medium,
                                design: .default
                            ))
                            .foregroundStyle(Color.lj.inkSoft)
                            .strikethrough(todo.done, color: Color.lj.inkMute)
                            .lineLimit(1)
                            .opacity(todo.done ? 0.4 : 1)
                    }
                }
            }
        }
    }

    /// macFull 右列 / 下行右半 —— Linked events 紫点列表（对原型重建）。
    /// 原型：「关联日程」header（11px/600/0.03em）+ 紫 5px 圆点 + 事件标题点列表。
    @ViewBuilder
    private func eventsBlock() -> some View {
        let sortedEvents = (project.events ?? []).sorted { $0.start < $1.start }

        VStack(alignment: .leading, spacing: LJSpacing.s10) {
            Text(LJStrings.linkedEvents)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .kerning(0.33)
                .foregroundStyle(Color.lj.inkMute)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sortedEvents, id: \.id) { event in
                    HStack(alignment: .center, spacing: LJSpacing.s8) {
                        // 紫 5px 圆点（原型 #8A6DF0）。
                        Circle()
                            .fill(Color.lj.purpleDot)
                            .frame(width: 5, height: 5)
                        Text(event.title)
                            .font(.system(size: 12.5, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkSoft)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    /// "Tue · 09:30" 格式 —— Linked events 行左侧 mono 时间戳。
    private func eventDayTimeText(_ event: Event) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return "\(dayFormatter.string(from: event.start)) · \(timeFormatter.string(from: event.start))"
    }

    // MARK: iOS mini card（横向 scroll）

    private var iosMiniBody: some View {
        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            Text(project.tag).ljTagPill()
            Text(project.title).ljCardTitleStyle().lineLimit(2)
            Text(project.intro)
                .font(.lj.caption)
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(2)
            Spacer(minLength: 0)
            AvatarStack(people: project.members ?? [], max: 4)
        }
        .frame(width: 240, alignment: .leading)
        .frame(minHeight: 150, alignment: .topLeading)
        .ljCardStyle()
    }

    // MARK: iOS full stacked card

    private var iosFullBody: some View {
        // 实时计数。
        let openTodos = (project.todos ?? []).filter { !$0.done }
        let urgentTodos = openTodos.filter { $0.urgency == .urgent }
        let sortedEvents = (project.events ?? []).sorted { $0.start < $1.start }

        return VStack(alignment: .leading, spacing: LJSpacing.s10) {
            // 标题 + tag
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s8) {
                Text(project.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .kerning(-0.24)
                    .foregroundStyle(Color.lj.ink)
                Text(project.tag).ljTagPill()
                Spacer(minLength: 0)
            }
            Text(project.intro)
                .ljBodyStyle()
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(3)

            // Stats row
            // I2: 完全本地化。中英语序天然差异由 LJStrings.* 词条吞掉。
            HStack(spacing: LJSpacing.s14) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(openTodos.count)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(urgentTodos.isEmpty ? Color.lj.ink : Color.lj.blue)
                    if urgentTodos.isEmpty {
                        Text(LJStrings.todos)
                            .font(.system(size: 11.5, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkSoft)
                    } else {
                        HStack(spacing: 0) {
                            Text("\(String(localized: LJStrings.todos)) · ")
                                .font(.system(size: 11.5, weight: .medium, design: .default))
                                .foregroundStyle(Color.lj.inkSoft)
                            Text(LJStrings.projectCardUrgentSuffix(urgentTodos.count))
                                .font(.system(size: 11.5, weight: .semibold, design: .default))
                                .foregroundStyle(Color.lj.blue)
                        }
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(sortedEvents.count)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.lj.ink)
                    Text(LJStrings.statEvents)
                        .font(.system(size: 11.5, weight: .medium, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                }
                Spacer()
                AvatarStack(people: project.members ?? [], max: 3)
            }

            // Linked events preview
            if !sortedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(Color.lj.border).frame(height: 0.5)
                        .padding(.vertical, 2)
                    Text(LJStrings.linkedEvents)
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.lj.inkMute)
                    ForEach(sortedEvents.prefix(2), id: \.id) { event in
                        HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                            Text(eventDayTimeText(event))
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.lj.inkMute)
                                .frame(width: 80, alignment: .leading)
                            Text(event.title)
                                .font(.system(size: 12.5, weight: .medium, design: .default))
                                .foregroundStyle(Color.lj.ink)
                                .lineLimit(1)
                        }
                    }
                    if sortedEvents.count > 2 {
                        // "+N more" 复用 Counts.moreEvents（已存在）。
                        Text(String(localized: "Counts.moreEvents",
                                    defaultValue: "+\(sortedEvents.count - 2) more",
                                    bundle: LinoJCoreBundle.bundle))
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundStyle(Color.lj.inkMute)
                            .padding(.leading, 90)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ljCardStyle()
    }
}

// MARK: - Preview

#if DEBUG
private func sampleProject() -> Project {
    Project(
        title: "LinoJ for macOS v1",
        intro: "Ship a calm, fast macOS planner that separates events from todos.",
        notes: "Open questions: sidebar density.",
        tag: "Shipping June",
        members: [Person(name: "Mei"), Person(name: "Andrew"), Person(name: "Kai")],
        createdAt: Date()
    )
}

#Preview("macStrip", traits: .sizeThatFitsLayout) {
    ProjectCard(project: sampleProject(), variant: .macStrip)
        .padding(LJSpacing.s16)
        .frame(width: 900)
        .background(Color.lj.bg)
}

#Preview("macFull", traits: .sizeThatFitsLayout) {
    ProjectCard(project: sampleProject(), variant: .macFull)
        .padding(LJSpacing.s16)
        .frame(width: 900)
        .background(Color.lj.bg)
}

#Preview("macFull compact (P6 < 1200pt)", traits: .sizeThatFitsLayout) {
    ProjectCard(project: sampleProject(), variant: .macFull, compact: true)
        .padding(LJSpacing.s16)
        .frame(width: 720)
        .background(Color.lj.bg)
}

#Preview("iosMini", traits: .sizeThatFitsLayout) {
    ProjectCard(project: sampleProject(), variant: .iosMini)
        .padding(LJSpacing.s16)
        .background(Color.lj.iosMainBg)
}

#Preview("iosFull", traits: .sizeThatFitsLayout) {
    ProjectCard(project: sampleProject(), variant: .iosFull)
        .padding(LJSpacing.s16)
        .frame(width: 380)
        .background(Color.lj.iosMainBg)
}
#endif
