//
//  CustomRulesView.swift
//  羽毛球计分器
//
//  「自定义」赛制的规则编辑器，首页与设置页共用。
//

import SwiftUI

/// 自定义规则编辑面板。
///
/// 三件事：每局几分、要不要封顶、打几局。改完立刻生效——
/// 比如把 21 改成 11，场上比分可能当场就分出胜负了，`MatchStore` 会重新判定。
struct CustomRulesView: View {
    @Bindable var store: MatchStore
    /// 首页用 true（字号大一点、卡片里嵌着），设置页用 false。
    var compact = false

    private var rules: BadmintonRules { store.state.rules }

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            row(title: "每局几分",
                value: rules.pointsToWin,
                range: BadmintonRules.pointsRange,
                unit: "分") { store.setCustomRules(points: $0, capBonus: rules.capBonus, maxGames: rules.maximumGames) }

            capRow

            gamesRow

            summary
        }
    }

    // MARK: - 每局几分

    private func row(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        unit: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Theme.label(compact ? 15 : 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 8)

            RuleStepper(value: value, range: range, unit: unit, onChange: onChange)
        }
    }

    // MARK: - 封顶

    private var capRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("封顶")
                    .font(Theme.label(compact ? 15 : 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 8)

                // 有封顶时才显示封顶分数的加减
                if let cap = rules.cap {
                    RuleStepper(value: cap, range: (rules.pointsToWin + 1)...(rules.pointsToWin + 20),
                                unit: "分") { newCap in
                        store.setCustomRules(points: rules.pointsToWin,
                                             capBonus: newCap - rules.pointsToWin,
                                             maxGames: rules.maximumGames)
                    }
                }

                Toggle("", isOn: Binding(
                    get: { rules.cap != nil },
                    set: { on in
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.28)) {
                            store.setCustomRules(points: rules.pointsToWin,
                                                 capBonus: on ? 9 : nil,
                                                 maxGames: rules.maximumGames)
                        }
                    }
                ))
                .labelsHidden()
                .tint(Theme.Blue.base)
                .scaleEffect(0.9)
            }

            HStack {
                Spacer()
                Text(rules.cap == nil ? "不封顶，必须一直净胜 2 分" : "打到 \(rules.cap!) 分即锁定胜局")
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    // MARK: - 打几局

    private var gamesRow: some View {
        HStack(spacing: 12) {
            Text("打几局")
                .font(Theme.label(compact ? 15 : 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(BadmintonRules.gameOptions, id: \.self) { n in
                    let selected = rules.maximumGames == n
                    Button {
                        guard !selected else { return }
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.26)) {
                            store.setCustomRules(points: rules.pointsToWin,
                                                 capBonus: rules.capBonus,
                                                 maxGames: n)
                        }
                    } label: {
                        Text(n == 1 ? "一局" : "\(n) 局")
                            .font(Theme.label(14, weight: .bold))
                            .foregroundStyle(selected ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected
                                          ? AnyShapeStyle(Theme.accentGradient(.blue))
                                          : AnyShapeStyle(Color.white.opacity(0.08)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 概要

    private var summary: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Blue.bright)

            Text(summaryText)
                .font(Theme.label(12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Blue.base.opacity(0.12))
        }
    }

    private var summaryText: String {
        let r = rules
        var parts: [String] = []
        parts.append(r.maximumGames == 1 ? "一局定胜负" : "\(r.maximumGames) 局 \(r.gamesToWin) 胜")
        parts.append("\(r.pointsToWin) 分")
        if let deuce = r.deuceAt {
            parts.append("\(deuce) 平后净胜 2 分")
        }
        parts.append(r.cap == nil ? "无封顶" : "\(r.cap!) 分封顶")
        return parts.joined(separator: " · ")
    }
}

// MARK: - 规则加减控件

/// 规则里用的小号加减控件：`[ − | 21 分 | + ]`。
///
/// 样式和计分面板上的 `MinusButton` 一致，但可以加也可以减。
private struct RuleStepper: View {
    let value: Int
    let range: ClosedRange<Int>
    let unit: String
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            button(symbol: "minus", enabled: value > range.lowerBound) { onChange(value - 1) }

            Text("\(value) \(unit)")
                .font(Theme.scoreFont(17))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 62)
                .contentTransition(.numericText())

            button(symbol: "plus", enabled: value < range.upperBound) { onChange(value + 1) }
        }
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
        }
    }

    private func button(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard enabled else { return }
            Haptics.selection()
            withAnimation(.snappy(duration: 0.24)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(enabled ? Theme.Blue.bright : .white.opacity(0.2))
                .frame(width: 38, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
