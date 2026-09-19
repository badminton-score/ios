//
//  HomeView.swift
//  羽毛球计分器
//
//  首页：选择计分模式、设置首发方，进入比赛。
//

import SwiftUI

struct AppEntry: View {
    @State private var store: MatchStore
    @State private var history = MatchHistoryStore()
    @State private var isShowingMatch = false
    /// 首次进入首页时若存在未完成的比赛，提供「继续上一场」入口。
    @State private var canResume: Bool

    init() {
        #if DEBUG
        // 截图与联调用：-uiPreview <home|match|gamePoint|gameEnd|win> 直接进入指定画面。
        if let preview = DebugPreview.current {
            _store = State(initialValue: preview.store)
            _isShowingMatch = State(initialValue: preview.showsMatch)
            _canResume = State(initialValue: false)
            return
        }
        #endif
        let restored = MatchStore.restoring()
        _store = State(initialValue: restored ?? MatchStore())
        _canResume = State(initialValue: restored != nil)
    }

    var body: some View {
        ZStack {
            if isShowingMatch {
                MatchView(store: store) {
                    withAnimation(.snappy(duration: 0.42)) { isShowingMatch = false }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HomeView(
                    store: store,
                    history: history,
                    canResume: canResume,
                    onStart: {
                        canResume = false
                        withAnimation(.snappy(duration: 0.42)) { isShowingMatch = true }
                    }
                )
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.Blue.base)
    }
}

#if DEBUG
/// 仅在 Debug 构建中启用：让模拟器截图脚本可以直接落到某个界面状态。
@MainActor
struct DebugPreview {
    let store: MatchStore
    let showsMatch: Bool

    static var current: DebugPreview? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uiPreview"), index + 1 < arguments.count else { return nil }
        let scene = arguments[index + 1]
        UserDefaults.standard.removeObject(forKey: "badminton.match.archive.v1")

        switch scene {
        case "match":
            var state = MatchState(mode: .bwf21, redName: "林丹", blueName: "李宗伟")
            state = play(state, red: 11, blue: 9, server: .red)
            return DebugPreview(store: MatchStore(state: state), showsMatch: true)

        case "gamePoint":
            var state = MatchState(mode: .bwf21, redName: "红方", blueName: "蓝方")
            state = play(state, red: 20, blue: 19, server: .red)
            return DebugPreview(store: MatchStore(state: state), showsMatch: true)

        case "deuce":
            var state = MatchState(mode: .bwf21, redName: "红方", blueName: "蓝方")
            state = play(state, red: 29, blue: 29, server: .blue)
            return DebugPreview(store: MatchStore(state: state), showsMatch: true)

        case "gameEnd":
            let store = MatchStore(state: MatchState(mode: .bwf21, redName: "红方", blueName: "蓝方"))
            playGame(store, red: 21, blue: 19)
            return DebugPreview(store: store, showsMatch: true)

        case "win":
            let store = MatchStore(state: MatchState(mode: .bwf21, redName: "红方", blueName: "蓝方"))
            playGame(store, red: 21, blue: 19)
            store.startNextGame()
            playGame(store, red: 21, blue: 14)
            print("DBG win: games=\(store.state.redGames):\(store.state.blueGames) over=\(store.state.isMatchOver) presentation=\(String(describing: store.presentation)) scores=\(store.state.gameScores) pts=\(store.state.redPoints):\(store.state.bluePoints)")
            return DebugPreview(store: store, showsMatch: true)

        case "deuceWin":
            let store = MatchStore(state: MatchState(mode: .bwf21, redName: "红方", blueName: "蓝方"))
            playGame(store, red: 22, blue: 20)
            store.startNextGame()
            playGame(store, red: 30, blue: 29)
            return DebugPreview(store: store, showsMatch: true)

        case "legacy15":
            var state = MatchState(mode: .traditional15, redName: "A 队", blueName: "B 队")
            state = play(state, red: 14, blue: 13, server: .blue)
            return DebugPreview(store: MatchStore(state: state), showsMatch: true)

        default:
            return DebugPreview(store: MatchStore(), showsMatch: false)
        }
    }

    /// 交替加分直到指定比分；因为领先方始终先到分，不会误触发平分延长。
    private static func playGame(_ store: MatchStore, red: Int, blue: Int) {
        for _ in 0..<max(red, blue) {
            if store.state.redPoints < red { store.addPoint(to: .red) }
            if store.state.bluePoints < blue { store.addPoint(to: .blue) }
        }
    }

    private static func play(_ state: MatchState, red: Int, blue: Int, server: Side) -> MatchState {
        var next = state
        next.redPoints = red
        next.bluePoints = blue
        next.server = server
        return next
    }
}
#endif

// MARK: - 首页

struct HomeView: View {
    @Bindable var store: MatchStore
    @Bindable var history: MatchHistoryStore
    var canResume: Bool
    var onStart: () -> Void

    @AppStorage("badminton.selectedMode") private var selectedModeRaw: String = ScoringMode.bwf21.rawValue
    @State private var appeared = false
    @State private var isShowingRecords = false

    private var mode: ScoringMode {
        get { ScoringMode(rawValue: selectedModeRaw) ?? .bwf21 }
        nonmutating set { selectedModeRaw = newValue.rawValue }
    }

    private var hasProgress: Bool {
        store.state.redPoints > 0 || store.state.bluePoints > 0 || !store.state.gameScores.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            orbs

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    hero
                    if canResume && hasProgress { resumeCard }
                    modeSection
                    firstServerSection
                    startButton
                    recordsButton
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true }
        }
        .sheet(isPresented: $isShowingRecords) {
            RecordsView(history: history)
        }
    }

    // MARK: 对战记录入口

    private var recordsButton: some View {
        Button {
            Haptics.selection()
            isShowingRecords = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Blue.bright)

                Text("对战记录")
                    .font(Theme.label(15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                if history.total > 0 {
                    Text("\(history.redWins) : \(history.blueWins)")
                        .font(Theme.scoreFont(14))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 装饰

    private var orbs: some View {
        ZStack {
            Circle()
                .fill(Theme.glow(.red).opacity(0.22))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: -140, y: -300)
            Circle()
                .fill(Theme.glow(.blue).opacity(0.22))
                .frame(width: 380, height: 380)
                .blur(radius: 120)
                .offset(x: 150, y: 120)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 头部

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Theme.glow(.blue).opacity(0.45), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 90
                    ))
                    .frame(width: 180, height: 180)

                Image(systemName: "bird.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Theme.accentGradient(.blue))
                    .shadow(color: Theme.glow(.blue).opacity(0.7), radius: 20)
                    .rotationEffect(.degrees(appeared ? 0 : -18))
                    .offset(y: appeared ? 0 : 12)
            }
            .frame(height: 130)

            VStack(spacing: 6) {
                Text("羽毛球计分器")
                    .font(Theme.label(30, weight: .heavy))
                    .foregroundStyle(.white)
                Text("红蓝对抗 · 规则内置 · 一指计分")
                    .font(Theme.label(13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: 继续上一场

    private var resumeCard: some View {
        Button {
            Haptics.selection()
            onStart()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Theme.accentGradient(.red))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("继续上一场比赛")
                        .font(Theme.label(15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(store.state.mode.title) · 第 \(store.state.currentGame) 局 · \(store.state.gamesLine)")
                        .font(Theme.label(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: 模式选择

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("计分模式")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 10) {
                ForEach(ScoringMode.allCases) { item in
                    ModeCard(mode: item, isSelected: item == mode, selectedMode: mode) {
                        guard item != mode else { return }
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.34)) {
                            mode = item
                            store.changeMode(item)
                        }
                    }
                }

                // 选了「自定义」就把规则编辑器展开在下面
                if mode == .custom {
                    CustomRulesView(store: store, compact: true)
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
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: 首发方

    private var firstServerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("开局先发球")
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 10) {
                ForEach(Side.allCases) { side in
                    let isSelected = store.state.server == side
                    Button {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.28)) { store.setFirstServer(side) }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Theme.accent(side))
                                .frame(width: 9, height: 9)
                            Text(store.state.name(of: side))
                                .font(Theme.label(15, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(isSelected ? AnyShapeStyle(Theme.accentGradient(side)) : AnyShapeStyle(Color.white.opacity(0.06)))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(isSelected ? .clear : .white.opacity(0.1), lineWidth: 1)
                                }
                        }
                        .shadow(color: isSelected ? Theme.glow(side).opacity(0.4) : .clear, radius: 16, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: 开始

    private var startButton: some View {
        Button {
            Haptics.critical()
            store.changeMode(mode)
            onStart()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("开始比赛")
                    .font(Theme.label(18, weight: .heavy))
            }
            .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.09))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.white, Color(white: 0.86)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .shadow(color: .white.opacity(0.22), radius: 24, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var footer: some View {
        Text(mode.detail)
            .font(Theme.label(11, weight: .medium))
            .foregroundStyle(.white.opacity(0.32))
            .multilineTextAlignment(.center)
    }
}

// MARK: - 模式卡片

private struct ModeCard: View {
    var mode: ScoringMode
    var isSelected: Bool
    var selectedMode: ScoringMode
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected
                                  ? AnyShapeStyle(Theme.accentGradient(mode == selectedMode ? .blue : .red))
                                  : AnyShapeStyle(Color.white.opacity(0.07)))
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

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background {
                            Circle().fill(Theme.accentGradient(.blue))
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(isSelected ? Theme.Blue.base.opacity(0.5) : .white.opacity(0.06), lineWidth: 1)
                    }
            }
            .scaleEffect(isSelected ? 1 : 0.99)
        }
        .buttonStyle(.plain)
    }
}
