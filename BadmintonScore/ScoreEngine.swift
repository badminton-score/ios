//
//  ScoreEngine.swift
//  赛点
//
//  纯函数式计分引擎：所有状态变更都在这里完成，界面只负责展示与调用。
//

import Foundation

/// 一次得分操作后产生的副作用，界面据此播放触感与动画。
enum ScoreEvent: Equatable, Sendable {
    case none
    /// 普通得分。
    case point(side: Side)
    /// 本局结束。
    case gameWon(side: Side, red: Int, blue: Int, game: Int)
    /// 整场比赛结束。
    case matchWon(side: Side, redGames: Int, blueGames: Int)
    /// 撤销或取消了一分。
    case undone
}

/// 一次计分动作的记录（用于历史列表展示）。
struct MatchLogEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var side: Side
    var redPoints: Int
    var bluePoints: Int
    var game: Int
    var isCorrection: Bool

    var text: String {
        "\(game)局  \(redPoints) : \(bluePoints)"
    }
}

enum ScoreEngine {

    // MARK: - 得分

    /// 给某一方加一分，返回新状态与产生的副作用。
    static func applyPoint(_ side: Side, to state: MatchState) -> (MatchState, ScoreEvent) {
        guard !state.isMatchOver, state.gameWinner == nil else { return (state, .none) }

        var next = state
        if side == .red { next.redPoints += 1 } else { next.bluePoints += 1 }
        next.log.append(
            MatchLogEntry(
                side: side,
                redPoints: next.redPoints,
                bluePoints: next.bluePoints,
                game: next.currentGame,
                isCorrection: false
            )
        )

        // 每球得分制：得分方获得发球权；旧制发球得分制：发球方得分才换发球。
        let wasServing = next.server == side
        if next.rules.rallyPoint || wasServing {
            // 双打：接发球方夺回发球权时，换这对里的另一个人发球。
            // （发球方自己连续得分时，还是同一个人发，只是左右发球区轮换。）
            if next.format == .doubles && !wasServing {
                if side == .red {
                    next.redServeIndex = 1 - next.redServeIndex
                } else {
                    next.blueServeIndex = 1 - next.blueServeIndex
                }
            }
            next.server = side
        }

        guard let winner = next.rules.winner(red: next.redPoints, blue: next.bluePoints) else {
            return (next, .point(side: side))
        }

        // 本局结束：赛后双方交换场地，由本局胜方在下一局先发球。
        next.gameScores.append(GameScore(game: next.currentGame, red: next.redPoints, blue: next.bluePoints))
        if winner == .red { next.redGames += 1 } else { next.blueGames += 1 }

        let event = ScoreEvent.gameWon(side: winner, red: next.redPoints, blue: next.bluePoints, game: next.currentGame)

        if next.games(of: winner) >= next.rules.gamesToWin {
            next.isMatchOver = true
            next.matchWinner = winner
            return (next, .matchWon(side: winner, redGames: next.redGames, blueGames: next.blueGames))
        }

        return (next, event)
    }

    // MARK: - 开始下一局

    /// 清空本局比分，进入下一局（逐分记录保留，按局号分组）。
    static func startNextGame(in state: MatchState) -> MatchState {
        guard let winner = state.gameWinner, !state.isMatchOver else { return state }
        var next = state
        next.currentGame += 1
        next.redPoints = 0
        next.bluePoints = 0
        next.server = winner
        return next
    }
}

// MARK: - 比分格式化

extension MatchState {
    /// 单局比分文案，例如 "21-19"。
    var currentGameLine: String { "\(redPoints)-\(bluePoints)" }

    /// 整场大比分文案，例如 "2-1"。
    var gamesLine: String { "\(redGames)-\(blueGames)" }

    /// 历史各局文案，例如 "21-19 / 18-21 / 21-15"。
    var historyLine: String {
        let finished = gameScores.map { "\($0.red)-\($0.blue)" }.joined(separator: " / ")
        return finished.isEmpty ? "—" : finished
    }
}
