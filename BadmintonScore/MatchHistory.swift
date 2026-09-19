//
//  MatchHistory.swift
//  羽毛球计分器
//
//  打完的比赛存档：胜负记录、比分、用时。全存在本地。
//

import Foundation
import Observation

/// 一场打完的比赛。
struct MatchRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    /// 打完的时间。
    var date: Date = Date()
    var mode: ScoringMode
    var format: MatchFormat
    var redName: String
    var blueName: String
    /// 各局比分。
    var games: [GameScore]
    /// 谁赢了；平局（理论上不会出现）为 nil。
    var winner: Side?
    /// 整场用了多久（秒）。
    var duration: TimeInterval

    /// 大比分，例如 "2-1"。
    var gamesLine: String {
        let red = games.filter { $0.winner == .red }.count
        let blue = games.filter { $0.winner == .blue }.count
        return "\(red)-\(blue)"
    }

    /// 各局小分，例如 "21-19 / 18-21 / 21-15"。
    var scoreLine: String {
        games.map { "\($0.red)-\($0.blue)" }.joined(separator: " / ")
    }

    /// 胜方名字。
    var winnerName: String? {
        guard let winner else { return nil }
        return winner == .red ? redName : blueName
    }

    /// 用时文案，例如 "12 分 30 秒"。
    var durationText: String {
        let total = Int(duration.rounded())
        let m = total / 60
        let s = total % 60
        if m == 0 { return "\(s) 秒" }
        return s == 0 ? "\(m) 分" : "\(m) 分 \(s) 秒"
    }
}

/// 对战记录仓库。存 UserDefaults，最多留 200 场。
@MainActor
@Observable
final class MatchHistoryStore {

    private static let storageKey = "badminton.history.v1"
    private static let limit = 200

    private(set) var records: [MatchRecord] = []

    init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let list = try? JSONDecoder().decode([MatchRecord].self, from: data) else { return }
        records = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func add(_ record: MatchRecord) {
        records.insert(record, at: 0)          // 新的排前面
        if records.count > Self.limit { records.removeLast(records.count - Self.limit) }
        persist()
    }

    func delete(_ record: MatchRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    func clear() {
        records.removeAll()
        persist()
    }

    // MARK: - 统计

    /// 总场次。
    var total: Int { records.count }

    /// 红方 / 蓝方各赢多少场。
    var redWins: Int { records.filter { $0.winner == .red }.count }
    var blueWins: Int { records.filter { $0.winner == .blue }.count }

    /// 打过的总时长。
    var totalDuration: TimeInterval { records.reduce(0) { $0 + $1.duration } }
}
