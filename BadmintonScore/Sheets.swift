//
//  Sheets.swift
//  赛点
//
//  下一局确认、对战记录与设置面板。
//

import SwiftUI

// MARK: - 一局结束

struct NextGameSheet: View {
    var state: MatchState
    var winner: Side
    var red: Int
    var blue: Int
    var game: Int
    var onContinue: () -> Void
    var onClose: () -> Void

    @State private var appeared = false

    private var accent: Color { Theme.accent(winner) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Theme.glow(winner).opacity(0.4), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 100
                    ))
                    .frame(width: 180, height: 180)

                Image(systemName: "flag.checkered")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(Theme.accentGradient(winner))
                    .shadow(color: Theme.glow(winner).opacity(0.7), radius: 18)
                    .scaleEffect(appeared ? 1 : 0.6)
            }
            .padding(.top, 26)

            Text("第 \(game) 局结束")
                .font(Theme.label(15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 4)

            Text("\(state.name(of: winner)) 拿下本局")
                .font(Theme.label(24, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.top, 2)

            HStack(spacing: 14) {
                Text("\(red)")
                    .foregroundStyle(Theme.accent(.red))
                Text(":")
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(blue)")
                    .foregroundStyle(Theme.accent(.blue))
            }
            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
            .padding(.top, 10)

            HStack(spacing: 8) {
                Circle().fill(Theme.accent(.red)).frame(width: 8, height: 8)
                Text("\(state.redName) \(state.redGames)")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("·").foregroundStyle(.white.opacity(0.3))
                Text("\(state.blueGames) \(state.blueName)")
                    .font(Theme.label(14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Circle().fill(Theme.accent(.blue)).frame(width: 8, height: 8)
            }
            .padding(.top, 12)

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("开始第 \(game + 1) 局")
                        .font(Theme.label(17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Theme.accentGradient(winner))
                        }
                        .shadow(color: Theme.glow(winner).opacity(0.5), radius: 18, y: 8)
                }
                .buttonStyle(.plain)

                Button(action: onClose) {
                    Text("稍后再开始")
                        .font(Theme.label(15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color(red: 0.043, green: 0.047, blue: 0.059)
                RadialGradient(
                    colors: [Theme.glow(winner).opacity(0.22), .clear],
                    center: .top,
                    startRadius: 10,
                    endRadius: 420
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

// MARK: - 对战记录

struct MatchHistorySheet: View {
    @Bindable var store: MatchStore
    @Environment(\.dismiss) private var dismiss

    private var state: MatchState { store.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    seriesCard

                    if !state.gameScores.isEmpty {
                        section(title: "各局比分") {
                            VStack(spacing: 0) {
                                ForEach(state.gameScores.reversed()) { score in
                                    gameRow(score)
                                    if score.id != state.gameScores.first?.id {
                                        Divider().overlay(Color.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                    }

                    section(title: "第 \(state.currentGame) 局逐分") {
                        if currentGameLog.isEmpty {
                            Text("本局还没有得分记录")
                                .font(Theme.label(14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.vertical, 10)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(currentGameLog.reversed()) { entry in
                                    logRow(entry)
                                    Divider().overlay(Color.white.opacity(0.06))
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("对战记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(Theme.label(16, weight: .semibold))
                }
            }
        }
    }

    private var currentGameLog: [MatchLogEntry] {
        state.log.filter { $0.game == state.currentGame }
    }

    private var seriesCard: some View {
        HStack(spacing: 16) {
            teamColumn(.red)
            VStack(spacing: 2) {
                Text("大比分")
                    .font(Theme.label(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Text(state.gamesLine)
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            }
            teamColumn(.blue)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.cardStroke, lineWidth: 1)
                }
        }
    }

    private func teamColumn(_ side: Side) -> some View {
        VStack(spacing: 6) {
            Text(state.name(of: side))
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Text("局 \(state.games(of: side))")
                .font(Theme.label(12, weight: .semibold))
                .foregroundStyle(Theme.accent(side))
        }
        .frame(maxWidth: .infinity)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
            content()
        }
    }

    private func gameRow(_ score: GameScore) -> some View {
        HStack(spacing: 12) {
            Text("第 \(score.game) 局")
                .font(Theme.label(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            HStack(spacing: 10) {
                Text("\(score.red)")
                    .foregroundStyle(score.winner == .red ? Theme.accent(.red) : .white.opacity(0.5))
                Text(":")
                    .foregroundStyle(.white.opacity(0.25))
                Text("\(score.blue)")
                    .foregroundStyle(score.winner == .blue ? Theme.accent(.blue) : .white.opacity(0.5))
            }
            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())

            Image(systemName: "crown.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.accent(score.winner))
        }
        .padding(.vertical, 11)
    }

    private func logRow(_ entry: MatchLogEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.accent(entry.side))
                .frame(width: 8, height: 8)
            Text(entry.isCorrection ? "撤销" : state.name(of: entry.side))
                .font(Theme.label(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text("\(entry.redPoints) : \(entry.bluePoints)")
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 9)
    }
}

// MARK: - 设置

struct SettingsSheet: View {
    @Bindable var store: MatchStore
    var onExit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    private var state: MatchState { store.state }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    modeSection
                    rulesSection
                    serverSection
                    dangerSection
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("赛制与设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(Theme.label(16, weight: .semibold))
                }
            }
        }
        .confirmationDialog("要清空当前比分并重新开始吗？", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("重新开始这场比赛", role: .destructive) {
                store.rematch()
                dismiss()
            }
            Button("返回首页", role: .destructive) {
                store.reset(fromHome: true)
                dismiss()
                onExit()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("计分模式")
            VStack(spacing: 10) {
                ForEach(ScoringMode.allCases) { mode in
                    modeRow(mode)
                }

                if state.mode == .custom {
                    CustomRulesView(store: store)
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Theme.cardStroke, lineWidth: 1)
                                }
                        }
                        .padding(.top, 4)
                }
            }
        }
    }

    private func modeRow(_ mode: ScoringMode) -> some View {
        let isSelected = mode == state.mode
        return Button {
            guard mode != state.mode else { return }
            Haptics.selection()
            withAnimation(.snappy(duration: 0.3)) {
                store.changeMode(mode)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? AnyShapeStyle(Theme.accentGradient(.blue)) : AnyShapeStyle(Color.white.opacity(0.07)))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(Theme.label(16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(mode.subtitle)
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 6)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.accent(.blue) : .white.opacity(0.22))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isSelected ? Theme.accent(.blue).opacity(0.55) : .white.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var rulesSection: some View {
        let rules = state.mode.rules
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("规则说明")
            VStack(alignment: .leading, spacing: 10) {
                ruleLine("flag.fill", "每局 \(rules.pointsToWin) 分，\(rules.gamesToWin == 1 ? "一局定胜负" : "赢下 \(rules.gamesToWin) 局者胜")")
                if let deuce = rules.deuceAt, let cap = rules.cap {
                    ruleLine("equal.circle.fill", "\(deuce) 平后需净胜 2 分，\(cap) 分封顶")
                    ruleLine("exclamationmark.circle.fill", "\(cap - 1) 平时先到 \(cap) 分者胜")
                } else if let deuce = rules.deuceAt {
                    ruleLine("equal.circle.fill", "\(deuce) 平后需净胜 2 分，无封顶")
                } else {
                    ruleLine("bolt.fill", "先到 \(rules.pointsToWin) 分者胜")
                }
                ruleLine(
                    rules.rallyPoint ? "arrow.triangle.2.circlepath" : "figure.badminton",
                    rules.rallyPoint ? "每球得分制：得分方获得发球权" : "发球得分制：只有发球方得分才计分"
                )
                ruleLine("arrow.left.arrow.right", "每局结束后交换场地，胜方下一局先发球")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    }
            }
        }
    }

    // MARK: 单打 / 双打

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("上场人数")
            HStack(spacing: 10) {
                ForEach(MatchFormat.allCases) { format in
                    let isSelected = state.format == format
                    Button {
                        guard !isSelected else { return }
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.3)) { store.setFormat(format) }
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: format.symbol)
                                .font(.system(size: 14, weight: .bold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.title)
                                    .font(Theme.label(15, weight: .bold))
                                Text(format.subtitle)
                                    .font(Theme.label(11, weight: .medium))
                                    .opacity(0.7)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected
                                      ? AnyShapeStyle(Theme.accentGradient(.blue))
                                      : AnyShapeStyle(Color.white.opacity(0.06)))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 队员名

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(state.format == .doubles ? "队员" : "名字")

            ForEach(Side.allCases) { side in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.accent(side))
                            .frame(width: 8, height: 8)
                        Text(side == .red ? "红方" : "蓝方")
                            .font(Theme.label(13, weight: .bold))
                            .foregroundStyle(Theme.bright(side))
                    }

                    let names = state.players(of: side)
                    ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                        PlayerNameField(
                            placeholder: index == 0 ? side.defaultName : "队友",
                            text: name,
                            accent: Theme.accent(side)
                        ) { newValue in
                            store.renamePlayer(side, index: index, to: newValue)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Theme.cardStroke, lineWidth: 1)
                        }
                }
            }

            if state.format == .doubles {
                Text("发球按 BWF 轮转：发球方连续得分时同一人继续发，接发球方夺回发球权时换人发。")
                    .font(Theme.label(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("本局先发球")
            HStack(spacing: 10) {
                ForEach(Side.allCases) { side in
                    let isSelected = state.server == side
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.28)) { store.setFirstServer(side) }
                    } label: {
                        Text(state.name(of: side))
                            .font(Theme.label(15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isSelected ? AnyShapeStyle(Theme.accentGradient(side)) : AnyShapeStyle(Color.white.opacity(0.06)))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(isSelected ? .clear : .white.opacity(0.1), lineWidth: 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("发球区提示按 BWF 规则显示：发球方得分为偶数时发右区，奇数时发左区。")
                .font(Theme.label(11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var dangerSection: some View {
        Button {
            showResetConfirm = true
        } label: {
            Label("重新开始 / 返回首页", systemImage: "arrow.counterclockwise.circle.fill")
                .font(Theme.label(15, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.12))
                }
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.label(13, weight: .bold))
            .foregroundStyle(.white.opacity(0.5))
    }

    private func ruleLine(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 18)
            Text(text)
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 队员名输入框

/// 一个队员的名字输入框。失焦或回车时提交。
private struct PlayerNameField: View {
    let placeholder: String
    let text: String
    let accent: Color
    let onSubmit: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accent.opacity(0.9))
                .frame(width: 20)

            TextField(placeholder, text: $draft)
                .font(Theme.label(15, weight: .semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit() }

            if !draft.isEmpty {
                Button {
                    draft = ""
                    commit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(focused ? accent.opacity(0.6) : .clear, lineWidth: 1.2)
                }
        }
        .onAppear { draft = text }
        .onChange(of: text) { _, new in
            if !focused { draft = new }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != text { onSubmit(trimmed) }
    }
}
