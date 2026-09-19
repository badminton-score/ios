//
//  ResultOverlay.swift
//  羽毛球计分器
//
//  整场比赛结束后的胜利画面：彩带、奖杯与大比分。
//

import SwiftUI

struct ResultOverlay: View {
    var state: MatchState
    var winner: Side
    var onRematch: () -> Void
    var onHome: () -> Void

    @State private var appeared = false
    @State private var trophyPop = false

    private var accent: Color { Theme.accent(winner) }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.55))
                .ignoresSafeArea()

            ConfettiView(side: winner)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                trophy

                VStack(spacing: 8) {
                    Text("\(state.name(of: winner)) 获胜")
                        .font(Theme.label(40, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.glow(winner).opacity(0.65), radius: 22)

                    Text("大比分 \(state.gamesLine)")
                        .font(Theme.label(18, weight: .semibold))
                        .foregroundStyle(accent)

                    Text(state.historyLine)
                        .font(Theme.label(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onRematch) {
                        Text("再来一场")
                            .font(Theme.label(17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.accentGradient(winner))
                            }
                            .shadow(color: Theme.glow(winner).opacity(0.5), radius: 20, y: 8)
                    }
                    .buttonStyle(.plain)

                    Button(action: onHome) {
                        Text("返回首页")
                            .font(Theme.label(17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5).delay(0.15)) { trophyPop = true }
        }
    }

    private var trophy: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Theme.glow(winner).opacity(0.55), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: 130
                ))
                .frame(width: 260, height: 260)

            Image(systemName: "trophy.fill")
                .font(.system(size: 92, weight: .bold))
                .foregroundStyle(Theme.accentGradient(winner))
                .shadow(color: Theme.glow(winner).opacity(0.8), radius: 26, y: 8)
                .scaleEffect(trophyPop ? 1 : 0.5)
                .rotationEffect(.degrees(trophyPop ? 0 : -12))
        }
    }
}
