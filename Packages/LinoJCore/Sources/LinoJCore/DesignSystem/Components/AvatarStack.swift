// AvatarStack.swift
// 一组人员叠加显示的小 avatar 列。
//
// 视觉：每个 avatar 是圆形 chip 色填充，文字为 person.initial 大写首字母。
// macOS 直径 22pt；iOS 直径 26pt。相邻 avatar 横向 -6pt 偏移形成「叠」效果。
// 超过 max 时最后一个圆显示 "+N"。

import SwiftUI

public struct AvatarStack: View {
    private let people: [Person]
    private let max: Int

    public init(people: [Person], max: Int = 5) {
        self.people = people
        self.max = max
    }

    public var body: some View {
        let diameter: CGFloat = {
            #if os(macOS)
            return 22
            #else
            return 26
            #endif
        }()
        let visible = Array(people.prefix(max))
        let overflow = people.count - visible.count

        // ZStack 实现叠加 —— 用 enumerated 给每个 avatar 一个 zIndex，让先出现的在上层。
        HStack(spacing: -6) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, person in
                AvatarChip(initial: person.initial, diameter: diameter)
                    .zIndex(Double(visible.count - index))
            }
            if overflow > 0 {
                AvatarChip(initial: "+\(overflow)", diameter: diameter)
                    .zIndex(0)
            }
        }
    }
}

/// 单个圆形 avatar chip。复用给溢出指示 ("+3")。
private struct AvatarChip: View {
    let initial: String
    let diameter: CGFloat

    var body: some View {
        Text(initial)
            .font(.system(size: 11, weight: .semibold, design: .default))
            .foregroundStyle(Color.lj.ink)
            .frame(width: diameter, height: diameter)
            .background {
                Circle().fill(Color.lj.chip)
            }
            .overlay {
                Circle().strokeBorder(Color.lj.border, lineWidth: 0.5)
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light", traits: .sizeThatFitsLayout) {
    let people = [
        Person(name: "Mei"),
        Person(name: "Andrew"),
        Person(name: "Jane"),
        Person(name: "Kai"),
        Person(name: "Leo"),
        Person(name: "Mom"),
        Person(name: "Dad")
    ]
    return VStack(alignment: .leading, spacing: LJSpacing.s12) {
        AvatarStack(people: Array(people.prefix(3)))
        AvatarStack(people: people, max: 5)
    }
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    AvatarStack(people: [
        Person(name: "Mei"), Person(name: "Andrew"), Person(name: "Kai")
    ])
    .padding(LJSpacing.s16)
    .background(Color.lj.bg)
    .environment(\.colorScheme, .dark)
}
#endif
