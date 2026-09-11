import Foundation
import AVFoundation

/// ID3 元数据提取器
final class MetadataExtractor {

    // MARK: - 提取单首歌曲元数据

    /// 从文件 URL 提取音频元数据
    static func extract(from url: URL) async throws -> Song {
        let asset = AVAsset(url: url)
        let metadata = try await asset.load(.commonMetadata)

        let duration = try await asset.load(.duration).seconds
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)

        var title = ""
        var artist = ""
        var album = ""
        var albumArtist = ""
        var genre = ""
        var year = 0
        var trackNumber = 0
        var coverArtData: Data?
        var bitrate = 0
        var sampleRate = 44100

        for item in metadata {
            guard let key = item.commonKey else { continue }

            switch key {
            case .commonKeyTitle:
                title = try await item.load(.stringValue) ?? ""
            case .commonKeyArtist:
                artist = try await item.load(.stringValue) ?? ""
            case .commonKeyAlbumName:
                album = try await item.load(.stringValue) ?? ""
            case .commonKeyType:
                genre = try await item.load(.stringValue) ?? ""
            case .commonKeyArtwork:
                coverArtData = try await item.load(.dataValue)
            default:
                break
            }

        }

        // 从原始 metadata 读取 ID3 专有字段（Album Artist / 年份）
        // 注意：AVMetadataKey 没有 commonKeyAlbumArtist，必须按 identifier 判断
        let allMetadata = try await asset.load(.metadata)
        for item in allMetadata {
            guard let identifier = item.identifier?.rawValue else { continue }

            // ID3: TPE2 = Album Artist；MP4: ©aAR
            if identifier == "id3/TPE2" || identifier.contains("aAR") {
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    albumArtist = value
                }
            }

            // ID3: TYER / TDRC（录音年份）
            if identifier == "id3/TYER" || identifier == "id3/TDRC" {
                if let value = try? await item.load(.stringValue),
                   let parsedYear = Int(value.prefix(4)) {
                    year = parsedYear
                }
            }

            // 音轨号 —— 两种格式的存储方式完全不同
            if identifier == "id3/TRCK" {
                // ID3：字符串，形如 "3/12"，取斜杠前一段
                if let value = try? await item.load(.stringValue),
                   let first = value.split(separator: "/").first,
                   let number = Int(first.trimmingCharacters(in: .whitespaces)) {
                    trackNumber = number
                }
            } else if identifier.contains("trkn") {
                // MP4 / M4A：二进制，不是字符串，不能用 load(.stringValue)
                // trkn 载荷布局： [0-1] 保留 | [2-3] 音轨号(BE UInt16) | [4-5] 总数 | [6-7] 保留
                if let data = try? await item.load(.dataValue), data.count >= 4 {
                    let base = data.startIndex
                    trackNumber = Int((UInt16(data[base + 2]) << 8) | UInt16(data[base + 3]))
                }
            }
        }

        // 从音频轨道获取比特率和采样率
        if let track = try? await asset.load(.tracks).first {
            let formatDescriptions = try? await track.load(.formatDescriptions)
            if let desc = formatDescriptions?.first {
                let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
                sampleRate = Int(audioDesc?.mSampleRate ?? 44100)
                bitrate = Int(audioDesc?.mBytesPerPacket ?? 0) * 8 * sampleRate / 1000
            }
        }

        // 如果标题为空，从文件名推断
        if title.isEmpty {
            title = Song.titleFromFileName(url.lastPathComponent)
        }
        if artist.isEmpty {
            artist = Song.artistFromFileName(url.lastPathComponent)
        }
        // 没有内嵌音轨号时，尝试从文件名前缀（如 "01 - 歌名.m4a"）推断
        if trackNumber == 0 {
            trackNumber = Song.trackNumberFromFileName(url.lastPathComponent)
        }

        // 关键：存「与安装无关」的路径。
        // iOS 沙盒路径含随机 UUID，每次重装都会变；存绝对路径的话，
        // 重装后所有记录都会失效 —— 歌单还在，但一首也播不了、封面全丢。
        let storedPath = SongPath.normalize(url.path)
        let songId = Song.stableId(for: storedPath)

        // 封面文件用稳定的 songId 命名（不能用 url.path.hashValue：
        // Swift 的 hashValue 每次启动都会重新加盐，重扫会留下一堆孤儿文件）
        var coverArtPath: String? = nil
        if let data = coverArtData {
            coverArtPath = saveCoverArt(songId: songId, data: data)
        }

        let format = url.pathExtension.lowercased()
        let fileSize = (fileAttributes?[.size] as? Int64) ?? 0
        let dateModified = (fileAttributes?[.modificationDate] as? Date) ?? Date()

        return Song(
            id: songId,
            filePath: storedPath,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            duration: duration.isFinite ? duration : 0,
            fileSize: fileSize,
            format: format,
            bitrate: bitrate,
            sampleRate: sampleRate,
            coverArtPath: coverArtPath,
            dateAdded: Date(),
            dateModified: dateModified
        )
    }

    /// 批量提取元数据
    static func extractBatch(from urls: [URL]) async -> [Song] {
        var songs: [Song] = []
        for url in urls {
            if let song = try? await extract(from: url) {
                songs.append(song)
            }
        }
        return songs
    }

    // MARK: - 私有辅助

    /// 保存封面图片到缓存目录，返回**安装无关**的路径
    private static func saveCoverArt(songId: String, data: Data) -> String? {
        let coverDir = SongPath.cachesDirectory.appendingPathComponent("CoverArt")
        try? FileManager.default.createDirectory(at: coverDir, withIntermediateDirectories: true)

        let fileURL = coverDir.appendingPathComponent("\(songId).jpg")
        do {
            try data.write(to: fileURL)
            return SongPath.normalize(fileURL.path)
        } catch {
            print("❌ 保存封面失败: \(error.localizedDescription)")
            return nil
        }
    }
}
