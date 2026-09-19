//
//  Theme.swift
//  赛点
//
//  统一的视觉语言：深色底、红蓝双色渐变、毛玻璃材质与柔和光晕。
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: - 红方

    enum Red {
        static let base = Color(red: 1.00, green: 0.24, blue: 0.30)
        static let deep = Color(red: 0.62, green: 0.04, blue: 0.13)
        static let bright = Color(red: 1.00, green: 0.55, blue: 0.48)
        static let glow = Color(red: 1.00, green: 0.30, blue: 0.34)

        /// 面板从上到下由 #2B0810 过渡到 #120608。
        static let panelDark = Color(red: 0.169, green: 0.031, blue: 0.063)
        static let panelDeepest = Color(red: 0.071, green: 0.024, blue: 0.031)
    }

    // MARK: - 蓝方

    enum Blue {
        static let base = Color(red: 0.20, green: 0.52, blue: 1.00)
        static let deep = Color(red: 0.03, green: 0.20, blue: 0.58)
        static let bright = Color(red: 0.55, green: 0.82, blue: 1.00)
        static let glow = Color(red: 0.29, green: 0.60, blue: 1.00)

        static let panelDark = Color(red: 0.027, green: 0.078, blue: 0.196)
        static let panelDeepest = Color(red: 0.016, green: 0.035, blue: 0.086)
    }

    /// 「删除 / 重新开始」这类破坏性操作用的红。
    ///
    /// 必须显式指定：AppEntry 上有 `.tint(Theme.Blue.base)`，
    /// 会把所有工具栏按钮染蓝，而 `role: .destructive` 在 ToolbarItem 里
    /// **覆盖不了 tint**，只写 role 的话删除按钮还是蓝的。
    static let destructive = Color(red: 1.00, green: 0.27, blue: 0.23)

    static func accent(_ side: Side) -> Color { side == .red ? Red.base : Blue.base }
    static func deep(_ side: Side) -> Color { side == .red ? Red.deep : Blue.deep }
    static func bright(_ side: Side) -> Color { side == .red ? Red.bright : Blue.bright }
    static func glow(_ side: Side) -> Color { side == .red ? Red.glow : Blue.glow }
    static func panelDark(_ side: Side) -> Color { side == .red ? Red.panelDark : Blue.panelDark }
    static func panelDeepest(_ side: Side) -> Color { side == .red ? Red.panelDeepest : Blue.panelDeepest }

    static func panelGradient(_ side: Side) -> LinearGradient {
        LinearGradient(
            colors: [panelDark(side), panelDeepest(side)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func accentGradient(_ side: Side) -> LinearGradient {
        LinearGradient(
            colors: [bright(side), accent(side), deep(side)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 背景

    static let background = LinearGradient(
        colors: [
            Color(red: 0.043, green: 0.047, blue: 0.059),
            Color(red: 0.027, green: 0.031, blue: 0.043),
            Color(red: 0.016, green: 0.016, blue: 0.024),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardStroke = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 字体

    /// 大比分数字：等宽圆体，缩放后依然端正。
    static func scoreFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 触感

@MainActor
enum Haptics {
    /// 得分的轻快反馈。
    static func point() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.75)
    }

    /// 减分/纠正的提示反馈。
    static func correction() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.6)
    }

    /// 拿下关键分（局点/赛点得分）。
    static func critical() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
    }

    /// 获胜的庆祝反馈。
    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 轻微选择反馈。
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
