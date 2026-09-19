//
//  MatchView.swift
//  羽毛球计分器
//
//  计分主界面：上下两块球队面板，点击面板加一分，角落按钮减一分。
//

import SwiftUI

struct MatchView: View {
    @Bindable var store: MatchStore
    var onExit: () -> Void

    /// 全局动画时钟，供两块面板的光晕共享。
    @State private var clock: TimeInterval = 0
    @State private var redPulse: Double = 0
    @State private var bluePulse: Double = 0
    @State private var redShake: CGFloat = 0
    @State private var blueShake: CGFloat = 0

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    private var state: MatchState { store.state }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ambient

            VStack(spacing: 10) {
                topBar
                ScorePanel(
                    side: .red,
                    name: state.name(of: .red),
                    servingName: state.format == .doubles && state.server == .red
                        ? state.players(of: .red)[state.serveIndex(of: .red)]
                        : nil,
                    points: state.redPoints,
                    games: state.redGames,
                    isServing: state.server == .red,
                    serveBox: state.serveBox,
                    isMatchPoint: store.isMatchPoint(.red),
                    isGamePoint: store.isGamePoint(.red),
                    isLocked: store.isLocked,
                    time: clock,
                    pulse: redPulse,
                    shake: redShake,
                    onScore: { addPoint(to: .red) },
                    onRemove: { removePoint(from: .red) },
                    onRename: { store.rename(.red, to: $0) }
                )
                ScorePanel(
                    side: .blue,
                    name: state.name(of: .blue),
                    servingName: state.format == .doubles && state.server == .blue
                        ? state.players(of: .blue)[state.serveIndex(of: .blue)]
                        : nil,
                    points: state.bluePoints,
                    games: state.blueGames,
                    isServing: state.server == .blue,
                    serveBox: state.serveBox,
                    isMatchPoint: store.isMatchPoint(.blue),
                    isGamePoint: store.isGamePoint(.blue),
                    isLocked: store.isLocked,
                    time: clock,
                    pulse: bluePulse,
                    shake: blueShake,
                    onScore: { addPoint(to: .blue) },
                    onRemove: { removePoint(from: .blue) },
                    onRename: { store.rename(.blue, to: $0) }
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)

            toastLayer
        }
        .onReceive(ticker) { date in
            clock = date.timeIntervalSinceReferenceDate
        }
        .overlay {
            if case .matchResult(let side) = store.presentation {
                ResultOverlay(
                    state: state,
                    winner: side,
                    onRematch: { withAnimation(.snappy) { store.rematch() } },
                    onHome: { store.dismissPresentation(); onExit() }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(10)
            }
        }
        .sheet(item: nextGameBinding) { presentation in
            if case .nextGame(let side, let red, let blue, let game) = presentation {
                NextGameSheet(
                    state: state,
                    winner: side,
                    red: red,
                    blue: blue,
                    game: game,
                    onContinue: { store.startNextGame() },
                    onClose: { store.dismissPresentation() }
                )
                .presentationDetents([.height(430)])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $store.isShowingHistory) {
            MatchHistorySheet(store: store)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(34)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.isShowingSettings) {
            SettingsSheet(store: store, onExit: {
                store.isShowingSettings = false
                onExit()
            })
            .presentationDetents([.large])
            .presentationCornerRadius(34)
            .presentationDragIndicator(.visible)
        }
        .animation(.snappy(duration: 0.4), value: store.presentation)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: store.lastEventToken)
    }

    /// 只把「下一局」交给 sheet，胜利画面走 overlay。
    ///
    /// 注意：setter 只在系统真的关闭 sheet 时才清空，且必须判断当前确实是「下一局」，
    /// 否则 SwiftUI 读取该 Binding 时会把胜利画面一并清掉。
    private var nextGameBinding: Binding<MatchPresentation?> {
        Binding(
            get: {
                if case .nextGame = store.presentation { return store.presentation }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if case .nextGame = store.presentation { store.dismissPresentation() }
            }
        )
    }

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(Theme.glow(.red).opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 130)
                .offset(x: -130, y: -330)
            Circle()
                .fill(Theme.glow(.blue).opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 130)
                .offset(x: 140, y: 340)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            GlassButton(systemName: "chevron.left", size: 38) { onExit() }

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Text("第 \(state.currentGame) 局")
                    .font(Theme.label(13, weight: .bold))
                    .foregroundStyle(.white)
                Text(state.mode.title)
                    .font(Theme.label(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay { Capsule(style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1) }
            }

            Spacer(minLength: 4)

            GlassButton(systemName: "arrow.uturn.backward", size: 38, isEnabled: store.canUndo) { undo() }
            GlassButton(systemName: "list.bullet", size: 38) { store.isShowingHistory = true }
            GlassButton(systemName: "slider.horizontal.3", size: 38) { store.isShowingSettings = true }
        }
        .padding(.horizontal, 4)
    }

    private var toastLayer: some View {
        VStack {
            Spacer()
            if let toast = store.toast {
                ToastView(message: toast)
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.toast)
    }

    // MARK: - 动作

    private func addPoint(to side: Side) {
        guard !store.isLocked else { return }
        let wasGamePoint = store.isGamePoint(side)
        let wasMatchPoint = store.isMatchPoint(side)
        store.addPoint(to: side)

        if wasMatchPoint {
            Haptics.win()
        } else if wasGamePoint {
            Haptics.critical()
        } else {
            Haptics.point()
        }

        pulse(side)
    }

    private func undo() {
        guard store.canUndo, !store.isLocked else { return }
        Haptics.correction()
        let side = store.lastUndoneSide
        store.undo()
        if let side { shake(side) }
    }

    /// 减分：撤销最近一次计分，并给出纠正反馈。
    private func removePoint(from side: Side) {
        guard store.canUndo, !store.isLocked else { return }
        Haptics.correction()
        store.removePoint(from: side)
        shake(side)
    }

    private func pulse(_ side: Side) {
        let animation = Animation.spring(response: 0.45, dampingFraction: 0.7)
        withAnimation(animation) {
            if side == .red { redPulse = 1 } else { bluePulse = 1 }
        }
        withAnimation(.easeOut(duration: 0.55).delay(0.05)) {
            if side == .red { redPulse = 0 } else { bluePulse = 0 }
        }
    }

    private func shake(_ side: Side) {
        let offsets: [CGFloat] = [0, -9, 8, -5, 3, 0]
        for (index, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.045) {
                withAnimation(.linear(duration: 0.05)) {
                    if side == .red { redShake = offset } else { blueShake = offset }
                }
            }
        }
    }
}

// MARK: - 单方计分面板

struct ScorePanel: View {
    var side: Side
    var name: String
    /// 双打时这一方具体谁在发球；单打传 nil。
    var servingName: String?
    var points: Int
    var games: Int
    var isServing: Bool
    var serveBox: String
    var isMatchPoint: Bool
    var isGamePoint: Bool
    var isLocked: Bool
    var time: TimeInterval
    var pulse: Double
    var shake: CGFloat
    var onScore: () -> Void
    var onRemove: () -> Void
    var onRename: (String) -> Void

    @State private var pressed = false
    @State private var editingName = ""
    @FocusState private var nameFocused: Bool

    private var accent: Color { Theme.accent(side) }

    var body: some View {
        ZStack {
            // 面板基底
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Theme.panelGradient(side))
                .overlay {
                    CourtGlow(side: side, time: time, pulse: pulse)
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accent.opacity(isServing ? 0.85 : 0.35 + pulse * 0.4),
                                    accent.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isServing ? 2 : 1.2
                        )
                }
                .shadow(color: Theme.glow(side).opacity(0.18 + pulse * 0.35), radius: 24 + pulse * 26, y: 10)

            content
        }
        .scaleEffect(pressed ? 0.985 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pressed)
        .offset(x: shake)
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .onTapGesture { onScore() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isLocked, !pressed else { return }
                    Haptics.selection()
                    pressed = true
                }
                .onEnded { _ in pressed = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) \(points) 分")
        .accessibilityHint("轻点加一分")
        .accessibilityAddTraits(.isButton)
        .onAppear { editingName = name }
        .onChange(of: name) { _, newValue in
            if !nameFocused { editingName = newValue }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            score
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                TextField("", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(Theme.label(19, weight: .heavy))
                    .foregroundStyle(.white)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                    .onChange(of: nameFocused) { _, focused in
                        if !focused { commitName() }
                    }
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 6) {
                    Text("已胜 \(games) 局")
                        .font(Theme.label(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))

                    if isMatchPoint {
                        PointBadge(text: "赛点", side: side)
                    } else if isGamePoint {
                        PointBadge(text: "局点", side: side)
                    }
                }
                .animation(.snappy, value: isMatchPoint)
                .animation(.snappy, value: isGamePoint)
            }

            Spacer()

            if isServing {
                ServeIndicator(side: side, box: serveBox, servingName: servingName)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isServing)
    }

    private var score: some View {
        AnimatedNumber(value: points, size: 136, color: .white)
            .shadow(color: Theme.glow(side).opacity(0.55), radius: 24, y: 6)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Theme.accentGradient(side))
                    .frame(width: isServing ? 74 : 34, height: 5)
                    .offset(y: 10)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: isServing)
            }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Label {
                Text("轻点面板 · 加一分")
            } icon: {
                Image(systemName: "hand.tap.fill")
            }
            .font(Theme.label(11, weight: .medium))
            .foregroundStyle(.white.opacity(0.34))

            Spacer()

            MinusButton(side: side, isEnabled: points > 0 && !isLocked) {
                onRemove()
            }
        }
    }

    private func commitName() {
        nameFocused = false
        onRename(editingName)
    }
}
