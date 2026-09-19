//
//  Scoring.swift
//  赛点
//
//  计分规则的领域模型：双方、赛制、比赛状态。
//

import Foundation

// MARK: - 双方

enum Side: String, Codable, CaseIterable, Identifiable, Sendable {
    case red
    case blue

    var id: String { rawValue }

    var opponent: Side { self == .red ? .blue : .red }

    /// 默认队名，可在计分界面下拉修改。
    var defaultName: String { self == .red ? "红方" : "蓝方" }
}

// MARK: - 单打 / 双打

/// 单打还是双打。双打时每方两个人，发球按 BWF 的轮转规则走。
enum MatchFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case singles
    case doubles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singles: "单打"
        case .doubles: "双打"
        }
    }

    var subtitle: String {
        switch self {
        case .singles: "一人对一人"
        case .doubles: "两人对两人 · 发球轮转"
        }
    }

    var symbol: String {
        switch self {
        case .singles: "person.fill"
        case .doubles: "person.2.fill"
        }
    }

    /// 每方几个人。
    var playersPerSide: Int {
        switch self {
        case .singles: 1
        case .doubles: 2
        }
    }
}

// MARK: - 预设赛制

/// 应用内置的几种羽毛球常见计分规则。
enum ScoringMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 现行 BWF 规则：21 分制，20 平后需净胜 2 分，29 平后 30 分封顶。
    case bwf21
    /// 21 分制，但取消封顶，必须净胜 2 分（业余长盘）。
    case classic21
    /// 旧制 15 分制，发球得分，14 平后需净胜 2 分，21 分封顶。
    case traditional15
    /// 旧制 11 分制，发球得分，10 平后需净胜 2 分，15 分封顶。
    case traditional11
    /// 一局定胜负的 21 分制（不加局）。
    case single21
    /// 自己定：每局几分、要不要封顶、打几局。
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bwf21: "21 分制"
        case .classic21: "21 分长盘"
        case .traditional15: "15 分制"
        case .traditional11: "11 分制"
        case .single21: "一局 21 分"
        case .custom: "自定义"
        }
    }

    var subtitle: String {
        switch self {
        case .bwf21: "正式比赛 · 三局两胜"
        case .classic21: "无封顶 · 必须净胜 2 分"
        case .traditional15: "旧制 · 两局三胜"
        case .traditional11: "旧制 · 三局两胜"
        case .single21: "快速对战 · 一局定胜负"
        case .custom: "自己定分数与局数"
        }
    }

    var detail: String {
        if self == .custom { return "自己定每局几分、要不要封顶、打几局" }
        let r = rules
        var text = "\(r.gamesToWin) 局获胜 · \(r.pointsToWin) 分"
        if let cap = r.cap, let deuce = r.deuceAt {
            text += " · \(deuce) 平后净胜 2 分 · \(cap) 分封顶"
        } else if let deuce = r.deuceAt {
            text += " · \(deuce) 平后净胜 2 分 · 无封顶"
        } else {
            text += " · 先到即胜"
        }
        return text
    }

    var symbol: String {
        switch self {
        case .bwf21: "trophy.fill"
        case .classic21: "infinity"
        case .traditional15: "15.circle.fill"
        case .traditional11: "11.circle.fill"
        case .single21: "bolt.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    var rules: BadmintonRules {
        switch self {
        case .bwf21:
            BadmintonRules(mode: self, pointsToWin: 21, cap: 30, deuceAt: 20, gamesToWin: 2, maximumGames: 3, rallyPoint: true)
        case .classic21:
            BadmintonRules(mode: self, pointsToWin: 21, cap: nil, deuceAt: 20, gamesToWin: 2, maximumGames: 3, rallyPoint: true)
        case .traditional15:
            BadmintonRules(mode: self, pointsToWin: 15, cap: 21, deuceAt: 14, gamesToWin: 2, maximumGames: 3, rallyPoint: false)
        case .traditional11:
            BadmintonRules(mode: self, pointsToWin: 11, cap: 15, deuceAt: 10, gamesToWin: 2, maximumGames: 3, rallyPoint: false)
        case .single21:
            BadmintonRules(mode: self, pointsToWin: 21, cap: 30, deuceAt: 20, gamesToWin: 1, maximumGames: 1, rallyPoint: true)
        case .custom:
            BadmintonRules.defaultCustom
        }
    }

    /// 该赛制下整场比赛是否可能打到 15 分以上（用于界面自适应）。
    var isLongForm: Bool { rules.pointsToWin >= 21 }
}

// MARK: - 赛制参数

struct BadmintonRules: Codable, Equatable, Sendable {
    var mode: ScoringMode
    /// 一局的基本获胜分数。
    var pointsToWin: Int
    /// 封顶分（nil 表示必须净胜 2 分，无封顶）。
    var cap: Int?
    /// 从该分数起进入平分（deuce），需要净胜 2 分。
    var deuceAt: Int?
    /// 赢下几局即赢得整场比赛。
    var gamesToWin: Int
    /// 这场比赛最多进行几局。
    var maximumGames: Int
    /// 是否每球得分制（rally point）。旧制为发球得分制。
    var rallyPoint: Bool

    /// 达到该分数即锁定胜局（无论对手多少分）。
    var absoluteWin: Int { cap ?? Int.max }

    // MARK: 自定义

    /// 可选范围，界面上的步进器用。
    static let pointsRange = 5...50
    static let capRange = 1...20      // 封顶相对目标分的"多加多少分"
    static let gameOptions = [1, 3, 5]

    /// 「自定义」的初始值：一套最常见的 21 分制。
    static let defaultCustom = BadmintonRules(
        mode: .custom, pointsToWin: 21, cap: 30, deuceAt: 20,
        gamesToWin: 2, maximumGames: 3, rallyPoint: true
    )

    /// 按「目标分 / 封顶加成 / 总局数」造一套自定义规则，并把各项夹到合法范围。
    ///
    /// - Parameters:
    ///   - points: 每局几分
    ///   - capBonus: 封顶比目标分高多少分；传 `nil` 表示不封顶
    ///   - maxGames: 最多打几局（1 / 3 / 5），赢多一半即胜
    static func custom(points: Int, capBonus: Int?, maxGames: Int) -> BadmintonRules {
        let p = points.clamped(to: pointsRange)
        let games = gameOptions.contains(maxGames) ? maxGames : 3
        // 1 局 → 赢 1 局；3 局 → 赢 2 局；5 局 → 赢 3 局
        let toWin = games / 2 + 1
        let cap = capBonus.map { p + $0.clamped(to: capRange) }
        return BadmintonRules(
            mode: .custom,
            pointsToWin: p,
            cap: cap,
            // 平分从「目标分 - 1」开始，和 BWF 的 20/21 关系一致
            deuceAt: max(1, p - 1),
            gamesToWin: toWin,
            maximumGames: games,
            rallyPoint: true
        )
    }

    /// 封顶相对目标分高多少分；无封顶返回 nil。
    var capBonus: Int? { cap.map { $0 - pointsToWin } }

    func isAtDeuce(_ red: Int, _ blue: Int) -> Bool {
        guard let deuceAt else { return false }
        return red >= deuceAt && blue >= deuceAt
    }

    /// 判断当前局是否已经分出胜负。
    ///
    /// 规则要点：只有当双方都进入平分（例如 21 分制的 20 平）之后，
    /// 才要求净胜 2 分；在那之前，先到目标分即获胜（21:15 直接结束）。
    func winner(red: Int, blue: Int) -> Side? {
        let deuce = deuceAt
        let isDeuce = deuce.map { red >= $0 && blue >= $0 } ?? false
        for side in Side.allCases {
            let mine = side == .red ? red : blue
            let theirs = side == .red ? blue : red
            if mine >= absoluteWin { return side }
            if mine >= pointsToWin, !isDeuce || mine - theirs >= 2 { return side }
        }
        return nil
    }
}

// MARK: - 比赛状态

struct MatchState: Codable, Equatable, Sendable {
    var mode: ScoringMode
    var matchID: UUID
    var redName: String
    var blueName: String
    /// 本局比分。
    var redPoints: Int
    var bluePoints: Int
    /// 已经拿下的局数。
    var redGames: Int
    var blueGames: Int
    /// 当前是第几局（从 1 开始）。
    var currentGame: Int
    /// 正在发球的一方。
    var server: Side
    /// 是否由红方开出第一个球。
    var startedByRed: Bool
    /// 整场比赛是否已经结束。
    var isMatchOver: Bool
    var matchWinner: Side?
    /// 已结束各局的比分，索引 0 为第 1 局。
    var gameScores: [GameScore]
    /// 本场比赛的逐分记录，用于对战记录与撤销。
    var log: [MatchLogEntry] = []
    /// 单打还是双打。
    var format: MatchFormat = .singles
    /// 每方的队员名。单打 1 个、双打 2 个；空的话用「红方 / 蓝方」。
    var redPlayers: [String] = []
    var bluePlayers: [String] = []
    /// 双打里各方当前该谁发球（0 或 1）。
    var redServeIndex: Int = 0
    var blueServeIndex: Int = 0

    /// 仅 `.custom` 用：用户自己定的那套规则。
    ///
    /// 是可选项，所以旧版本存下来的存档解出来是 nil，不会崩。
    var customRules: BadmintonRules?

    /// 本场生效的规则。自定义模式下用用户设的，其余用预设。
    var rules: BadmintonRules {
        if mode == .custom { return customRules ?? .defaultCustom }
        return mode.rules
    }

    init(mode: ScoringMode, redName: String? = nil, blueName: String? = nil, firstServer: Side = .red,
         customRules: BadmintonRules? = nil) {
        self.mode = mode
        // 进入自定义模式时，没给规则就用一套默认的 21 分制，免得规则是空的
        self.customRules = mode == .custom ? (customRules ?? .defaultCustom) : customRules
        self.matchID = UUID()
        self.redName = redName ?? Side.red.defaultName
        self.blueName = blueName ?? Side.blue.defaultName
        self.redPoints = 0
        self.bluePoints = 0
        self.redGames = 0
        self.blueGames = 0
        self.currentGame = 1
        self.server = firstServer
        self.startedByRed = firstServer == .red
        self.isMatchOver = false
        self.matchWinner = nil
        self.gameScores = []
        self.log = []
    }

    /// 某方的队名。单打就是那个人；双打是「A / B」。
    func name(of side: Side) -> String {
        players(of: side).joined(separator: " / ")
    }

    func points(of side: Side) -> Int {
        side == .red ? redPoints : bluePoints
    }

    func games(of side: Side) -> Int {
        side == .red ? redGames : blueGames
    }

    /// 当前局是否已经结束。
    var gameWinner: Side? {
        rules.winner(red: redPoints, blue: bluePoints)
    }

    /// 发球方发左区还是右区（BWF：0 为偶数记分时发右区）。
    var serveBox: String {
        points(of: server).isMultiple(of: 2) ? "右区" : "左区"
    }

    /// 发球方是否处于领先。
    var isServerLeading: Bool {
        points(of: server) > points(of: server.opponent)
    }

    /// 某方是否处于「只差一球就赢下这一局」的状态。
    ///
    /// 关键在「平分」是从**双方都到 20** 才开始算的：
    /// - 20:19 是局点 —— 再得一分 21:19 就赢，此时对手还没到 20，不触发平分规则
    /// - 21:20 也是局点 —— 再得一分 22:20，净胜 2 分
    /// - 只有 20:20 之后，才必须一直净胜 2 分（否则 21:20 那类比分早该结束了）
    func isGamePoint(for side: Side) -> Bool {
        guard gameWinner == nil, !isMatchOver else { return false }
        var probe = self
        probe.redPoints += side == .red ? 1 : 0
        probe.bluePoints += side == .blue ? 1 : 0
        return probe.rules.winner(red: probe.redPoints, blue: probe.bluePoints) == side
    }

    /// 某方是否处于「只差一球就赢下整场比赛」的状态。
    func isMatchPoint(for side: Side) -> Bool {
        guard gameWinner == nil, !isMatchOver else { return false }
        var probe = self
        probe.redPoints += side == .red ? 1 : 0
        probe.bluePoints += side == .blue ? 1 : 0
        guard probe.rules.winner(red: probe.redPoints, blue: probe.bluePoints) == side else { return false }
        let games = games(of: side) + 1
        return games >= rules.gamesToWin
    }
}

/// 一局结束后的比分记录。
struct GameScore: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = UUID()
    var game: Int
    var red: Int
    var blue: Int

    var winner: Side { red > blue ? .red : .blue }
}

// MARK: - 队员

extension MatchState {

    /// 某方的队员列表。
    ///
    /// 第一个人永远回落到 `redName` / `blueName`（老存档里只有这两个字段），
    /// 双打第二个人没填就叫「队友」。
    func players(of side: Side) -> [String] {
        let primary = side == .red ? redName : blueName
        let extra = side == .red ? redPlayers : bluePlayers
        var list = [primary]
        if format == .doubles {
            let second = extra.count > 1 ? extra[1] : "队友"
            list.append(second.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "队友" : second)
        }
        return list
    }

    /// 当前发球的队员在队里的序号。
    func serveIndex(of side: Side) -> Int {
        let i = side == .red ? redServeIndex : blueServeIndex
        return format == .singles ? 0 : (i % 2 + 2) % 2
    }

    /// 某个队员现在是否在发球。
    func isServing(_ side: Side, index: Int) -> Bool {
        guard format == .doubles, server == side else { return false }
        return serveIndex(of: side) == index
    }

    mutating func setPlayers(_ names: [String], for side: Side) {
        let cleaned = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // 第一个人同时写回 redName / blueName，这样单打和旧代码都还认得
        let primary = cleaned.first.flatMap { $0.isEmpty ? nil : $0 } ?? side.defaultName
        if side == .red {
            redName = primary
            redPlayers = cleaned
        } else {
            blueName = primary
            bluePlayers = cleaned
        }
    }

    /// 切换单打/双打时把队员数组对齐到需要的长度。
    mutating func normalizePlayers() {
        let count = format.playersPerSide
        for side in [Side.red, .blue] {
            var list = players(of: side)
            if list.count > count { list = Array(list.prefix(count)) }
            while list.count < count { list.append("队友") }
            setPlayers(list, for: side)
        }
        redServeIndex = redServeIndex % max(1, count)
        blueServeIndex = blueServeIndex % max(1, count)
    }
}

// MARK: - 小工具

extension Comparable {
    /// 把值夹到闭区间里。
    func clamped(to range: ClosedRange<Int>) -> Int {
        guard let value = self as? Int else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
