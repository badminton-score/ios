//
//  RecordsView.swift
//  羽毛球计分器
//
//  对战记录列表 + 简单统计。
//

import SwiftUI

struct RecordsView: View {
    @Bindable var history: MatchHistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if history.records.isEmpty {
                    empty
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            statsCard
                            ForEach(history.records) { record in
                                RecordRow(record: record) {
                                    withAnimation(.snappy(duration: 0.28)) {
                                        history.delete(record)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("对战记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !history.records.isEmpty {
                        Button("清空") { showClearConfirm = true }
                            .font(Theme.label(15, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(Theme.label(16, weight: .semibold))
                }
            }
            .confirmationDialog("清空全部对战记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) {
                    withAnimation(.snappy(duration: 0.3)) { history.clear() }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 空状态

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
            Text("还没有打完的比赛")
                .font(Theme.label(17, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Text("打完一整场就会自动记在这里")
                .font(Theme.label(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - 统计

    private var statsCard: some View {
        HStack(spacing: 0) {
            stat("总场次", "\(history.total)", .white)
            divider
            stat("红方胜", "\(history.redWins)", Theme.Red.bright)
            divider
            stat("蓝方胜", "\(history.blueWins)", Theme.Blue.bright)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.cardStroke, lineWidth: 1)
                }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 26)
    }

    private func stat(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.scoreFont(24))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(title)
                .font(Theme.label(11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 单条记录

private struct RecordRow: View {
    let record: MatchRecord
    let onDelete: () -> Void

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(Self.formatter.string(from: record.date))
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))

                Text(record.mode.title)
                    .font(Theme.label(11, weight: .bold))
                    .foregroundStyle(Theme.Blue.bright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        Capsule().fill(Theme.Blue.base.opacity(0.16))
                    }

                if record.format == .doubles {
                    Text("双打")
                        .font(Theme.label(11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            Capsule().fill(Color.white.opacity(0.08))
                        }
                }

                Spacer(minLength: 0)

                Text(record.durationText)
                    .font(Theme.label(11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }

            HStack(alignment: .center, spacing: 10) {
                side(record.redName, score: record.gamesLine,
                     isWinner: record.winner == .red, tint: Theme.Red.base)

                Text("vs")
                    .font(Theme.label(11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))

                side(record.blueName, score: record.gamesLine,
                     isWinner: record.winner == .blue, tint: Theme.Blue.base)
            }

            if !record.scoreLine.isEmpty {
                Text(record.scoreLine)
                    .font(Theme.label(12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            record.winner == .red
                                ? Theme.Red.base.opacity(0.28)
                                : Theme.Blue.base.opacity(0.28),
                            lineWidth: 1
                        )
                }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除这条", systemImage: "trash")
            }
        }
    }

    private func side(_ name: String, score: String, isWinner: Bool, tint: Color) -> some View {
        HStack(spacing: 7) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                    .transition(.scale)
            }
            Text(name)
                .font(Theme.label(14, weight: isWinner ? .bold : .medium))
                .foregroundStyle(isWinner ? .white : .white.opacity(0.55))
                .lineLimit(1)
            Text(score)
                .font(Theme.scoreFont(14))
                .foregroundStyle(isWinner ? tint : Color.white.opacity(0.4))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
