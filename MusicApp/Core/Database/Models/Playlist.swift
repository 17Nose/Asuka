import Foundation

/// 播放列表
struct Playlist: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var coverImagePath: String?
    var isSmart: Bool
    var createdAt: Date
    var updatedAt: Date
    var songs: [Song]

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        coverImagePath: String? = nil,
        isSmart: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        songs: [Song] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.coverImagePath = coverImagePath
        self.isSmart = isSmart
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.songs = songs
    }

    var songCount: Int { songs.count }

    var totalDuration: TimeInterval {
        songs.reduce(0) { $0 + $1.duration }
    }

    var totalDurationFormatted: String {
        let minutes = Int(totalDuration) / 60
        return "\(minutes) 分钟"
    }
}
