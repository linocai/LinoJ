// ConflictAlert.swift
// U6：Main 顶部「今日时间冲突」提示 pill。
//
// 语义与视觉：
//   - 与 HeadsUpAlert（蓝色「即将开始」）并列，但**中性色变体**：冲突不是「紧急即将发生」，
//     是被动提示，**不抢蓝色 heads-up 的视觉权重**。整体用 inkMute 中性灰，不用蓝。
//   - 无脉冲蓝点（脉冲蓝是 heads-up 的紧急语言），改用静态中性小点。
//   - 无 Snooze / Open 按钮（冲突是被动提示，无可操作动作）。
//   - 复用 HeadsUpAlert 的 full-width pill 几何（圆角 LJRadii.card、内边距、mono 时间）。
//
// 文案：「2 events overlap at 16:00 / 16:00 有 2 个日程冲突」（LJStrings.headsUpConflict，
// 位置参数 %1$d 数量 / %2$@ 时刻）。time 由调用方按 HH:mm 格式化后传入。

import SwiftUI

public struct ConflictAlert: View {
    private let atTime: Date
    private let count: Int

    public init(atTime: Date, count: Int) {
        self.atTime = atTime
        self.count = count
    }

    /// 冲突起始时刻 "16:00"（与 EventCard 同 HH:mm 口径）。
    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: atTime)
    }

    public var body: some View {
        HStack(alignment: .center, spacing: LJSpacing.s12) {
            // 静态中性小点（非脉冲蓝——冲突不抢 heads-up 的紧急视觉）。
            Circle()
                .fill(Color.lj.inkMute)
                .frame(width: 8, height: 8)

            // 文案：整条用 LJStrings.headsUpConflict（位置参数；time 内嵌为 mono 感）。
            Text(LJStrings.headsUpConflict(count: count, time: timeText))
                .font(.system(size: 12.5, weight: .medium, design: .default))
                .foregroundStyle(Color.lj.inkSoft)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LJSpacing.s14)
        .padding(.vertical, LJSpacing.s10)
        .background {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .fill(Color.lj.chip)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LJRadii.card, style: .continuous)
                .strokeBorder(Color.lj.border, lineWidth: 0.5)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light", traits: .sizeThatFitsLayout) {
    ConflictAlert(atTime: Date(), count: 2)
        .padding(LJSpacing.s16)
        .frame(width: 760)
        .background(Color.lj.bg)
}

#Preview("Dark", traits: .sizeThatFitsLayout) {
    ConflictAlert(atTime: Date(), count: 3)
        .padding(LJSpacing.s16)
        .frame(width: 760)
        .background(Color.lj.bg)
        .environment(\.colorScheme, .dark)
}
#endif
