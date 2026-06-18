// NoteCard.swift
// v1.3 R5 件：灵感 masonry 笔记墙的单张笔记卡（对原型重建）。
//
// 真理源：design_handoff_linoj_frontend/LinoJ 主页.dc.html inline style（灵感页 masonry）：
//   卡片 padding:16 16 14 19；radius:14；bg:n.bg（多色调浅底）；border:0.5px rgba(60,60,67,0.08)；
//   顶高光 inset 0 0.5px 0 rgba(255,255,255,0.6)；
//   左 3px 全高色条（top14 bottom14）n.bar（按 tone 取渐变）；
//   标题 15px/600/-0.015em；正文摘要 13px/rgba(60,60,67,0.65)/line-height1.55；
//   日期 mono 11px/rgba(60,60,67,0.38)；置顶时显示 pin 标记。
//
// tone 由 note.id 哈希派生（a 暖橙 / b 紫 / c 蓝），无 schema 改动。

import SwiftUI

/// 灵感 masonry 笔记墙单卡。点击触发 `onOpen`（打开编辑）。
public struct NoteCard: View {
    private let note: Note
    private let onOpen: () -> Void

    public init(note: Note, onOpen: @escaping () -> Void = {}) {
        self.note = note
        self.onOpen = onOpen
    }

    /// note.id 哈希派生稳定 tone（0=暖橙 / 1=紫 / 2=蓝）。
    private var tone: Int {
        let hash = note.id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return hash % 3
    }

    private var toneBg: Color {
        switch tone {
        case 0: return Color.lj.noteToneWarm
        case 1: return Color.lj.noteTonePurple
        default: return Color.lj.noteToneBlue
        }
    }

    /// 左色条渐变（按 tone）。
    private var barGradient: LinearGradient {
        let colors: [Color]
        switch tone {
        case 0: colors = [Color.lj.noteBarWarm, Color.lj.noteBarWarmDeep]
        case 1: colors = [LJGradients.brandBlue, LJGradients.brandPurple]
        default: colors = [Color.lj.noteBarBlue, LJGradients.brandBlue]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    public var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: LJSpacing.s6) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.lj.inkMute)
                    }
                    Text(note.displayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .kerning(-0.225)
                        .foregroundStyle(Color.lj.ink)
                        .lineLimit(2)
                }
                let snippet = bodySnippet
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundStyle(Color.lj.inkSoft)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(dateText)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.lj.inkMute)
                    .padding(.top, 5)
            }
            .padding(.leading, 19)
            .padding(.trailing, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(toneBg)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
            .overlay { LJTopHighlight(radius: 14) }
            // 左 3px 全高色条（上下内缩 14pt，与原型 top14 bottom14 一致）。
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(barGradient)
                    .frame(width: 3)
                    .padding(.vertical, 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .ljHoverLift()
    }

    // MARK: - Helpers

    /// 正文摘要：取纯文本去掉首行（= displayTitle）后剩余非空文本拼成一段。
    private var bodySnippet: String {
        let plain = String(note.body.characters)
        let lines = plain.split(separator: "\n", omittingEmptySubsequences: false)
        var rest: [String] = []
        var seenTitle = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !seenTitle {
                if trimmed.isEmpty { continue }
                seenTitle = true
                continue
            }
            rest.append(String(line))
        }
        return rest.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// mono 日期（原型「5月20日」格式）—— 本地化短日期。
    private var dateText: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: note.updatedAt)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Note cards", traits: .sizeThatFitsLayout) {
    HStack(alignment: .top, spacing: 16) {
        NoteCard(note: {
            let n = Note(body: AttributedString("产品命名\nLinoJ 留着。J = Journal + Join。"))
            n.isPinned = true
            return n
        }())
        NoteCard(note: Note(body: AttributedString("一句话灵魂\n把时间和待办彻底分开。")))
    }
    .frame(width: 480)
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
}
#endif
