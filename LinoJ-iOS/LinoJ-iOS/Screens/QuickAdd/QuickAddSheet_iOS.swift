// QuickAddSheet_iOS.swift
// iOS Quick Add bottom sheet —— plan P3.6 范围。
//
// 入口：右上 `+` floating button → router.showQuickAdd = true → RootTabView 的
// `.sheet(isPresented: $router.showQuickAdd) { QuickAddSheet_iOS() }`。
//
// 视觉决策（依据 design_handoff_linoj/ios-overlays.jsx 的 IosNewSheet）：
//   - `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)` 让系统帮忙
//     渲染 grab handle 与底部 sheet 行为。
//   - 顶行：Cancel（左）/ "New" 标题（中）/ Create ink pill（右）。不用 NavigationStack。
//   - 然后 segmented Picker，下方 ScrollView 装表单。
//   - 三种 form 复用同样设计（Todo / Event / Project），iOS 用大字号 + 圆角 chip 视觉，
//     不与 macOS 直接共享 View（macOS 用 inline plain TextField，iOS 用大圆角 panel TextField）。

import SwiftUI
import SwiftData
import LinoJCore

struct QuickAddSheet_iOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router

    @State private var vm: QuickAddViewModel?

    /// 项目列表用 `@Query` 拉，给 Todo / Event 表单的 Project chip row 用。
    @Query(sort: \Project.createdAt, order: .forward) private var projects: [Project]

    /// I5：Settings VM 用于读 defaultTodoScope。
    @State private var settings = SettingsViewModel()

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                Color.lj.bg
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if vm == nil {
                vm = QuickAddViewModel(
                    context: modelContext,
                    defaultKind: router.quickAddDefaultKind,
                    prefilledProject: router.quickAddPrefilledProject,
                    // I5：Settings 中的 defaultTodoScope。
                    defaultScope: settings.defaultTodoScope,
                    // V5：非 nil 则进入 Project edit 模式。
                    editingProject: router.quickAddEditingProject
                )
            }
        }
        .onDisappear {
            router.quickAddPrefilledProject = nil
            router.quickAddDefaultKind = .todo
            // V5：清掉 edit 信号，下次打开恢复 create 模式。
            router.quickAddEditingProject = nil
            // S11：清掉 vm，下次打开 sheet 重建，避免上次输入污染。
            vm = nil
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header(vm: vm)
            kindSegmented(vm: vm)
                .padding(.horizontal, LJSpacing.s16)
                .padding(.bottom, LJSpacing.s14)

            ScrollView {
                Group {
                    switch vm.kind {
                    case .todo:    todoForm(vm: vm)
                    case .event:   eventForm(vm: vm)
                    case .project: projectForm(vm: vm)
                    }
                }
                .padding(.horizontal, LJSpacing.s16)
                .padding(.top, 4)
                .padding(.bottom, LJSpacing.s28)
            }
        }
        .background(Color.lj.bg)
    }

    // MARK: Header

    @ViewBuilder
    private func header(vm: QuickAddViewModel) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text(LJStrings.quickAddCancel)
            }
            .buttonStyle(.plain)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color.lj.inkSoft)

            Spacer()

            // V5：edit 模式标题切「Edit project」。
            Text(vm.isEditing ? LJStrings.quickAddEditProjectTitle : LJStrings.quickAddNew)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.lj.ink)

            Spacer()

            Button {
                submit(vm: vm)
            } label: {
                // V5：edit 模式提交按钮文案为「Save」。
                Text(vm.isEditing ? LJStrings.quickAddSave : LJStrings.quickAddCreate)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.lj.bg)
                    .padding(.horizontal, LJSpacing.s14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(vm.canSubmit ? Color.lj.ink : Color.lj.inkDim)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSubmit)
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.top, LJSpacing.s10)
        .padding(.bottom, LJSpacing.s12)
    }

    // MARK: Segmented

    @ViewBuilder
    private func kindSegmented(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        Picker("", selection: $vm.kind) {
            Text(LJStrings.quickAddKindTodo).tag(QuickAddViewModel.Kind.todo)
            Text(LJStrings.quickAddKindEvent).tag(QuickAddViewModel.Kind.event)
            Text(LJStrings.quickAddKindProject).tag(QuickAddViewModel.Kind.project)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        // V5：edit 模式锁死在 Project（整个 segmented disable —— kind 已固定为 .project）。
        .disabled(vm.isEditing)
    }

    // MARK: Submit

    private func submit(vm: QuickAddViewModel) {
        guard vm.canSubmit else { return }
        do {
            _ = try vm.submit()
            dismiss()
        } catch {
            // 0.9.1：错误日志静默（不在 Release 打印），失败时 sheet 保持打开让用户重试。
            _ = error
        }
    }

    // MARK: - Todo form

    @ViewBuilder
    private func todoForm(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: LJSpacing.s14) {
            // 18pt big title input（iOS sheet 整体偏大字号；jsx 用 18pt）。
            TextField(text: $vm.todoTitle) {
                Text(LJStrings.quickAddTodoPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, LJSpacing.s16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.lj.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.lj.border, lineWidth: 0.5)
                )

            iosFieldGroup(label: LJStrings.quickAddLabelUrgency) {
                HStack(spacing: 8) {
                    iosToggleChipLocalized(label: LJStrings.urgencyUrgent, active: vm.todoUrgency == .urgent, blue: true) {
                        vm.todoUrgency = .urgent
                    }
                    iosToggleChipLocalized(label: LJStrings.urgencyNormal, active: vm.todoUrgency == .normal, blue: false) {
                        vm.todoUrgency = .normal
                    }
                }
            }

            iosFieldGroup(label: LJStrings.quickAddLabelScope) {
                HStack(spacing: 8) {
                    iosToggleChipLocalized(label: LJStrings.scopePersonal, active: vm.todoScope == .personal, blue: false) {
                        vm.todoScope = .personal
                    }
                    iosToggleChipLocalized(label: LJStrings.scopeCompany, active: vm.todoScope == .company, blue: false) {
                        vm.todoScope = .company
                    }
                }
            }

            iosFieldGroup(label: LJStrings.quickAddLabelProject, optional: true) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        iosToggleChipLocalized(label: LJStrings.quickAddChipNone, active: vm.todoProject == nil, blue: false) {
                            vm.todoProject = nil
                        }
                        ForEach(projects) { project in
                            iosToggleChip(
                                label: project.title,
                                active: vm.todoProject?.id == project.id,
                                blue: false
                            ) {
                                vm.todoProject = project
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .disabled(vm.todoScope == .personal)
            .opacity(vm.todoScope == .personal ? 0.5 : 1)
        }
    }

    // MARK: - Event form

    @ViewBuilder
    private func eventForm(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: LJSpacing.s14) {
            TextField(text: $vm.eventTitle) {
                Text(LJStrings.quickAddEventPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, LJSpacing.s16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.lj.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.lj.border, lineWidth: 0.5)
                )

            // Date / Start / End as a grouped list（圆角白卡内三行）
            VStack(spacing: 0) {
                iosListRow {
                    Text(LJStrings.quickAddEventDateRow).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.lj.ink)
                    Spacer()
                    DatePicker("", selection: $vm.eventDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Divider().overlay(Color.lj.border).padding(.leading, LJSpacing.s16)
                iosListRow {
                    Text(LJStrings.quickAddEventStartsRow).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.lj.ink)
                    Spacer()
                    DatePicker("", selection: $vm.eventStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Divider().overlay(Color.lj.border).padding(.leading, LJSpacing.s16)
                iosListRow {
                    Text(LJStrings.quickAddEventEndsRow).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.lj.ink)
                    Spacer()
                    DatePicker("", selection: $vm.eventEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.lj.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            )

            // Location
            iosFieldGroup(label: LJStrings.quickAddLabelLocation) {
                TextField(text: $vm.eventLocation) {
                    Text(LJStrings.quickAddLocationPlaceholder)
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .padding(.horizontal, LJSpacing.s16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.lj.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    )
            }

            // Attendees：AvatarStack（已选）。
            // 0.9.1 TestFlight：attendee 选择器仍是 stub，隐藏 "+ Add" 死按钮避免测试者点了没反应。
            // 提交 Event 仍正常（只是不带 attendees）。eventAttendees 当前恒为空（无添加入口），
            // 故整节仅在非空时渲染。选择器后续版本接通后恢复按钮。
            if !vm.eventAttendees.isEmpty {
                iosFieldGroup(label: LJStrings.quickAddLabelAttendees) {
                    AvatarStack(people: vm.eventAttendees, max: 5)
                }
            }

            // Optional link to project
            iosFieldGroup(label: LJStrings.quickAddLabelLinkProject, optional: true) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        iosToggleChipLocalized(label: LJStrings.quickAddChipNone, active: vm.eventProject == nil, blue: false) {
                            vm.eventProject = nil
                        }
                        ForEach(projects) { project in
                            iosToggleChip(
                                label: project.title,
                                active: vm.eventProject?.id == project.id,
                                blue: false
                            ) {
                                vm.eventProject = project
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Project form

    @ViewBuilder
    private func projectForm(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: LJSpacing.s14) {
            TextField(text: $vm.projectTitle) {
                Text(LJStrings.quickAddProjectPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, LJSpacing.s16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.lj.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.lj.border, lineWidth: 0.5)
                )

            // Description (multiline)
            iosFieldGroup(label: LJStrings.quickAddLabelDescription) {
                TextEditor(text: $vm.projectIntro)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                    .scrollContentBackground(.hidden)
                    .padding(LJSpacing.s12)
                    .frame(minHeight: 90)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.lj.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    )
            }

            iosFieldGroup(label: LJStrings.quickAddLabelTag, hint: LJStrings.quickAddTagHintShort) {
                TextField(text: $vm.projectTag) {
                    Text(LJStrings.quickAddTagPlaceholder)
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .padding(.horizontal, LJSpacing.s16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.lj.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.lj.border, lineWidth: 0.5)
                    )
            }

            // Members：AvatarStack（已选）。
            // 0.9.1 TestFlight：member picker 仍是 stub，隐藏 "+ Invite" 死按钮。提交 Project 仍正常
            // （只是不带 members）。projectMembers 当前恒为空（无添加入口），故整节仅在非空时渲染。
            if !vm.projectMembers.isEmpty {
                iosFieldGroup(label: LJStrings.quickAddLabelMembers) {
                    AvatarStack(people: vm.projectMembers, max: 5)
                }
            }
        }
    }

    // MARK: - Reusable bits

    /// 上小 caption（"URGENCY"）+ 下方 content。
    @ViewBuilder
    private func iosFieldGroup<Inner: View>(
        label: LocalizedStringResource,
        optional: Bool = false,
        hint: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Inner
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.88)
                    .foregroundStyle(Color.lj.inkMute)
                if optional {
                    Text(LJStrings.quickAddOptional)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute.opacity(0.7))
                }
            }
            .padding(.leading, 4)

            content()

            if let hint {
                Text(hint)
                    .font(.system(size: 11.5, weight: .medium))
                    .italic()
                    .foregroundStyle(Color.lj.inkMute)
                    .padding(.leading, 4)
            }
        }
    }

    /// iOS toggle chip（接 String —— 用于用户数据 project.title）。blue=true 时 active 走蓝系。
    @ViewBuilder
    private func iosToggleChip(
        label: String,
        active: Bool,
        blue: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if blue && active {
                    Circle()
                        .fill(Color.lj.blue)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 13, weight: active ? .semibold : .medium))
                    .foregroundStyle(
                        active
                            ? (blue ? Color.lj.blueInk : Color.lj.ink)
                            : Color.lj.inkSoft
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(active ? (blue ? Color.lj.blueSoft : Color.lj.chip) : Color.lj.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .strokeBorder(
                        active
                            ? (blue ? Color.lj.blueBorder : Color.lj.borderStrong)
                            : Color.lj.border,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// iOS toggle chip（接 LocalizedStringResource —— 用于固定 label）。
    @ViewBuilder
    private func iosToggleChipLocalized(
        label: LocalizedStringResource,
        active: Bool,
        blue: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if blue && active {
                    Circle()
                        .fill(Color.lj.blue)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 13, weight: active ? .semibold : .medium))
                    .foregroundStyle(
                        active
                            ? (blue ? Color.lj.blueInk : Color.lj.ink)
                            : Color.lj.inkSoft
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(active ? (blue ? Color.lj.blueSoft : Color.lj.chip) : Color.lj.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .strokeBorder(
                        active
                            ? (blue ? Color.lj.blueBorder : Color.lj.borderStrong)
                            : Color.lj.border,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// 圆角白卡内单行 list-item 容器。
    @ViewBuilder
    private func iosListRow<Inner: View>(@ViewBuilder content: () -> Inner) -> some View {
        HStack(spacing: LJSpacing.s10) {
            content()
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.vertical, 12)
    }
}
