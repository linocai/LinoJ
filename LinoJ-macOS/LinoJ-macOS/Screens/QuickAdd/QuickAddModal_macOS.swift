// QuickAddModal_macOS.swift
// macOS Quick Add modal —— plan P3.6 范围。
//
// 入口：⌘N / ⌘⇧T / ⌘⇧E / ⌘⇧P / Calendar `+ New event` → router.showQuickAdd = true。
// RootWindow 用 `.sheet(isPresented: $router.showQuickAdd)` 绑这个视图。
//
// 视觉决策：
//   - SwiftUI macOS `.sheet` 默认是从顶部滑下的窗口附着 sheet，宽度由内部 content 决定。
//     plan 写 "520pt 宽 + backdrop 70% black + 居中"，但居中浮动 modal 在 SwiftUI macOS 上
//     必须用自定义 NSWindow 或 overlay 才能实现 —— 性价比低且与系统行为不一致。
//     选用 `.sheet` + 强行 `.frame(width: 520, height: 一定值)` —— 系统 sheet 自带遮罩与阴影，
//     与设计稿差异在「居中 vs 从顶部下滑」一处，功能完全等价，验收文本接受 .sheet。
//   - sheet 内部按 design_handoff_linoj/macos-overlays.jsx 的 ANewModal 组装：
//     header（"New" 标题 + 3-way segmented control）→ body（按 kind 切表单）→ footer（kbd hints + Cancel + Create）。
//
// 键盘：
//   - esc：系统 sheet 自带 dismiss（点击 Cancel 也可）；Esc 默认会 dismiss sheet（macOS 标准）。
//   - ⌘↵：Create 按钮 `.keyboardShortcut(.return, modifiers: .command)`，按下触发 submit。

import SwiftUI
import SwiftData
import LinoJCore

struct QuickAddModal_macOS: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router

    /// VM 在 onAppear 时实例化（拿 router 的 defaultKind + prefilledProject 喂进去）。
    @State private var vm: QuickAddViewModel?

    /// 项目列表用 `@Query` 拉，给 Todo / Event 表单的 Project chip row 用。
    @Query(sort: \Project.createdAt, order: .forward) private var projects: [Project]

    /// W1：选人器候选来源 —— 全部 Person，按 name 排序（与 projects 拉法同模式）。
    /// VM 不持有 @Query（@Model 非 Sendable），由 View 拉快照传进 VM 的增删方法。
    @Query(sort: \Person.name, order: .forward) private var allPeople: [Person]

    /// W1：当前内联展开的选人器（nil 表示都收起）。同时只展开一个。
    @State private var expandedPicker: PersonTargetUI?

    /// W1：选人器顶部搜索/输入框内容（attendees 与 members 复用同一个 —— 同时只展开一个）。
    @State private var peopleSearch: String = ""

    /// W1：标识当前展开哪个选人器（与 VM 的 PersonTarget 区分；UI 层枚举）。
    private enum PersonTargetUI { case attendee, member }

    /// I5：Settings VM 用于读 defaultTodoScope —— Quick Add Todo 表单的默认 scope。
    /// 与 SettingsView 各自 own 一个 VM，反正都从 .standard UserDefaults 读，值同步。
    @State private var settings = SettingsViewModel()

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                // 占位（极短暂 —— onAppear 立即 init），避免 sheet 弹出瞬间空。
                Color.lj.panel
                    .frame(width: 520, height: 480)
            }
        }
        .onAppear {
            if vm == nil {
                vm = QuickAddViewModel(
                    context: modelContext,
                    defaultKind: router.quickAddDefaultKind,
                    prefilledProject: router.quickAddPrefilledProject,
                    // I5: 应用 Settings 中的 defaultTodoScope（默认 .company）。
                    defaultScope: settings.defaultTodoScope,
                    // V5：非 nil 则进入 Project edit 模式（预填字段 + submit 走 update）。
                    editingProject: router.quickAddEditingProject
                )
            }
        }
        .onDisappear {
            // S11 / 原有：sheet 关闭后清掉 router 的预填 + VM 本地状态，避免下次打开还带着上次的输入。
            router.quickAddPrefilledProject = nil
            router.quickAddDefaultKind = .todo
            // V5：清掉 edit 信号，下次打开恢复 create 模式。
            router.quickAddEditingProject = nil
            // S11：vm = nil 让下次打开 sheet 重建，避免上次输入污染。
            vm = nil
            // W1：选人器展开态 + 搜索框随 sheet 关闭复位。
            expandedPicker = nil
            peopleSearch = ""
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func content(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header(vm: vm)
            Divider().overlay(Color.lj.border)

            ScrollView {
                Group {
                    switch vm.kind {
                    case .todo:    todoForm(vm: vm)
                    case .event:   eventForm(vm: vm)
                    case .project: projectForm(vm: vm)
                    }
                }
                .padding(.horizontal, LJSpacing.s18)
                .padding(.top, LJSpacing.s18)
                .padding(.bottom, LJSpacing.s18)
            }
            .frame(maxHeight: .infinity)

            Divider().overlay(Color.lj.border)
            footer(vm: vm)
        }
        .frame(width: 520, height: 480)
        .background(Color.lj.panel)
    }

    // MARK: Header

    @ViewBuilder
    private func header(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        HStack(spacing: LJSpacing.s12) {
            // V5：edit 模式标题切「Edit project」，否则「New」。
            Text(vm.isEditing ? LJStrings.quickAddEditProjectTitle : LJStrings.quickAddNew)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.lj.ink)

            Spacer(minLength: 0)

            // 3-way segmented control。SwiftUI Picker(.segmented) 在 macOS 上能直接达成视觉。
            // V5：edit 模式锁死在 Project（整个 segmented disable —— kind 已固定为 .project）。
            Picker("", selection: $vm.kind) {
                Label {
                    Text(LJStrings.quickAddKindTodo)
                } icon: {
                    Image(systemName: "checkmark.square")
                }
                .tag(QuickAddViewModel.Kind.todo)
                Label {
                    Text(LJStrings.quickAddKindEvent)
                } icon: {
                    Image(systemName: "calendar")
                }
                .tag(QuickAddViewModel.Kind.event)
                Label {
                    Text(LJStrings.quickAddKindProject)
                } icon: {
                    Image(systemName: "folder")
                }
                .tag(QuickAddViewModel.Kind.project)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)
            .disabled(vm.isEditing)
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.vertical, LJSpacing.s12)
    }

    // MARK: Footer

    @ViewBuilder
    private func footer(vm: QuickAddViewModel) -> some View {
        HStack(spacing: LJSpacing.s8) {
            // kbd hints
            HStack(spacing: 6) {
                kbd("esc")
                Text(LJStrings.quickAddCancelHint)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
                Text("·")
                    .foregroundStyle(Color.lj.inkDim)
                    .padding(.horizontal, 4)
                kbd("⌘↵")
                Text(LJStrings.quickAddCreateHint)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Text(LJStrings.quickAddCancel)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button {
                submit(vm: vm)
            } label: {
                Text(createButtonTitle(vm: vm))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.lj.bg)
                    .padding(.horizontal, LJSpacing.s14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(vm.canSubmit ? Color.lj.ink : Color.lj.inkDim)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSubmit)
            // ⌘↵ 提交
            .keyboardShortcut(.return, modifiers: .command)
            .accessibilityLabel(Text(vm.isEditing ? LJStrings.quickAddSave : LJStrings.quickAddCreate))
        }
        .padding(.horizontal, LJSpacing.s16)
        .padding(.vertical, LJSpacing.s12)
        .background(Color.lj.bgSoft)
    }

    /// 单个 kbd 标签视觉（与 design_handoff jsx kbdStyle 接近）。
    @ViewBuilder
    private func kbd(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.lj.inkSoft)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.lj.chip)
            )
    }

    private func createButtonTitle(vm: QuickAddViewModel) -> LocalizedStringResource {
        // V5：edit 模式提交按钮文案为「Save」。
        if vm.isEditing { return LJStrings.quickAddSave }
        switch vm.kind {
        case .todo:    return LJStrings.quickAddCreateTodo
        case .event:   return LJStrings.quickAddCreateEvent
        case .project: return LJStrings.quickAddCreateProject
        }
    }

    // MARK: Submit

    private func submit(vm: QuickAddViewModel) {
        guard vm.canSubmit else { return }
        do {
            _ = try vm.submit()
            dismiss()
        } catch {
            // P3.6 不要求错误展示，保留 sheet 让用户重试。
            // 0.9.1：错误日志静默（不在 Release 打印），失败时 sheet 保持打开让用户重试。
            _ = error
        }
    }

    // MARK: - Todo form

    @ViewBuilder
    private func todoForm(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: LJSpacing.s14) {
            // 22pt 大字号 title input —— 设计稿 ANewTodoBody 用 22pt semibold display。
            TextField(text: $vm.todoTitle) {
                Text(LJStrings.quickAddTodoPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.lj.ink)
                .submitLabel(.done)
                .onSubmit {
                    submit(vm: vm)
                }

            // Urgency 双选
            HStack(spacing: LJSpacing.s8) {
                urgencyChip(label: LJStrings.urgencyUrgent, active: vm.todoUrgency == .urgent, blue: true) {
                    vm.todoUrgency = .urgent
                }
                urgencyChip(label: LJStrings.urgencyNormal, active: vm.todoUrgency == .normal, blue: false) {
                    vm.todoUrgency = .normal
                }

                Divider().frame(height: 18).overlay(Color.lj.border)

                // Scope 双选
                scopeChip(label: LJStrings.scopePersonal, active: vm.todoScope == .personal) {
                    vm.todoScope = .personal
                }
                scopeChip(label: LJStrings.scopeCompany, active: vm.todoScope == .company) {
                    vm.todoScope = .company
                }
            }

            // Project chip row（scope == .personal 时整行 disabled + 0.5 opacity）
            VStack(alignment: .leading, spacing: 6) {
                Text(LJStrings.quickAddLabelProject)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(Color.lj.inkMute)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // None
                        projectChipLocalized(label: LJStrings.quickAddChipNone, active: vm.todoProject == nil) {
                            vm.todoProject = nil
                        }
                        ForEach(projects) { project in
                            projectChip(
                                label: project.title,
                                active: vm.todoProject?.id == project.id
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
            // 22pt title input
            TextField(text: $vm.eventTitle) {
                Text(LJStrings.quickAddEventPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.lj.ink)

            // Date / Start / End 三个 DatePicker（一行三列）
            HStack(alignment: .top, spacing: LJSpacing.s8) {
                eventField(label: LJStrings.quickAddEventDate) {
                    DatePicker("", selection: $vm.eventDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                eventField(label: LJStrings.quickAddEventStart) {
                    DatePicker("", selection: $vm.eventStart, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                eventField(label: LJStrings.quickAddEventEnd) {
                    DatePicker("", selection: $vm.eventEnd, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
            }

            // Location
            VStack(alignment: .leading, spacing: 4) {
                Text(LJStrings.quickAddLabelLocation)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(Color.lj.inkMute)
                TextField(text: $vm.eventLocation) {
                    Text(LJStrings.quickAddLocationPlaceholder)
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .padding(.horizontal, LJSpacing.s8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.lj.chip)
                    )
            }

            // Attendees：W1 始终渲染该节 —— 标题 + 已选 AvatarStack/空态提示 + 入口按钮 + 内联选人区。
            peopleSection(
                vm: vm,
                target: .attendee,
                sectionLabel: LJStrings.quickAddLabelAttendees,
                addLabel: LJStrings.quickAddAttendeesAdd,
                emptyLabel: LJStrings.quickAddAttendeesEmpty,
                selected: vm.eventAttendees
            )

            // Optional Link to project
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(LJStrings.quickAddLabelLinkProject)
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.66)
                        .foregroundStyle(Color.lj.inkMute)
                    Text(LJStrings.quickAddOptional)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lj.inkMute.opacity(0.7))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        projectChipLocalized(label: LJStrings.quickAddChipNone, active: vm.eventProject == nil) {
                            vm.eventProject = nil
                        }
                        ForEach(projects) { project in
                            projectChip(
                                label: project.title,
                                active: vm.eventProject?.id == project.id
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

    /// 一个 DATE / START / END 字段视觉 wrapper —— 上小 caption + 下控件。
    @ViewBuilder
    private func eventField<Inner: View>(
        label: LocalizedStringResource,
        @ViewBuilder content: () -> Inner
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.66)
                .foregroundStyle(Color.lj.inkMute)
            content()
                .padding(.horizontal, LJSpacing.s8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.lj.chip)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Project form

    @ViewBuilder
    private func projectForm(vm: QuickAddViewModel) -> some View {
        @Bindable var vm = vm

        VStack(alignment: .leading, spacing: LJSpacing.s14) {
            // Title
            TextField(text: $vm.projectTitle) {
                Text(LJStrings.quickAddProjectPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.lj.ink)

            // Description（multiline TextEditor —— macOS TextEditor 跨 26 SDK 可用）
            VStack(alignment: .leading, spacing: 4) {
                Text(LJStrings.quickAddLabelDescription)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(Color.lj.inkMute)
                TextEditor(text: $vm.projectIntro)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.inkSoft)
                    .scrollContentBackground(.hidden)
                    .padding(LJSpacing.s8)
                    .frame(minHeight: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.lj.chip)
                    )
            }

            // Tag
            VStack(alignment: .leading, spacing: 4) {
                Text(LJStrings.quickAddLabelTag)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(Color.lj.inkMute)
                TextField(text: $vm.projectTag) {
                    Text(LJStrings.quickAddTagPlaceholder)
                }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .padding(.horizontal, LJSpacing.s8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.lj.chip)
                    )
                Text(LJStrings.quickAddTagHint)
                    .font(.system(size: 11, weight: .medium))
                    .italic()
                    .foregroundStyle(Color.lj.inkMute)
            }

            // Members：W1 始终渲染该节 —— 标题 + 已选 AvatarStack/空态提示 + 入口按钮 + 内联选人区。
            // V5 edit 模式 projectMembers 已预填既有成员，选人区支持在已选基础上增删。
            peopleSection(
                vm: vm,
                target: .member,
                sectionLabel: LJStrings.quickAddLabelMembers,
                addLabel: LJStrings.quickAddMembersAdd,
                emptyLabel: LJStrings.quickAddMembersEmpty,
                selected: vm.projectMembers
            )
        }
    }

    // MARK: - People picker (W1)

    /// W1：Attendees / Members 节统一布局 —— 标题 + 已选 AvatarStack（或空态提示）+ 入口按钮 +
    /// 内联展开的可滚动 Person 列表（点入口按钮原地展开/收起，不另开二级 sheet）。
    @ViewBuilder
    private func peopleSection(
        vm: QuickAddViewModel,
        target: PersonTargetUI,
        sectionLabel: LocalizedStringResource,
        addLabel: LocalizedStringResource,
        emptyLabel: LocalizedStringResource,
        selected: [Person]
    ) -> some View {
        let isExpanded = (expandedPicker == target)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: LJSpacing.s8) {
                Text(sectionLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(Color.lj.inkMute)

                Spacer(minLength: 0)

                // 入口按钮：展开/收起内联选人区。
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isExpanded {
                            expandedPicker = nil
                        } else {
                            expandedPicker = target
                            peopleSearch = ""
                        }
                    }
                } label: {
                    Text(addLabel)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.lj.blueInk)
                }
                .buttonStyle(.plain)
            }

            // 已选展示 / 空态。
            if selected.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.lj.inkMute)
            } else {
                AvatarStack(people: selected, max: 5)
            }

            // 内联展开的选人区。
            if isExpanded {
                inlinePicker(vm: vm, target: target)
            }
        }
    }

    /// W1：内联选人区 —— 顶部输入框（搜索 / 新建）+ 限高可滚动 Person 列表 + 「新建」行。
    @ViewBuilder
    private func inlinePicker(vm: QuickAddViewModel, target: PersonTargetUI) -> some View {
        let trimmed = peopleSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [Person] = trimmed.isEmpty
            ? allPeople
            : allPeople.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        // 是否已存在同名（trim + 小写）—— 决定要不要显示「新建」行。
        let exactExists = allPeople.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased()
        }

        VStack(alignment: .leading, spacing: 6) {
            // 顶部输入框。
            TextField(text: $peopleSearch) {
                Text(LJStrings.quickAddPeopleSearchPlaceholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.lj.ink)
                .padding(.horizontal, LJSpacing.s8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.lj.chip)
                )

            // 限高可滚动列表。
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if filtered.isEmpty && (trimmed.isEmpty || exactExists) {
                        Text(LJStrings.quickAddPeopleNoResults)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color.lj.inkMute)
                            .padding(.vertical, 6)
                            .padding(.horizontal, LJSpacing.s8)
                    }
                    ForEach(filtered) { person in
                        personRow(vm: vm, target: target, person: person)
                    }
                    // 「+ 新建『<name>』」行：仅当有输入且无完全同名时显示。
                    if !trimmed.isEmpty && !exactExists {
                        createPersonRow(vm: vm, target: target, name: trimmed)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 160)
        }
        .padding(LJSpacing.s8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.lj.bgSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.lj.border, lineWidth: 0.5)
        )
    }

    /// W1：选人列表单行 —— avatar + name + trailing checkmark（已选）。点击 toggle。
    @ViewBuilder
    private func personRow(vm: QuickAddViewModel, target: PersonTargetUI, person: Person) -> some View {
        let isSelected = (target == .attendee)
            ? vm.isAttendeeSelected(person)
            : vm.isMemberSelected(person)

        Button {
            switch target {
            case .attendee: vm.toggleAttendee(person)
            case .member:   vm.toggleMember(person)
            }
        } label: {
            HStack(spacing: LJSpacing.s8) {
                Text(person.initial)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lj.ink)
                    .frame(width: 22, height: 22)
                    .background { Circle().fill(Color.lj.chip) }
                    .overlay { Circle().strokeBorder(Color.lj.border, lineWidth: 0.5) }

                Text(person.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.lj.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.lj.blueInk)
                }
            }
            .padding(.horizontal, LJSpacing.s8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.lj.chip : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    /// W1：「+ 新建『<name>』」行 —— 点击经 VM addPerson 复用/新建并选中，然后清空输入框。
    @ViewBuilder
    private func createPersonRow(vm: QuickAddViewModel, target: PersonTargetUI, name: String) -> some View {
        Button {
            let vmTarget: QuickAddViewModel.PersonTarget = (target == .attendee) ? .attendee : .member
            _ = vm.addPerson(named: name, existing: allPeople, target: vmTarget)
            peopleSearch = ""
        } label: {
            HStack(spacing: LJSpacing.s8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lj.blueInk)
                // "Create『<name>』" —— name 由布局拼接，不进本地化 key。
                Text("\(String(localized: LJStrings.quickAddPeopleCreateNew))『\(name)』")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.lj.blueInk)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LJSpacing.s8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chips

    /// Urgency 选项 chip（Urgent 蓝、Normal 灰）。
    @ViewBuilder
    private func urgencyChip(
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
                    .font(.system(size: 11.5, weight: active ? .bold : .medium))
                    .foregroundStyle(
                        active
                            ? (blue ? Color.lj.blueInk : Color.lj.ink)
                            : Color.lj.inkSoft
                    )
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(active ? (blue ? Color.lj.blueSoft : Color.lj.chip) : Color.clear)
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

    /// Scope 选项 chip（Personal / Company），样式与 urgency 非蓝态一致。
    @ViewBuilder
    private func scopeChip(label: LocalizedStringResource, active: Bool, action: @escaping () -> Void) -> some View {
        urgencyChip(label: label, active: active, blue: false, action: action)
    }

    /// Project picker chip —— 选中时填 chip 色 + 强边。接 String（用户数据）。
    @ViewBuilder
    private func projectChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.lj.ink : Color.lj.inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(active ? Color.lj.chip : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .strokeBorder(
                            active ? Color.lj.borderStrong : Color.lj.border,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    /// Project picker chip 的 LocalizedStringResource 版本（用于 "None"）。
    @ViewBuilder
    private func projectChipLocalized(
        label: LocalizedStringResource,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? Color.lj.ink : Color.lj.inkSoft)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(active ? Color.lj.chip : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .strokeBorder(
                            active ? Color.lj.borderStrong : Color.lj.border,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
