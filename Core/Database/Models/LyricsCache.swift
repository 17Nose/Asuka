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

// 注意：LyricLine / WordTiming / DisplayLyricLine 定义在 Utilities/LRC/Parser.swift
// 此处不再重复声明，否则会导致 "ambiguous for type lookup" 编译错误
