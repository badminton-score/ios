//
//  MatchStore.swift
//  羽毛球计分器
//
//  一次比赛的完整会话状态：比分、撤销/重做栈、提示与弹窗，以及本地持久化。
//

import Foundation
import Observation

/// 比赛过程中需要浮层展示的内容。
enum MatchPresentation: Identifiable, Equatable {
    /// 整场比赛结束，展示胜利画面。
    case matchResult(side: Side)
    /// 一局结束，询问是否开始下一局。
    case nextGame(side: Side, red: Int, blue: Int, game: Int)

    var id: String {
        switch self {
        case .matchResult(let side): "match-\(side.rawValue)"
        case .nextGame(_, _, _, let game): "next-\(game)"
        }
    }
}

@MainActor
@Observable
final class MatchStore {

    // MARK: - 状态

    private(set) var state: MatchState
    private(set) var lastEvent: ScoreEvent = .none
    private(set) var lastEventToken = UUID()
    private(set) var presentation: MatchPresentation?
    /// 撤销一步之后，积分面板上短暂显示的提示。
    private(set) var toast: ToastMessage?

    var isShowingSettings = false
    var isShowingHistory = false

    /// 最近一次被撤销的对手方，用于提示「已撤销 红方 1 分」。
    private(set) var lastUndoneSide: Side?

    private var undoStack: [MatchState] = []
    private var redoStack: [MatchState] = []

    /// 这一场从什么时候开始的，用来算用时。
    private var startedAt: Date = Date()
    /// 打完的比赛往这儿写。由 `AppEntry` 在创建时注入。
    weak var history: MatchHistoryStore?
    /// 本场是否已经记过一笔，避免同一场重复记录。
    private var didRecord = false

    // MARK: - 生命周期

    private static let storageKey = "badminton.match.archive.v1"

    init(state: MatchState = MatchState(mode: .bwf21)) {
        self.state = state
    }

    /// 尝试恢复上次未完成的比赛。
    static func restoring() -> MatchStore? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let archive = try? JSONDecoder().decode(Archive.self, from: data) else { return nil }
        let store = MatchStore(state: archive.state)
        store.undoStack = archive.undo
        store.redoStack = archive.redo
        return store
    }

    private struct Archive: Codable {
        var state: MatchState
        var undo: [MatchState]
        var redo: [MatchState]
    }

    private func persist() {
        let archive = Archive(state: state, undo: undoStack, redo: redoStack)
        guard let data = try? JSONEncoder().encode(archive) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - 派生的展示信息

    var server: Side { state.server }
    var currentGameNumber: Int { state.currentGame }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// 当本局不会再有变化时（结束或整场结束）禁用加减分。
    var isLocked: Bool {
        state.isMatchOver || state.gameWinner != nil || presentation != nil
    }

    func isMatchPoint(_ side: Side) -> Bool { state.isMatchPoint(for: side) }
    func isGamePoint(_ side: Side) -> Bool { state.isGamePoint(for: side) }

    // MARK: - 计分

    func addPoint(to side: Side) {
        guard !isLocked else { return }
        pushUndo()
        let (next, event) = ScoreEngine.applyPoint(side, to: state)
        state = next
        lastEvent = event
        lastEventToken = UUID()
        lastUndoneSide = nil
        toast = nil

        switch event {
        case .matchWon(let winner, _, _):
            presentation = .matchResult(side: winner)
            recordIfNeeded()
        case .gameWon(let winner, let red, let blue, let game):
            presentation = .nextGame(side: winner, red: red, blue: blue, game: game)
        default:
            break
        }
        persist()
    }

    /// 减分：撤销最近一次计分（与撤销按钮等价，界面上的减分入口更直观）。
    func removePoint(from side: Side) {
        undo(preferredSide: side)
    }

    func undo(preferredSide: Side? = nil) {
        guard canUndo, presentation == nil else { return }
        let previous = undoStack.last
        let side: Side? = preferredSide ?? {
            guard let p = previous else { return nil }
            if p.redPoints != state.redPoints { return .red }
            if p.bluePoints != state.bluePoints { return .blue }
            return nil
        }()
        pushRedo()
        state = undoStack.removeLast()
        lastEvent = .undone
        lastEventToken = UUID()
        lastUndoneSide = side
        toast = ToastMessage(text: "已撤销 \(side.map { state.name(of: $0) } ?? "一") 1 分", symbol: "arrow.uturn.backward")
        persist()
    }

    func redo() {
        guard canRedo, presentation == nil else { return }
        // 这里**不能**走 pushUndo()：它内部会 redoStack.removeAll()，
        // 而下面紧接着就要从 redoStack 里取状态，栈被清空就会崩
        // （Can't remove last element from an empty collection）。
        undoStack.append(state)
        if undoStack.count > 200 { undoStack.removeFirst(undoStack.count - 200) }
        state = redoStack.removeLast()
        lastEvent = .point(side: state.server)
        lastEventToken = UUID()
        toast = ToastMessage(text: "已恢复 1 分", symbol: "arrow.uturn.forward")
        persist()
    }

    /// 整场结束且还没记过的话，写一条对战记录。
    private func recordIfNeeded() {
        guard !didRecord, state.isMatchOver, let winner = state.matchWinner else { return }
        didRecord = true
        history?.add(
            MatchRecord(
                mode: state.mode,
                format: state.format,
                redName: state.name(of: .red),
                blueName: state.name(of: .blue),
                games: state.gameScores,
                winner: winner,
                duration: Date().timeIntervalSince(startedAt)
            )
        )
    }

    private func pushUndo() {
        undoStack.append(state)
        if undoStack.count > 200 { undoStack.removeFirst(undoStack.count - 200) }
        redoStack.removeAll()
    }

    private func pushRedo() {
        redoStack.append(state)
    }

    // MARK: - 局与场

    func startNextGame() {
        state = ScoreEngine.startNextGame(in: state)
        presentation = nil
        undoStack.removeAll()
        redoStack.removeAll()
        lastEvent = .none
        lastUndoneSide = nil
        persist()
    }

    /// 整场重来：保持队名与赛制，清零比分。
    func rematch() {
        startedAt = Date()
        didRecord = false
        var fresh = MatchState(mode: state.mode,
                               redName: state.players(of: .red).first,
                               blueName: state.players(of: .blue).first,
                               firstServer: .red,
                               customRules: state.customRules)
        fresh.format = state.format
        fresh.setPlayers(state.players(of: .red), for: .red)
        fresh.setPlayers(state.players(of: .blue), for: .blue)
        fresh.matchID = state.matchID
        state = fresh
        undoStack.removeAll()
        redoStack.removeAll()
        presentation = nil
        toast = nil
        lastEvent = .none
        lastUndoneSide = nil
        persist()
    }

    func reset(fromHome: Bool = false) {
        rematch()
        if fromHome { clearPersisted() }
    }

    func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - 编辑

    func changeMode(_ mode: ScoringMode) {
        guard mode != state.mode else { return }
        startedAt = Date()
        didRecord = false
        var fresh = MatchState(mode: mode,
                               redName: state.players(of: .red).first,
                               blueName: state.players(of: .blue).first,
                               firstServer: .red,
                               // 切到自定义时带上之前调好的那套，别每次都重置
                               customRules: state.customRules)
        fresh.format = state.format
        fresh.setPlayers(state.players(of: .red), for: .red)
        fresh.setPlayers(state.players(of: .blue), for: .blue)
        fresh.matchID = state.matchID
        state = fresh
        undoStack.removeAll()
        redoStack.removeAll()
        presentation = nil
        toast = nil
        lastEvent = .none
        persist()
    }

    /// 改自定义规则。
    ///
    /// 规则一变，之前打的比分就按新规则重新判定了（比如把 21 改成 11，可能立刻分出胜负），
    /// 所以这里保留比分、但把撤销栈清掉，避免撤销回旧规则下的状态。
    func setCustomRules(points: Int, capBonus: Int?, maxGames: Int) {
        let rules = BadmintonRules.custom(points: points, capBonus: capBonus, maxGames: maxGames)
        var next = state
        next.customRules = rules
        state = next
        undoStack.removeAll()
        redoStack.removeAll()
        toast = nil
        // 规则改小之后可能当场就分出胜负了，这里重新判定一次
        settle()
        persist()
    }

    /// 改完规则后重新判定本局/本场是否已经结束，并弹出对应浮层。
    private func settle() {
        guard !state.isMatchOver else {
            presentation = .matchResult(side: state.matchWinner ?? .red)
            recordIfNeeded()
            return
        }
        guard let winner = state.gameWinner else {
            presentation = nil
            return
        }
        if state.games(of: winner) >= state.rules.gamesToWin {
            state.isMatchOver = true
            state.matchWinner = winner
            presentation = .matchResult(side: winner)
            recordIfNeeded()
        } else if !state.gameScores.contains(where: { $0.game == state.currentGame }) {
            presentation = .nextGame(side: winner, red: state.redPoints, blue: state.bluePoints, game: state.currentGame)
        }
    }

    /// 切换单打 / 双打。比分保留，但撤销栈清掉（队伍构成变了）。
    func setFormat(_ format: MatchFormat) {
        guard format != state.format else { return }
        var next = state
        next.format = format
        next.normalizePlayers()
        state = next
        undoStack.removeAll()
        redoStack.removeAll()
        persist()
    }

    /// 改某个队员的名字。空名字回落到默认。
    func renamePlayer(_ side: Side, index: Int, to name: String) {
        var list = state.players(of: side)
        guard list.indices.contains(index) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        list[index] = trimmed.isEmpty
            ? (index == 0 ? side.defaultName : "队友")
            : String(trimmed.prefix(10))
        state.setPlayers(list, for: side)
        persist()
    }

    /// 改队名（单打用）。双打请用 `renamePlayer(_:index:to:)`。
    func rename(_ side: Side, to name: String) {
        var list = state.players(of: side)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        list[0] = trimmed.isEmpty ? side.defaultName : String(trimmed.prefix(10))
        state.setPlayers(list, for: side)
        persist()
    }

    func setFirstServer(_ side: Side) {
        var fresh = state
        fresh.server = side
        fresh.startedByRed = side == .red
        state = fresh
        persist()
    }

    func dismissPresentation() {
        presentation = nil
        persist()
    }

    func clearToast() {
        toast = nil
    }
}

// MARK: - 轻量提示

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var symbol: String
}
