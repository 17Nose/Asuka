import Foundation

/// 歌词缓存
struct LyricsCache: Identifiable, Codable {
    let id: String  // songId
    var lrcContent: String?
    var tlrcContent: String?  // 翻译歌词
    var source: String
    var fetchedAt: Date

    init(
        songId: String,
        lrcContent: String? = nil,
        tlrcContent: String? = nil,
        source: String = "local",
        fetchedAt: Date = Date()
    ) {
        self.id = songId
        self.lrcContent = lrcContent
        self.tlrcContent = tlrcContent
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

/// LRC 歌词行
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String

    static func == (lhs: LyricLine, rhs: LyricLine) -> Bool {
        lhs.time == rhs.time && lhs.text == rhs.text
    }
}
