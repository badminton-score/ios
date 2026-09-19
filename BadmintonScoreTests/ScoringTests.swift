//
//  ScoringTests.swift
//  羽毛球计分器Tests
//
//  覆盖各种赛制的计分、平分、封顶、发球权与局/场结束逻辑。
//

import Testing
import Foundation
@testable import BadmintonScore

// MARK: - 单局胜负判定

@Suite("单局胜负判定")
struct GameWinnerTests {

    @Test("21 分制先到 21 分且领先 2 分即获胜")
    func basic() {
        let rules = ScoringMode.bwf21.rules
        #expect(rules.winner(red: 20, blue: 15) == nil)
        #expect(rules.winner(red: 21, blue: 15) == .red)
        #expect(rules.winner(red: 15, blue: 21) == .blue)
    }

    @Test("20 平后需要净胜 2 分，21:20 不算获胜")
    func deuce() {
        let rules = ScoringMode.bwf21.rules
        #expect(rules.isAtDeuce(20, 20))
        #expect(rules.winner(red: 21, blue: 20) == nil)
        #expect(rules.winner(red: 20, blue: 21) == nil)
        #expect(rules.winner(red: 22, blue: 20) == .red)
        #expect(rules.winner(red: 20, blue: 22) == .blue)
        #expect(rules.winner(red: 25, blue: 24) == nil)
        #expect(rules.winner(red: 26, blue: 24) == .red)
    }

    @Test("29 平后先到 30 分者获胜（封顶）")
    func cap() {
        let rules = ScoringMode.bwf21.rules
        #expect(rules.winner(red: 29, blue: 29) == nil)
        #expect(rules.winner(red: 30, blue: 29) == .red)
        #expect(rules.winner(red: 29, blue: 30) == .blue)
    }

    @Test("21 分长盘没有封顶，必须有 2 分差距")
    func noCap() {
        let rules = ScoringMode.classic21.rules
        #expect(rules.cap == nil)
        #expect(rules.winner(red: 30, blue: 29) == nil)
        #expect(rules.winner(red: 31, blue: 29) == .red)
        #expect(rules.winner(red: 40, blue: 39) == nil)
    }

    @Test("15 分制 14 平后需净胜 2 分，21 分封顶")
    func traditional15() {
        let rules = ScoringMode.traditional15.rules
        #expect(rules.winner(red: 15, blue: 12) == .red)
        #expect(rules.winner(red: 15, blue: 14) == nil)
        #expect(rules.winner(red: 16, blue: 14) == .red)
        #expect(rules.winner(red: 21, blue: 20) == .red)
    }

    @Test("11 分制 10 平后需净胜 2 分，15 分封顶")
    func traditional11() {
        let rules = ScoringMode.traditional11.rules
        #expect(rules.winner(red: 11, blue: 9) == .red)
        #expect(rules.winner(red: 11, blue: 10) == nil)
        #expect(rules.winner(red: 12, blue: 10) == .red)
        #expect(rules.winner(red: 15, blue: 14) == .red)
    }
}

// MARK: - 局点 / 赛点

@Suite("局点与赛点")
struct PointSituationTests {

    @Test("20:19 是局点；平分规则从双方都到 20 才开始算")
    func gamePointThreshold() {
        var state = MatchState(mode: .bwf21)
        state.redPoints = 20
        state.bluePoints = 19
        #expect(state.isGamePoint(for: .red))
        // 蓝方在 20:19 得分只是追成 20:20，不是局点
        #expect(state.isGamePoint(for: .blue) == false)

        // 21:20：红方再得一分是 22:20，净胜 2 分，所以是局点
        state.redPoints = 21
        state.bluePoints = 20
        #expect(state.isGamePoint(for: .red))
        // 蓝方在 21:20 得分只是追成 21:21，不是局点
        #expect(state.isGamePoint(for: .blue) == false)

        // 22:20 这一局已经结束了（净胜 2 分），所以它不叫「局点」
        state.redPoints = 22
        state.bluePoints = 20
        #expect(state.gameWinner == .red)
        #expect(state.isGamePoint(for: .red) == false)

        // 29 平之后，30 分封顶使这一分直接决定胜负
        state.redPoints = 29
        state.bluePoints = 29
        #expect(state.isGamePoint(for: .red))
        #expect(state.isGamePoint(for: .blue))
    }

    @Test("第三局 20:19 时是赛点")
    func matchPoint() {
        var state = MatchState(mode: .bwf21)
        state.redGames = 1
        state.blueGames = 1
        state.currentGame = 3
        state.redPoints = 20
        state.bluePoints = 19
        #expect(state.isMatchPoint(for: .red))
        #expect(state.isGamePoint(for: .red))

        // 20 平之后这一分并不能结束比赛
        state.redPoints = 20
        state.bluePoints = 20
        #expect(state.isMatchPoint(for: .red) == false)
    }

    @Test("第一局永远不是赛点")
    func firstGameNeverMatchPoint() {
        var state = MatchState(mode: .bwf21)
        state.redPoints = 20
        state.bluePoints = 5
        #expect(state.isMatchPoint(for: .red) == false)
    }
}

// MARK: - 得分行为

@Suite("得分与发球权")
struct ScoringFlowTests {

    @Test("每球得分制：得分方获得发球权")
    func rallyPointServe() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        var result = ScoreEngine.applyPoint(.blue, to: state)
        #expect(result.0.server == .blue)
        #expect(result.0.bluePoints == 1)
        #expect(result.1 == .point(side: .blue))

        state = result.0
        result = ScoreEngine.applyPoint(.red, to: state)
        #expect(result.0.server == .red)
    }

    @Test("发球方得分为偶数时发右区，奇数时发左区")
    func serveBox() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        #expect(state.serveBox == "右区")
        state.redPoints = 1
        #expect(state.serveBox == "左区")
        state.redPoints = 10
        #expect(state.serveBox == "右区")
    }

    @Test("旧制发球得分制：接发球方得分不换发球")
    func servicePointMode() {
        var state = MatchState(mode: .traditional15, firstServer: .red)
        state.redPoints = 3
        state.bluePoints = 3
        let result = ScoreEngine.applyPoint(.blue, to: state)
        #expect(result.0.bluePoints == 4)
        #expect(result.0.redPoints == 3)
        #expect(result.0.server == .red)

        // 发球方得分则继续保持发球权
        let served = ScoreEngine.applyPoint(.red, to: result.0)
        #expect(served.0.redPoints == 4)
        #expect(served.0.server == .red)
    }

    @Test("拿到 21 分触发本局结束")
    func gameEnds() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        state.redPoints = 20
        state.bluePoints = 15
        let (next, event) = ScoreEngine.applyPoint(.red, to: state)
        #expect(next.redGames == 1)
        #expect(next.gameScores.count == 1)
        #expect(next.gameScores[0].red == 21)
        #expect(next.gameScores[0].blue == 15)
        #expect(event == .gameWon(side: .red, red: 21, blue: 15, game: 1))
        #expect(next.isMatchOver == false)
    }

    @Test("比分到 20:20 时比赛继续，不会误判结束")
    func deuceDoesNotEndGame() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        state.redPoints = 20
        state.bluePoints = 19
        let (next, event) = ScoreEngine.applyPoint(.blue, to: state)
        #expect(next.gameWinner == nil)
        #expect(next.gameScores.isEmpty)
        #expect(event == .point(side: .blue))
        #expect(next.redPoints == 20)
        #expect(next.bluePoints == 20)
    }

    @Test("赢下两局结束整场比赛")
    func matchEnds() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        state.redGames = 1
        state.currentGame = 2
        state.redPoints = 20
        state.bluePoints = 10
        let (next, event) = ScoreEngine.applyPoint(.red, to: state)
        #expect(next.isMatchOver)
        #expect(next.matchWinner == .red)
        #expect(event == .matchWon(side: .red, redGames: 2, blueGames: 0))
    }

    @Test("比赛结束后不再计分")
    func lockedAfterMatch() {
        var state = MatchState(mode: .bwf21)
        state.isMatchOver = true
        state.matchWinner = .red
        let (next, event) = ScoreEngine.applyPoint(.blue, to: state)
        #expect(next.bluePoints == 0)
        #expect(event == .none)
    }

    @Test("一局制赢一局即结束比赛")
    func singleGameMode() {
        var state = MatchState(mode: .single21, firstServer: .blue)
        state.bluePoints = 20
        let (next, event) = ScoreEngine.applyPoint(.blue, to: state)
        #expect(next.isMatchOver)
        #expect(event == .matchWon(side: .blue, redGames: 0, blueGames: 1))
    }

    @Test("下一局由上一局胜方先发球，比分清零")
    func nextGame() {
        var state = MatchState(mode: .bwf21, firstServer: .red)
        state.redPoints = 20
        state.bluePoints = 18
        let (ended, _) = ScoreEngine.applyPoint(.red, to: state)
        let next = ScoreEngine.startNextGame(in: ended)
        #expect(next.currentGame == 2)
        #expect(next.redPoints == 0)
        #expect(next.bluePoints == 0)
        #expect(next.server == .red)
        #expect(next.gameScores.count == 1)
    }
}

// MARK: - 会话与撤销

@Suite("比赛会话与撤销")
@MainActor
struct MatchStoreTests {

    @Test("减分撤销最近一次得分")
    func undoPoint() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.addPoint(to: .red)
        store.addPoint(to: .blue)
        store.addPoint(to: .red)
        #expect(store.state.redPoints == 2)
        #expect(store.state.bluePoints == 1)

        store.removePoint(from: .red)
        #expect(store.state.redPoints == 1)
        #expect(store.state.bluePoints == 1)
        #expect(store.canUndo)
        #expect(store.canRedo)
    }

    @Test("撤销后可以重做")
    func redo() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.addPoint(to: .red)
        store.undo()
        #expect(store.state.redPoints == 0)
        store.redo()
        #expect(store.state.redPoints == 1)
    }

    @Test("撤销会回滚比分、发球权与逐分记录")
    func undoRestoresServeAndLog() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.addPoint(to: .blue)
        #expect(store.state.server == .blue)
        #expect(store.state.log.count == 1)
        store.undo()
        #expect(store.state.server == .red)
        #expect(store.state.log.isEmpty)
    }

    @Test("本局结束后加减分按钮锁定")
    func lockedAfterGame() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        for _ in 0..<21 { store.addPoint(to: .red) }
        #expect(store.isLocked)
        store.addPoint(to: .blue)
        #expect(store.state.bluePoints == 0)
    }

    @Test("开始下一局后解锁并保留大比分")
    func nextGameUnlocks() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        for _ in 0..<21 { store.addPoint(to: .red) }
        let presentation = store.presentation
        guard case .nextGame(let side, _, _, let game) = presentation else {
            Issue.record("应当进入下一局提示")
            return
        }
        #expect(side == .red)
        #expect(game == 1)

        store.startNextGame()
        #expect(store.state.currentGame == 2)
        #expect(store.state.redGames == 1)
        #expect(store.isLocked == false)
        #expect(store.presentation == nil)
    }

    @Test("整场结束时展示胜利方")
    func matchPresentation() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        for _ in 0..<21 { store.addPoint(to: .red) }
        store.startNextGame()
        for _ in 0..<21 { store.addPoint(to: .red) }
        guard case .matchResult(let side) = store.presentation else {
            Issue.record("应当展示胜利方")
            return
        }
        #expect(side == .red)
        #expect(store.state.isMatchOver)
        #expect(store.state.gamesLine == "2-0")
    }

    @Test("切换赛制会重置比分")
    func changeModeResets() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.addPoint(to: .red)
        store.changeMode(.traditional15)
        #expect(store.state.redPoints == 0)
        #expect(store.state.mode == .traditional15)
        #expect(store.canUndo == false)
        #expect(store.state.rules.pointsToWin == 15)
    }

    @Test("再来一场保留队名与赛制，清零比分")
    func rematch() {
        let store = MatchStore(state: MatchState(mode: .bwf21, redName: "甲", blueName: "乙"))
        store.addPoint(to: .red)
        store.rematch()
        #expect(store.state.redPoints == 0)
        #expect(store.state.redName == "甲")
        #expect(store.state.blueName == "乙")
        #expect(store.state.mode == .bwf21)
    }

    @Test("队名为空时回落到默认名")
    func renameFallback() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.rename(.red, to: "   ")
        #expect(store.state.redName == "红方")
        store.rename(.blue, to: "蓝队")
        #expect(store.state.blueName == "蓝队")
    }
}

// MARK: - 完整比赛流程

@Suite("完整比赛流程")
@MainActor
struct FullMatchTests {

    /// 交替加分直到指定比分（领先方先到分，不会误触发平分延长）。
    private func playGame(_ store: MatchStore, red: Int, blue: Int) {
        for _ in 0..<max(red, blue) {
            if store.state.redPoints < red { store.addPoint(to: .red) }
            if store.state.bluePoints < blue { store.addPoint(to: .blue) }
        }
    }

    @Test("21 分制三局两胜：2-1 结束比赛")
    func bestOfThree() {
        let store = MatchStore(state: MatchState(mode: .bwf21))

        playGame(store, red: 21, blue: 19)
        #expect(store.state.gameScores.map { "\($0.red)-\($0.blue)" } == ["21-19"])
        store.startNextGame()

        playGame(store, red: 15, blue: 21)
        #expect(store.state.blueGames == 1)
        store.startNextGame()

        playGame(store, red: 21, blue: 18)
        #expect(store.state.isMatchOver)
        #expect(store.state.matchWinner == .red)
        #expect(store.state.gamesLine == "2-1")
        #expect(store.state.historyLine == "21-19 / 15-21 / 21-18")
    }

    @Test("30 分封顶决胜")
    func capDecider() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        playGame(store, red: 29, blue: 29)
        #expect(store.state.gameWinner == nil)
        // 29 平：下一分就是 30 分封顶，直接决定胜负
        #expect(store.isGamePoint(.red))

        store.addPoint(to: .red)
        #expect(store.state.gameScores.first?.red == 30)
        #expect(store.state.gameScores.first?.blue == 29)
        #expect(store.state.redGames == 1)
    }

    @Test("逐分记录可按局分组")
    func logByGame() {
        let store = MatchStore(state: MatchState(mode: .bwf21))
        playGame(store, red: 21, blue: 14)
        store.startNextGame()
        store.addPoint(to: .blue)
        let gameOneLog = store.state.log.filter { $0.game == 1 }
        let gameTwoLog = store.state.log.filter { $0.game == 2 }
        #expect(gameOneLog.count == 35)
        #expect(gameTwoLog.count == 1)
        #expect(gameTwoLog[0].side == .blue)
    }
}

// MARK: - 赛制预设

@Suite("赛制预设")
struct ScoringModeTests {

    @Test("六种预设规则的参数")
    func presets() {
        // 五种固定预设 + 一个「自定义」
        #expect(ScoringMode.allCases.count == 6)

        let bwf = ScoringMode.bwf21.rules
        #expect(bwf.pointsToWin == 21 && bwf.cap == 30 && bwf.deuceAt == 20 && bwf.gamesToWin == 2)

        let long = ScoringMode.classic21.rules
        #expect(long.cap == nil && long.gamesToWin == 2)

        let old15 = ScoringMode.traditional15.rules
        #expect(old15.pointsToWin == 15 && old15.cap == 21 && old15.deuceAt == 14)
        #expect(old15.rallyPoint == false)

        let old11 = ScoringMode.traditional11.rules
        #expect(old11.pointsToWin == 11 && old11.cap == 15 && old11.deuceAt == 10)
        #expect(old11.rallyPoint == false)

        let single = ScoringMode.single21.rules
        #expect(single.gamesToWin == 1 && single.maximumGames == 1)

        // 「自定义」在用户没调之前是一套 21 分制默认值
        let custom = ScoringMode.custom.rules
        #expect(custom.pointsToWin == 21 && custom.cap == 30)
        #expect(custom.mode == .custom)
    }

    @Test("每种赛制都能在合理比分下结束")
    @MainActor
    func everyModeCanFinish() {
        for mode in ScoringMode.allCases {
            let store = MatchStore(state: MatchState(mode: mode))
            var guardCounter = 0
            while !store.state.isMatchOver, guardCounter < 400 {
                store.addPoint(to: .red)
                guardCounter += 1
                if store.state.gameWinner != nil, !store.state.isMatchOver {
                    store.startNextGame()
                }
            }
            #expect(store.state.isMatchOver, "\(mode.title) 应当可以结束比赛")
            #expect(store.state.matchWinner == .red)
        }
    }
}

// MARK: - 自定义规则

@Suite("自定义赛制")
struct CustomRulesTests {

    @Test("按目标分 / 封顶加成 / 局数造出规则")
    func buildRules() {
        let r = BadmintonRules.custom(points: 11, capBonus: 5, maxGames: 3)
        #expect(r.pointsToWin == 11)
        #expect(r.cap == 16)
        #expect(r.deuceAt == 10)
        #expect(r.maximumGames == 3)
        #expect(r.gamesToWin == 2)
        #expect(r.rallyPoint)
    }

    @Test("局数决定要赢几局：1→1、3→2、5→3")
    func gamesToWin() {
        #expect(BadmintonRules.custom(points: 21, capBonus: nil, maxGames: 1).gamesToWin == 1)
        #expect(BadmintonRules.custom(points: 21, capBonus: nil, maxGames: 3).gamesToWin == 2)
        #expect(BadmintonRules.custom(points: 21, capBonus: nil, maxGames: 5).gamesToWin == 3)
    }

    @Test("不封顶时 cap 为 nil，且必须净胜 2 分")
    func noCap() {
        let r = BadmintonRules.custom(points: 15, capBonus: nil, maxGames: 3)
        #expect(r.cap == nil)
        #expect(r.absoluteWin == Int.max)
        // 14 平之后 15:14 不算赢，16:14 才算
        #expect(r.winner(red: 15, blue: 14) == nil)
        #expect(r.winner(red: 16, blue: 14) == .red)
    }

    @Test("目标分被夹到 5...50，非法局数回落到 3 局")
    func clamping() {
        #expect(BadmintonRules.custom(points: 1, capBonus: nil, maxGames: 3).pointsToWin == 5)
        #expect(BadmintonRules.custom(points: 999, capBonus: nil, maxGames: 3).pointsToWin == 50)
        #expect(BadmintonRules.custom(points: 21, capBonus: nil, maxGames: 4).maximumGames == 3)
    }

    @Test("自定义规则真的影响到判定：11 分制到 11 就结束")
    func customActuallyApplies() {
        var state = MatchState(mode: .custom,
                               customRules: .custom(points: 11, capBonus: 5, maxGames: 3))
        for _ in 0..<11 { state = ScoreEngine.applyPoint(.red, to: state).0 }
        #expect(state.gameWinner == .red)
        #expect(state.redGames == 1)
        #expect(!state.isMatchOver)          // 三局两胜，才赢一局
    }

    @Test("自定义 11 分制下 10:10 不结束，12:10 才结束")
    func customDeuce() {
        var state = MatchState(mode: .custom,
                               customRules: .custom(points: 11, capBonus: 5, maxGames: 3))
        state.redPoints = 10
        state.bluePoints = 10
        #expect(state.rules.winner(red: 11, blue: 10) == nil)
        #expect(state.rules.winner(red: 12, blue: 10) == .red)
        // 封顶 16
        #expect(state.rules.winner(red: 16, blue: 15) == .red)
    }

    @Test("存档里没有 customRules 时回落到默认")
    func fallbackWhenMissing() {
        let state = MatchState(mode: .custom)
        #expect(state.customRules != nil)
        #expect(state.rules.pointsToWin == 21)
    }
}

// MARK: - 单打 / 双打

@Suite("单打与双打")
struct FormatTests {

    @Test("单打每方 1 人，双打每方 2 人")
    func playerCount() {
        var state = MatchState(mode: .bwf21)
        state.setPlayers(["林丹"], for: .red)
        #expect(state.players(of: .red).count == 1)
        #expect(state.name(of: .red) == "林丹")

        state.format = .doubles
        state.normalizePlayers()
        #expect(state.players(of: .red).count == 2)
        #expect(state.name(of: .red) == "林丹 / 队友")
    }

    @Test("切到双打会补上第二个人的位置")
    func switchingFillsSecond() {
        var state = MatchState(mode: .bwf21, redName: "甲", blueName: "乙")
        #expect(state.players(of: .red).count == 1)
        state.format = .doubles
        state.normalizePlayers()
        #expect(state.players(of: .red) == ["甲", "队友"])
        #expect(state.players(of: .blue) == ["乙", "队友"])
    }

    @Test("双打：发球方连续得分，同一个人继续发")
    func serverKeepsServing() {
        var state = MatchState(mode: .bwf21)
        state.format = .doubles
        state.setPlayers(["A1", "A2"], for: .red)
        state.setPlayers(["B1", "B2"], for: .blue)
        state.server = .red
        state.redServeIndex = 0

        let after = ScoreEngine.applyPoint(.red, to: state).0
        #expect(after.server == .red)
        #expect(after.redServeIndex == 0)     // 还是 A1 发
    }

    @Test("双打：接发球方赢球后换人发")
    func serverRotatesOnRegain() {
        var state = MatchState(mode: .bwf21)
        state.format = .doubles
        state.setPlayers(["A1", "A2"], for: .red)
        state.setPlayers(["B1", "B2"], for: .blue)
        state.server = .red
        state.redServeIndex = 0
        state.blueServeIndex = 0

        // 蓝方得分 → 蓝方拿到发球权，且换 B2 发
        let after = ScoreEngine.applyPoint(.blue, to: state).0
        #expect(after.server == .blue)
        #expect(after.blueServeIndex == 1)
        // 红方那边不受影响，下次拿回发球权时再换
        #expect(after.redServeIndex == 0)

        // 红方再拿回发球权 → 换 A2 发
        let back = ScoreEngine.applyPoint(.red, to: after).0
        #expect(back.server == .red)
        #expect(back.redServeIndex == 1)
    }

    @Test("单打不轮转，永远是 0 号")
    func singlesNeverRotates() {
        var state = MatchState(mode: .bwf21)
        state.server = .red
        state = ScoreEngine.applyPoint(.blue, to: state).0
        state = ScoreEngine.applyPoint(.red, to: state).0
        #expect(state.serveIndex(of: .red) == 0)
        #expect(state.serveIndex(of: .blue) == 0)
    }

    @Test("isServing 只在双打且轮到该队员时为真")
    func isServingFlag() {
        var state = MatchState(mode: .bwf21)
        state.setPlayers(["A1"], for: .red)
        state.server = .red
        #expect(!state.isServing(.red, index: 0))   // 单打恒为 false

        state.format = .doubles
        state.setPlayers(["A1", "A2"], for: .red)
        state.redServeIndex = 1
        #expect(state.isServing(.red, index: 1))
        #expect(!state.isServing(.red, index: 0))
    }
}

// MARK: - 对战记录

@Suite("对战记录")
@MainActor
struct MatchHistoryTests {

    /// 每个测试自己 new 一个，测完清干净，别互相干扰。
    private func freshHistory() -> MatchHistoryStore {
        let h = MatchHistoryStore()
        h.clear()
        return h
    }

    /// 交替加分直到指定比分。
    private func playGame(_ store: MatchStore, red: Int, blue: Int) {
        for _ in 0..<max(red, blue) {
            if store.state.redPoints < red { store.addPoint(to: .red) }
            if store.state.bluePoints < blue { store.addPoint(to: .blue) }
        }
    }

    @Test("打完一整场自动记一条")
    func recordsOnMatchEnd() {
        let history = freshHistory()
        defer { history.clear() }

        let store = MatchStore(state: MatchState(mode: .bwf21, redName: "甲", blueName: "乙"))
        store.history = history

        // 红方连赢两局
        for _ in 0..<21 { store.addPoint(to: .red) }
        store.startNextGame()
        for _ in 0..<21 { store.addPoint(to: .red) }

        #expect(store.state.isMatchOver)
        #expect(history.records.count == 1)

        let r = history.records[0]
        #expect(r.redName == "甲")
        #expect(r.blueName == "乙")
        #expect(r.winner == .red)
        #expect(r.gamesLine == "2-0")
        #expect(r.scoreLine == "21-0 / 21-0")
        #expect(r.mode == .bwf21)
    }

    @Test("同一场不会重复记录")
    func noDuplicateRecord() {
        let history = freshHistory()
        defer { history.clear() }

        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.history = history

        for _ in 0..<21 { store.addPoint(to: .red) }
        store.startNextGame()
        for _ in 0..<21 { store.addPoint(to: .red) }

        // 结束后再点几下，不该再写
        store.addPoint(to: .blue)
        store.addPoint(to: .blue)

        #expect(history.records.count == 1)
    }

    @Test("没打完不记录")
    func noRecordMidMatch() {
        let history = freshHistory()
        defer { history.clear() }

        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.history = history

        for _ in 0..<21 { store.addPoint(to: .red) }
        #expect(store.state.gameWinner == .red)
        #expect(history.records.isEmpty)      // 只赢一局，整场还没结束

        store.startNextGame()
        store.addPoint(to: .red)
        #expect(history.records.isEmpty)
    }

    @Test("再来一场之后可以再记一条")
    func recordsAfterRematch() {
        let history = freshHistory()
        defer { history.clear() }

        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.history = history

        for _ in 0..<21 { store.addPoint(to: .red) }
        store.startNextGame()
        for _ in 0..<21 { store.addPoint(to: .red) }
        #expect(history.records.count == 1)

        store.rematch()
        for _ in 0..<21 { store.addPoint(to: .blue) }
        store.startNextGame()
        for _ in 0..<21 { store.addPoint(to: .blue) }

        #expect(history.records.count == 2)
        #expect(history.records[0].winner == .blue)   // 新的排前面
        #expect(history.blueWins == 1)
        #expect(history.redWins == 1)
    }

    @Test("自定义赛制下也能记，并记下赛制与双打")
    func recordsCustomAndDoubles() {
        let history = freshHistory()
        defer { history.clear() }

        var state = MatchState(mode: .custom,
                               customRules: .custom(points: 5, capBonus: nil, maxGames: 1))
        state.format = .doubles
        state.setPlayers(["A1", "A2"], for: .red)
        state.setPlayers(["B1", "B2"], for: .blue)

        let store = MatchStore(state: state)
        store.history = history

        for _ in 0..<5 { store.addPoint(to: .red) }

        #expect(store.state.isMatchOver)          // 一局定胜负，5 分就结束
        #expect(history.records.count == 1)
        let r = history.records[0]
        #expect(r.mode == .custom)
        #expect(r.format == .doubles)
        #expect(r.redName == "A1 / A2")
    }

    @Test("记录里各方显示自己赢的局数，不是同一个大比分")
    func perSideGameCount() {
        let history = freshHistory()
        defer { history.clear() }

        let store = MatchStore(state: MatchState(mode: .bwf21))
        store.history = history

        // 2-1：红方赢两局、蓝方赢一局
        playGame(store, red: 21, blue: 19); store.startNextGame()
        playGame(store, red: 15, blue: 21); store.startNextGame()
        playGame(store, red: 21, blue: 18)

        #expect(history.records.count == 1)
        let r = history.records[0]
        #expect(r.gamesLine == "2-1")
        #expect(r.games(of: .red) == 2)
        #expect(r.games(of: .blue) == 1)
        #expect(r.redGames == 2)
        #expect(r.blueGames == 1)
    }

    @Test("统计数字对得上")
    func stats() {
        let history = freshHistory()
        defer { history.clear() }

        for (red, blue) in [(21, 5), (5, 21), (21, 19)] {
            let store = MatchStore(state: MatchState(mode: .single21))
            store.history = history
            for _ in 0..<max(red, blue) {
                if store.state.redPoints < red { store.addPoint(to: .red) }
                if store.state.bluePoints < blue { store.addPoint(to: .blue) }
            }
        }

        #expect(history.total == 3)
        #expect(history.redWins == 2)
        #expect(history.blueWins == 1)
    }
}
