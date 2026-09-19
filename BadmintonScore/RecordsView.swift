//
//  RecordsView.swift
//  羽毛球计分器
//
//  对战记录：列表 + 统计 + 选择批量删除。
//

import SwiftUI

struct RecordsView: View {
    @Bindable var history: MatchHistoryStore
    @Environment(\.dismiss) private var dismiss

    /// 选择模式：打开后每行前面出现圆圈，可以多选。
    ///
    /// Debug 构建下可以用 -selectRecords 直接进选择模式、
    /// -selectAllRecords 连记录一起选中，方便截图验证。
    @State private var isSelecting = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-selectRecords")
        #else
        return false
        #endif
    }()
    @State private var selection: Set<MatchRecord.ID> = []
    @State private var editMode: EditMode = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-selectRecords") ? .active : .inactive
        #else
        return .inactive
        #endif
    }()

    private var allSelected: Bool {
        !history.records.isEmpty && selection.count == history.records.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if history.records.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("对战记录")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .toolbar { toolbar }
        }
    }

    // MARK: - 列表

    private var list: some View {
        List(selection: $selection) {
            // 统计卡片当第一行放进来，这样 List 的圆角和滑动手势都能正常用
            statsCard
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(history.records) { record in
                RecordRow(record: record)
                    .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // 向左滑，右侧露出红色的删除
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation(.snappy(duration: 0.28)) { history.delete(record) }
                        } label: {
                            Label("删除", systemImage: "trash.fill")
                        }
                        // 全局 tint 是蓝的，这里显式染红
                        .tint(Theme.destructive)
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onAppear {
            #if DEBUG
            // 截图验证用：直接全选，看得到删除按钮的红
            if ProcessInfo.processInfo.arguments.contains("-selectAllRecords") {
                selection = Set(history.records.map(\.id))
            }
            #endif
        }
        .animation(.snappy(duration: 0.3), value: history.records)
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(allSelected ? "取消全选" : "全选") {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.25)) {
                        selection = allSelected ? [] : Set(history.records.map(\.id))
                    }
                }
                .font(Theme.label(15, weight: .semibold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    deleteSelected()
                } label: {
                    Text(selection.isEmpty ? "删除" : "删除 \(selection.count)")
                        .font(Theme.label(15, weight: .bold))
                        .foregroundStyle(Theme.destructive)
                }
                .tint(Theme.destructive)
                .disabled(selection.isEmpty)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if !history.records.isEmpty {
                    Button("选择") {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.28)) {
                            isSelecting = true
                            editMode = .active
                        }
                    }
                    .font(Theme.label(15, weight: .semibold))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") {
                    if isSelecting { exitSelecting() } else { dismiss() }
                }
                .font(Theme.label(16, weight: .semibold))
            }
        }
    }

    private func deleteSelected() {
        let ids = selection
        Haptics.win()
        withAnimation(.snappy(duration: 0.3)) {
            history.delete(ids)
            selection = []
        }
        // 删完就退回普通模式
        exitSelecting()
    }

    private func exitSelecting() {
        withAnimation(.snappy(duration: 0.28)) {
            isSelecting = false
            selection = []
            editMode = .inactive
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
                    .background { Capsule().fill(Theme.Blue.base.opacity(0.16)) }

                if record.format == .doubles {
                    Text("双打")
                        .font(Theme.label(11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(Color.white.opacity(0.08)) }
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
    }

    private func side(_ name: String, score: String, isWinner: Bool, tint: Color) -> some View {
        HStack(spacing: 7) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
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
