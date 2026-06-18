// SourceLabel.swift
// v1.3 新功能件：主页待办的「来源标签」胶囊（+ 可选项目名胶囊）。
//
// 仅主页（Main）的待办下方显示，标明 Todo.scope（个人 / 公司）；Personal / Company 页内
// 待办因同 scope 冗余，不显示来源标签（由调用方决定是否套此件）。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style：
//   胶囊 padding:2px 8px；border-radius:6；5px 圆点；字 10.5px/600；标签间 gap 6。
//   个人：底 rgba(60,60,67,0.07)≈chip、字 rgba(60,60,67,0.6)≈inkSoft、点 rgba(60,60,67,0.4)≈inkMute。
//   公司：底 rgba(123,123,240,0.12)≈scopeCompanyBg、字 #6E63E6≈scopeCompanyFg、点 #8A6DF0≈scopeCompanyDot。
//   项目名胶囊（在来源标签右侧并排）：底 rgba(60,60,67,0.05~0.06)≈chip、字 inkSoft；
//     点 urgent 用 #8A6DF0(purpleDot) / normal 用 rgba(60,60,67,0.35)≈inkMute。

import SwiftUI

/// 主页待办来源标签件：scope 胶囊 + 可选项目名胶囊（右侧并排）。
public struct LJSourceLabel: View {
    private let scope: Scope
    private let projectName: String?
    private let urgent: Bool

    /// - Parameters:
    ///   - scope: 待办 scope（决定个人灰 / 公司紫）。
    ///   - projectName: 关联项目名（nil 则不显示项目胶囊）。
    ///   - urgent: 该待办是否 urgent（仅影响项目胶囊圆点颜色）。
    public init(scope: Scope, projectName: String? = nil, urgent: Bool = false) {
        self.scope = scope
        self.projectName = projectName
        self.urgent = urgent
    }

    public var body: some View {
        HStack(spacing: LJSpacing.s6) {
            scopeChip
            if let projectName, !projectName.isEmpty {
                projectChip(projectName)
            }
        }
    }

    // MARK: - scope 胶囊

    private var scopeChip: some View {
        let isCompany = scope == .company
        return HStack(spacing: 5) {
            Circle()
                .fill(isCompany ? Color.lj.scopeCompanyDot : Color.lj.inkMute)
                .frame(width: 5, height: 5)
            Text(scopeLabel)
                .font(.system(size: 10.5, weight: .semibold, design: .default))
                .foregroundStyle(isCompany ? Color.lj.scopeCompanyFg : Color.lj.inkSoft)
        }
        .padding(.horizontal, LJSpacing.s8)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.sourceLabel, style: .continuous)
                .fill(isCompany ? Color.lj.scopeCompanyBg : Color.lj.chip)
        }
    }

    /// 复用既有「个人 / 公司」本地化（Tab.personal / Tab.company），不新增字符串。
    private var scopeLabel: LocalizedStringResource {
        scope == .company ? LJStrings.tabCompany : LJStrings.tabPersonal
    }

    // MARK: - 项目名胶囊

    private func projectChip(_ name: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(urgent ? Color.lj.purpleDot : Color.lj.inkMute)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 10.5, weight: .semibold, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(1)
        }
        .padding(.horizontal, LJSpacing.s8)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.sourceLabel, style: .continuous)
                .fill(Color.lj.chip)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Source labels", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: LJSpacing.s10) {
        LJSourceLabel(scope: .personal)
        LJSourceLabel(scope: .company)
        LJSourceLabel(scope: .company, projectName: "LinoJ macOS", urgent: true)
        LJSourceLabel(scope: .personal, projectName: "Side hobby", urgent: false)
    }
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
}
#endif
