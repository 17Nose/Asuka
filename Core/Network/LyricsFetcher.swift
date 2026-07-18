import Foundation

// MARK: - 歌词搜索结果模型

struct LyricsSearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let lrcURL: String?
    let tlyricURL: String?   // 翻译歌词
    let source: LyricsSource

    enum LyricsSource: String, Codable {
        case netease = "网易云音乐"
        case qq = "QQ音乐"
        case kugou = "酷狗音乐"
        case local = "本地"
    }
}

struct LyricsDownloadResult {
    let lrcContent: String
    let tlrcContent: String?
    let source: LyricsSearchResult.LyricsSource
}

// MARK: - 歌词获取器（多源聚合）

final class LyricsFetcher {
    static let shared = LyricsFetcher()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - 搜索歌词

    /// 多源搜索歌词（按优先级：网易云 → QQ → 酷狗）
    func search(title: String, artist: String, duration: TimeInterval? = nil) async throws -> [LyricsSearchResult] {
        let keywords = "\(artist) \(title)".trimmingCharacters(in: .whitespaces)

        var allResults: [LyricsSearchResult] = []

        // 并行搜索多个源
        async let neteaseResults = try? searchNetease(keywords: keywords, duration: duration)
        async let qqResults = try? searchQQ(keywords: keywords, duration: duration)
        async let kugouResults = try? searchKuGou(keywords: keywords, duration: duration)

        if let r = await neteaseResults { allResults.append(contentsOf: r) }
        if let r = await qqResults { allResults.append(contentsOf: r) }
        if let r = await kugouResults { allResults.append(contentsOf: r) }

        // 按匹配度排序（更接近的时长优先）
        if let dur = duration {
            allResults.sort { a, b in
                abs(a.duration - dur) < abs(b.duration - dur)
            }
        }

        return allResults
    }

    /// 下载歌词内容
    func download(result: LyricsSearchResult) async throws -> LyricsDownloadResult {
        guard let lrcURL = result.lrcURL, let url = URL(string: lrcURL) else {
            throw LyricsError.noLyricsFound
        }

        var lrcContent = ""
        var tlrcContent: String? = nil

        // 下载主歌词
        let (lrcData, _) = try await session.data(from: url)
        lrcContent = String(data: lrcData, encoding: .utf8) ?? ""

        // 下载翻译歌词
        if let tlyricURL = result.tlyricURL, let tURL = URL(string: tlyricURL) {
            if let (tData, _) = try? await session.data(from: tURL) {
                tlrcContent = String(data: tData, encoding: .utf8)
            }
        }

        guard !lrcContent.isEmpty else {
            throw LyricsError.noLyricsFound
        }

        return LyricsDownloadResult(
            lrcContent: lrcContent,
            tlrcContent: tlrcContent,
            source: result.source
        )
    }

    // MARK: - 网易云音乐搜索

    private func searchNetease(keywords: String, duration: TimeInterval?) async throws -> [LyricsSearchResult] {
        // 网易云音乐搜索 API（公开接口）
        let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let searchURL = "https://music.163.com/api/search/get?type=1&limit=10&s=\(encodedKeywords)"

        guard let url = URL(string: searchURL) else { return [] }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct NeteaseResponse: Codable {
            struct Result: Codable {
                struct SongsWrapper: Codable {
                    struct Song: Codable {
                        let id: Int
                        let name: String
                        struct Artist: Codable {
                            let name: String
                        }
                        let artists: [Artist]
                        struct Album: Codable {
                            let name: String
                        }
                        let album: Album
                        let duration: Int  // 毫秒
                    }
                    let songs: [Song]?
                }
                let songs: SongsWrapper?
            }
            let result: Result?
        }

        let neteaseResp = try JSONDecoder().decode(NeteaseResponse.self, from: data)
        guard let songs = neteaseResp.result?.songs?.songs else { return [] }

        return songs.compactMap { song in
            let songDuration = TimeInterval(song.duration) / 1000.0
            let lrcAPI = "https://music.163.com/api/song/lyric?id=\(song.id)&lv=1&kv=1&tv=-1"
            return LyricsSearchResult(
                id: "netease_\(song.id)",
                title: song.name,
                artist: song.artists.map(\.name).joined(separator: "/"),
                album: song.album.name,
                duration: songDuration,
                lrcURL: lrcAPI,
                tlyricURL: nil,
                source: .netease
            )
        }
    }

    /// 下载网易云歌词
    func fetchNeteaseLyrics(songId: Int) async throws -> LyricsDownloadResult {
        let url = URL(string: "https://music.163.com/api/song/lyric?id=\(songId)&lv=1&kv=1&tv=-1")!
        let (data, _) = try await session.data(from: url)

        struct NeteaseLyricResponse: Codable {
            struct LyricData: Codable {
                let lyric: String?
                let tlyric: String?
                let klyric: String?   // 逐字歌词
            }
            let lrc: LyricData?
        }

        let resp = try JSONDecoder().decode(NeteaseLyricResponse.self, from: data)
        let lrc = resp.lrc

        var lrcContent = lrc?.lyric ?? ""
        // 如果原始歌词为空，尝试用逐字歌词
        if lrcContent.isEmpty, let klyric = lrc?.klyric, !klyric.isEmpty {
            lrcContent = klyric
        }

        guard !lrcContent.isEmpty else {
            throw LyricsError.noLyricsFound
        }

        return LyricsDownloadResult(
            lrcContent: lrcContent,
            tlrcContent: lrc?.tlyric,
            source: .netease
        )
    }

    // MARK: - QQ音乐搜索

    private func searchQQ(keywords: String, duration: TimeInterval?) async throws -> [LyricsSearchResult] {
        let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let searchURL = "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&n=10&p=1&w=\(encodedKeywords)&cr=1"

        guard let url = URL(string: searchURL) else { return [] }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct QQResponse: Codable {
            struct Data: Codable {
                struct Song: Codable {
                    struct SongInfo: Codable {
                        let songid: Int
                        let songname: String
                        let singer: [SingerInfo]?
                        let albumname: String?
                        let interval: Int?  // 秒
                        struct SingerInfo: Codable {
                            let name: String
                        }
                    }
                    let song: [SongInfo]?
                }
                let song: Song?
            }
            let data: Data?
        }

        let qqResp = try JSONDecoder().decode(QQResponse.self, from: data)
        guard let songs = qqResp.data?.song?.song else { return [] }

        return songs.compactMap { song in
            let songDuration = TimeInterval(song.interval ?? 0)
            let lrcURL = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(song.songid)&format=json&nobase64=1"
            return LyricsSearchResult(
                id: "qq_\(song.songid)",
                title: song.songname,
                artist: song.singer?.map(\.name).joined(separator: "/") ?? "",
                album: song.albumname ?? "",
                duration: songDuration,
                lrcURL: lrcURL,
                tlyricURL: nil,
                source: .qq
            )
        }
    }

    // MARK: - 酷狗音乐搜索

    private func searchKuGou(keywords: String, duration: TimeInterval?) async throws -> [LyricsSearchResult] {
        let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let searchURL = "https://msearchcdn.kugou.com/api/v3/search/song?keyword=\(encodedKeywords)&page=1&pagesize=10&showtype=1"

        guard let url = URL(string: searchURL) else { return [] }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct KuGouResponse: Codable {
            struct Data: Codable {
                struct Info: Codable {
                    let hash: String?
                    let songname: String?
                    let singername: String?
                    let album_name: String?
                    let duration: Int?  // 秒
                    let remark: String?  // 可能是 "320kbps" 等
                }
                let info: [Info]?
            }
            let data: Data?
        }

        let kugouResp = try JSONDecoder().decode(KuGouResponse.self, from: data)
        guard let songs = kugouResp.data?.info else { return [] }

        return songs.compactMap { song in
            guard let hash = song.hash, !hash.isEmpty else { return nil }
            let songDuration = TimeInterval(song.duration ?? 0)
            let lrcURL = "https://m.kugou.com/app/i/krc.php?cmd=100&hash=\(hash)&timelength=999999&infotype=2"
            return LyricsSearchResult(
                id: "kugou_\(hash)",
                title: song.songname ?? "",
                artist: song.singername ?? "",
                album: song.album_name ?? "",
                duration: songDuration,
                lrcURL: lrcURL,
                tlyricURL: nil,
                source: .kugou
            )
        }
    }
}

// MARK: - 歌词错误类型

enum LyricsError: LocalizedError {
    case noLyricsFound
    case networkError(String)
    case parseError
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noLyricsFound:
            return "未找到匹配的歌词"
        case .networkError(let msg):
            return "网络请求失败: \(msg)"
        case .parseError:
            return "歌词解析失败"
        case .saveFailed:
            return "歌词保存失败"
        }
    }
}
