//
//  Components.swift
//  羽毛球计分器
//
//  可复用的视觉组件：比分数字动画、面板光晕、发球指示、胜利彩带。
//

import SwiftUI

// MARK: - 会弹跳的比分数字

/// 比分变化时先放大回弹，再轻微拉伸，形成连贯的「跳一下」反馈。
struct AnimatedNumber: View {
    var value: Int
    var size: CGFloat
    var color: Color
    var weight: Font.Weight = .bold

    @State private var bump: CGFloat = 1
    @State private var stretch: CGFloat = 1

    var body: some View {
        Text("\(value)")
            .font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
            .scaleEffect(x: bump * (2 - stretch), y: bump * stretch, anchor: .center)
            .contentTransition(.numericText(value: Double(value)))
            .animation(.snappy(duration: 0.3, extraBounce: 0.1), value: value)
            .onChange(of: value) { _, _ in
                bump = 1.22
                stretch = 0.86
                withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
                    bump = 0.97
                    stretch = 1.06
                } completion: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                        bump = 1
                        stretch = 1
                    }
                }
            }
    }
}

// MARK: - 场地光晕

/// 面板内的流动光带，呼应羽毛球场地的球网与地胶光泽。
struct CourtGlow: View {
    var side: Side
    /// 由外层统一驱动的动画时间，避免多个 Canvas 各自计时。
    var time: TimeInterval
    /// 得分的瞬间传入一个 0…1 的脉冲值。
    var pulse: Double = 0

    private var phases: [Double] { side == .red ? [0, 0.9, 1.7] : [0.4, 1.3, 2.2] }

    var body: some View {
        Canvas { context, size in
            let accent = Theme.glow(side)
            for (index, seed) in phases.enumerated() {
                let amplitude = size.height * (0.035 + Double(index) * 0.012)
                let speed = 0.28 + Double(index) * 0.11
                let baselineRatio = 0.66 + Double(index) * 0.11
                let opacity = (0.16 - Double(index) * 0.035) + pulse * 0.30

                var path = Path()
                let steps = 40
                for step in 0...steps {
                    let ratio = Double(step) / Double(steps)
                    let x = ratio * size.width
                    let angle = ratio * .pi * (1.4 + Double(index) * 0.5) + seed + time * speed
                    let y = size.height * baselineRatio - sin(angle) * amplitude - pulse * size.height * 0.06
                    if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [accent.opacity(opacity), accent.opacity(opacity * 0.12), .clear]),
                        startPoint: CGPoint(x: size.width / 2, y: size.height * 0.5),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 发球指示

/// 正在发球的一方显示的羽毛球图标 + 出球区提示。
struct ServeIndicator: View {
    var side: Side
    var box: String

    @State private var float = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bird.fill")
                .font(.system(size: 13, weight: .bold))
                .offset(y: float ? -2.5 : 1.5)
                .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: float)

            Text("发球 · \(box)")
                .font(Theme.label(12, weight: .bold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(Theme.bright(side))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.accent(side).opacity(0.16))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Theme.accent(side).opacity(0.34), lineWidth: 1)
                }
        }
        .shadow(color: Theme.glow(side).opacity(0.35), radius: 12, y: 3)
        .onAppear { float = true }
    }
}

// MARK: - 局点 / 赛点标签

struct PointBadge: View {
    var text: String
    var side: Side

    @State private var pulse = false

    var body: some View {
        Text(text)
            .font(Theme.label(11, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous).fill(Theme.accentGradient(side))
            }
            .shadow(color: Theme.glow(side).opacity(pulse ? 0.85 : 0.3), radius: pulse ? 16 : 8)
            .scaleEffect(pulse ? 1.04 : 0.98)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - 减分按钮

struct MinusButton: View {
    var side: Side
    var isEnabled: Bool
    var action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.25))
                .frame(width: 42, height: 42)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(isEnabled ? 0.22 : 0.08), lineWidth: 1)
                        }
                }
                .scaleEffect(pressed ? 0.88 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("\(side == .red ? "红方" : "蓝方")减一分")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - 毛玻璃圆形按钮

struct GlassButton: View {
    var systemName: String
    var size: CGFloat = 40
    var isEnabled: Bool = true
    var tint: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint.opacity(isEnabled ? 0.95 : 0.28))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay { Circle().strokeBorder(.white.opacity(isEnabled ? 0.18 : 0.07), lineWidth: 1) }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - 轻提示

struct ToastView: View {
    var message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.symbol)
                .font(.system(size: 12, weight: .bold))
            Text(message.text)
                .font(Theme.label(13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay { Capsule(style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1) }
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 6)
    }
}

// MARK: - 胜利彩带

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGSize
    let startX: Double
    let delay: Double
    let duration: Double
    let drift: Double
    let spin: Double
    let spinSpeed: Double
    let isCapsule: Bool
}

struct ConfettiView: View {
    var side: Side
    var isActive: Bool = true

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.78, blue: 0.25),
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 0.42, green: 0.62, blue: 1.00),
        Color(red: 0.36, green: 0.86, blue: 0.62),
        Color(red: 0.80, green: 0.52, blue: 1.00),
        Color(red: 1.00, green: 1.00, blue: 1.00),
    ]

    @State private var particles: [ConfettiParticle] = []
    @State private var start = Date()
    private let cycle: Double = 4.4

    private var tinted: [Color] {
        [Theme.bright(side), Theme.accent(side)] + Self.palette
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSince(start)
                guard !particles.isEmpty else { return }
                for particle in particles {
                    let cycleIndex = floor((now - particle.delay) / cycle)
                    let local = (now - particle.delay) - cycleIndex * cycle
                    guard local >= 0, local <= particle.duration else { continue }

                    let progress = local / particle.duration
                    let x = particle.startX * size.width
                        + particle.drift * sin(progress * 3.1 + particle.delay * 4) * size.width * 0.14
                        + particle.drift * progress * size.width * 0.06
                    let y = -70 + progress * (size.height + 150)

                    context.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .radians(particle.spin + progress * particle.spinSpeed))
                        let rect = CGRect(
                            x: -particle.size.width / 2,
                            y: -particle.size.height / 2,
                            width: particle.size.width,
                            height: particle.size.height
                        )
                        let path = particle.isCapsule
                            ? Path(roundedRect: rect, cornerRadius: particle.size.height / 2)
                            : Path(rect)
                        layer.fill(path, with: .color(particle.color.opacity(1 - progress * 0.25)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: makeParticles)
    }

    private func makeParticles() {
        start = Date()
        particles = (0..<140).map { index in
            ConfettiParticle(
                color: tinted[index % tinted.count],
                size: CGSize(
                    width: Double.random(in: 5...11),
                    height: Double.random(in: 8...18)
                ),
                startX: Double.random(in: -0.05...1.05),
                delay: Double.random(in: 0...cycle),
                duration: Double.random(in: 2.3...3.4),
                drift: Double.random(in: -1.6...1.6),
                spin: Double.random(in: 0...(2 * .pi)),
                spinSpeed: Double.random(in: -8...8),
                isCapsule: Bool.random()
            )
        }
    }
}

// MARK: - 抬升卡片容器

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.cardStroke, lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }
}
