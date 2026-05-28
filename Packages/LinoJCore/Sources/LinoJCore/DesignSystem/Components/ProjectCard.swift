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

    /// P6 响应式：compact=true 时走 2-row 布局（上行 hero / 下行 todos + events 二分），
    /// compact=false 走原 3-col 布局（1.4fr 1fr 1fr）。
    /// 由调用方（CompanyView）从外层 GeometryReader 读窗口宽度后决定 —— 不用本组件内
    /// GeometryReader，避免破坏 VStack 内的自适应高度。
    @ViewBuilder
    private var macFullBody: some View {
        if compact {
            VStack(alignment: .leading, spacing: LJSpacing.s14) {
                heroBlock()
                Rectangle().fill(Color.lj.border).frame(height: 0.5)
                HStack(alignment: .top, spacing: LJSpacing.s22) {
                    todosBlock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    eventsBlock()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .ljCardStyle()
            .ljHoverLift()
        } else {
            HStack(alignment: .top, spacing: LJSpacing.s22) {
                heroBlock()
                    .frame(maxWidth: .infinity, alignment: .leading)
                todosBlock()
                    .frame(maxWidth: .infinity, alignment: .leading)
                eventsBlock()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .ljCardStyle()
            .ljHoverLift()
        }
    }

    /// macFull 左列 / 上行 —— title + tag + intro + members + member 计数。
    @ViewBuilder
    private func heroBlock() -> some View {
        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s10) {
                Text(project.title).ljCardTitleStyle()
                Text(project.tag).ljTagPill()
            }
            Text(project.intro)
                .ljBodyStyle()
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(3)
            Spacer(minLength: 0)
            HStack(spacing: LJSpacing.s10) {
                AvatarStack(people: project.members ?? [])
                Text("\(project.memberCount) member\(project.memberCount == 1 ? "" : "s")")
                    .font(.system(size: 11.5, weight: .medium, design: .default))
                    .foregroundStyle(Color.lj.inkMute)
            }
        }
    }

    /// macFull 中列 / 下行左半 —— Todos 计数 + 前 4 行预览。
    @ViewBuilder
    private func todosBlock() -> some View {
        // 实时读项目关系上的 todos。
        let openTodos = (project.todos ?? []).filter { !$0.done }
        let urgentTodos = openTodos.filter { $0.urgency == .urgent }

        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // I2: "Todos" / "待办"
                Text(LJStrings.todos)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                Text("\(openTodos.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.lj.ink)
                if !urgentTodos.isEmpty {
                    // I2: "X urgent" / "X 紧急"
                    Text(LJStrings.projectCardUrgentSuffix(urgentTodos.count))
                        .font(.system(size: 10.5, weight: .semibold, design: .default))
                        .foregroundStyle(Color.lj.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.lj.blueSoft)
                        }
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach((project.todos ?? []).prefix(4), id: \.id) { todo in
                    HStack(alignment: .top, spacing: LJSpacing.s8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(
                                    todo.urgency == .urgent ? Color.lj.blue : Color.lj.inkMute,
                                    lineWidth: 1.2
                                )
                                .frame(width: 12, height: 12)
                            if todo.done {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(todo.urgency == .urgent ? Color.lj.blue : Color.lj.ink)
                                    .frame(width: 7, height: 7)
                            }
                        }
                        .padding(.top, 2)
                        Text(todo.title)
                            .font(.system(
                                size: 12.5,
                                weight: todo.urgency == .urgent ? .semibold : .medium,
                                design: .default
                            ))
                            .foregroundStyle(Color.lj.ink)
                            .strikethrough(todo.done, color: Color.lj.inkMute)
                            .lineLimit(2)
                            .opacity(todo.done ? 0.4 : 1)
                    }
                }
            }
        }
    }

    /// macFull 右列 / 下行右半 —— Linked events 计数 + 全部按时间排序的事件 row。
    @ViewBuilder
    private func eventsBlock() -> some View {
        let sortedEvents = (project.events ?? []).sorted { $0.start < $1.start }

        VStack(alignment: .leading, spacing: LJSpacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // I2: "Linked events" / "关联事件"
                Text(LJStrings.linkedEvents)
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.lj.inkMute)
                Text("\(sortedEvents.count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.lj.ink)
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(sortedEvents, id: \.id) { event in
                    HStack(alignment: .top, spacing: LJSpacing.s10) {
                        Text(eventDayTimeText(event))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.lj.inkMute)
                            .frame(width: 80, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundStyle(Color.lj.ink)
                                .lineLimit(1)
                            Text(event.location)
                                .font(.system(size: 10.5, weight: .medium, design: .default))
                                .foregroundStyle(Color.lj.inkMute)
                                .lineLimit(1)
                        }
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
