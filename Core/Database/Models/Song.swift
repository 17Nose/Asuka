import Foundation

/// 歌曲数据模型
struct Song: Identifiable, Codable, Equatable {
    let id: String
    let filePath: String
    let title: String
    let artist: String
    let album: String
    let albumArtist: String
    let genre: String
    let year: Int
    let duration: TimeInterval
    let fileSize: Int64
    let format: String
    let bitrate: Int
    let sampleRate: Int
    let coverArtPath: String?
    let dateAdded: Date
    let dateModified: Date

    // MARK: - 计算属性

    /// 格式化时长，如 "3:42"
    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 显示用的歌手名（未知时显示 "未知歌手"）
    var displayArtist: String {
        artist.isEmpty ? "未知歌手" : artist
    }

    /// 显示用的专辑名（未知时显示 "未知专辑"）
    var displayAlbum: String {
        album.isEmpty ? "未知专辑" : album
    }

    /// 文件格式图标描述
    var formatIcon: String {
        switch format.lowercased() {
        case "flac": return "flac"
        case "wav":  return "wav"
        case "m4a":  return "m4a"
        default:     return "mp3"
        }
    }

    /// 文件大小格式化
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    // MARK: - 初始化

    init(
        id: String = UUID().uuidString,
        filePath: String,
        title: String = "未知歌曲",
        artist: String = "",
        album: String = "",
        albumArtist: String = "",
        genre: String = "",
        year: Int = 0,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        format: String = "mp3",
        bitrate: Int = 0,
        sampleRate: Int = 44100,
        coverArtPath: String? = nil,
        dateAdded: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.genre = genre
        self.year = year
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.coverArtPath = coverArtPath
        self.dateAdded = dateAdded
        self.dateModified = dateModified
    }
}

// MARK: - 从文件名推断元数据
extension Song {
    /// 当无法提取 ID3 标签时，从文件名推断标题
    static func titleFromFileName(_ fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        // 尝试解析 "歌手 - 歌名" 格式
        if let dashRange = name.range(of: " - ") {
            return String(name[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return name
    }

    /// 从文件名推断歌手
    static func artistFromFileName(_ fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        if let dashRange = name.range(of: " - ") {
            return String(name[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}
