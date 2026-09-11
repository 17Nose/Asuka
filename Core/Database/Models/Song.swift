import Foundation
import UIKit

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
    /// 音轨号（专辑内曲序），0 表示未知
    let trackNumber: Int
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

    /// 有音轨号时返回其字符串，否则 nil（供专辑页行首展示）
    var trackDisplay: String? {
        trackNumber > 0 ? String(trackNumber) : nil
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
        trackNumber: Int = 0,
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
        self.trackNumber = trackNumber
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

// MARK: - 稳定 ID

extension Song {
    /// 由「安装无关路径」算出的稳定 ID
    ///
    /// ⚠️ 不能用 Swift 的 `Hasher` / `hashValue`：它们**每次进程启动都会重新加盐**，
    /// 同一个文件在不同次启动会算出不同的值。用它当主键会导致每次扫描都新增一批
    /// 重复记录（`ON CONFLICT(id)` 永远匹配不上）。这里用确定性的 FNV-1a。
    static func stableId(for storedPath: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325   // FNV-1a 64 位偏移基准
        for byte in storedPath.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3    // FNV 质数
        }
        return String(format: "%016llx", hash)
    }

    /// 解析后的绝对路径（当前安装下）
    var resolvedFilePath: String { SongPath.resolve(filePath) }

    /// 解析后的封面绝对路径
    var resolvedCoverArtPath: String? {
        coverArtPath.map { SongPath.resolve($0) }
    }

    /// 封面图片（统一入口，避免各视图各自拼路径）
    var coverImage: UIImage? {
        guard let path = resolvedCoverArtPath else { return nil }
        return UIImage(contentsOfFile: path)
    }

    /// 音频文件是否仍然存在（用于检测路径失效）
    var fileExists: Bool { SongPath.exists(filePath) }
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

    /// 当音频没有内嵌音轨号时，尝试从文件名前缀推断曲序
    /// 支持 "01 - 歌名" / "01. 歌名" / "01 歌名" / "01_歌名"
    static func trackNumberFromFileName(_ fileName: String) -> Int {
        let name = (fileName as NSString).deletingPathExtension

        // 只取前 4 个字符做前缀匹配
        let prefix = String(name.prefix(4))
        let digits = prefix.prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count <= 3 else { return 0 }

        // 数字后面必须跟分隔符或空格，避免把 "1998年的夏天" 误判为曲序
        let rest = prefix.dropFirst(digits.count)
        if let next = rest.first, !" .-_".contains(next) { return 0 }

        return Int(digits) ?? 0
    }
}
