import Foundation

/// 播放记录（AI 推荐数据源）
struct PlayRecord: Identifiable, Codable {
    let id: Int64?
    let songId: String
    let playedAt: Date
    let playDuration: TimeInterval
    let skipped: Bool
    let source: String

    init(
        id: Int64? = nil,
        songId: String,
        playedAt: Date = Date(),
        playDuration: TimeInterval = 0,
        skipped: Bool = false,
        source: String = "library"
    ) {
        self.id = id
        self.songId = songId
        self.playedAt = playedAt
        self.playDuration = playDuration
        self.skipped = skipped
        self.source = source
    }

    /// 是否算有效播放（播放超过 30 秒或超过歌曲一半）
    var isValidPlay: Bool {
        !skipped && playDuration >= 30
    }
}
