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
    // MARK: - 挑选最匹配的结果

    /// 从搜索结果里挑最匹配的一条
    ///
    /// 只按「时长最接近」排序很容易选中翻唱版（翻唱时长往往也接近），
    /// 所以要综合歌名、歌手、时长三项打分。
    func bestMatch(for song: Song, in results: [LyricsSearchResult]) -> LyricsSearchResult? {
        guard !results.isEmpty else { return nil }
        let wantTitle = normalize(song.title)
        let wantArtist = normalize(song.artist)

        return results.max { lhs, rhs in
            score(lhs, wantTitle, wantArtist, song.duration)
                < score(rhs, wantTitle, wantArtist, song.duration)
        }
    }

    private func score(
        _ result: LyricsSearchResult,
        _ wantTitle: String,
        _ wantArtist: String,
        _ wantDuration: TimeInterval
    ) -> Double {
        var value = 0.0

        // 歌名
        let title = normalize(result.title)
        if title == wantTitle { value += 100 }
        else if title.contains(wantTitle) || wantTitle.contains(title) { value += 55 }
        else { value -= 30 }

        // 歌手
        let artist = normalize(result.artist)
        if !wantArtist.isEmpty && !artist.isEmpty {
            if artist == wantArtist { value += 100 }
            else if artist.contains(wantArtist) || wantArtist.contains(artist) { value += 70 }
            else {
                // 歌名对得上但歌手完全不符 —— 基本是翻唱
                value -= 45
            }
        }

        // 时长
        if wantDuration > 0 {
            let diff = abs(result.duration - wantDuration)
            if diff < 3 { value += 30 }
            else if diff < 8 { value += 10 }
            else if diff > 20 { value -= 25 }
        }

        return value
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 下载歌词
    ///
    /// ⚠️ 三个音乐源返回的格式**完全不同**，必须分开解析：
    ///   - 网易云：JSON `{ "lrc": {"lyric": "..."}, "tlyric": {"lyric": "..."} }`
    ///   - QQ   ：JSON `{ "lyric": "..." }`（请求带 `nobase64=1`）
    ///   - 酷狗 ：Base64 编码的歌词文本
    ///
    /// 旧实现把返回体一律当成纯 LRC 文本存库，结果存进去的是一整段 JSON，
    /// `LRCParser` 找不到任何 `[mm:ss]` 行 —— 这就是「所有歌都没歌词」的根因。
    func download(result: LyricsSearchResult) async throws -> LyricsDownloadResult {
        switch result.source {
        case .netease: return try await downloadNetease(result)
        case .qq:      return try await downloadQQ(result)
        case .kugou:   return try await downloadKuGou(result)
        case .local:   throw LyricsError.noLyricsFound
        }
    }

    // MARK: - 各源下载实现

    private func fetch(_ urlString: String?, referer: String) async throws -> Data {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            throw LyricsError.noLyricsFound
        }
        var request = URLRequest(url: url)
        // 这几个接口都校验来源，缺 Referer 会被拒
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await session.data(for: request)
        return data
    }

    private func downloadNetease(_ result: LyricsSearchResult) async throws -> LyricsDownloadResult {
        let data = try await fetch(result.lrcURL, referer: "https://music.163.com")

        struct Resp: Decodable {
            struct Lrc: Decodable { let lyric: String? }
            let lrc: Lrc?
            let tlyric: Lrc?
            let klyric: Lrc?
        }
        let resp = try JSONDecoder().decode(Resp.self, from: data)

        // 普通歌词为空时退回逐字歌词（KRC 同样带时间轴）
        let candidates = [resp.lrc?.lyric, resp.klyric?.lyric].compactMap { $0 }
        let lyric = candidates.first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? ""

        guard !lyric.isEmpty else { throw LyricsError.noLyricsFound }

        let translation = resp.tlyric?.lyric
        return LyricsDownloadResult(
            lrcContent: lyric,
            tlrcContent: (translation?.isEmpty == false) ? translation : nil,
            source: .netease
        )
    }

    private func downloadQQ(_ result: LyricsSearchResult) async throws -> LyricsDownloadResult {
        let data = try await fetch(result.lrcURL, referer: "https://y.qq.com")

        struct Resp: Decodable { let lyric: String? }
        let resp = try JSONDecoder().decode(Resp.self, from: data)

        guard let lyric = resp.lyric, !lyric.isEmpty else { throw LyricsError.noLyricsFound }
        return LyricsDownloadResult(lrcContent: lyric, tlrcContent: nil, source: .qq)
    }

    private func downloadKuGou(_ result: LyricsSearchResult) async throws -> LyricsDownloadResult {
        let data = try await fetch(result.lrcURL, referer: "https://www.kugou.com")

        // 酷狗一般返回 Base64
        if let base64 = String(data: data, encoding: .utf8),
           let decoded = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)),
           let text = String(data: decoded, encoding: .utf8),
           !text.isEmpty {
            return LyricsDownloadResult(lrcContent: text, tlrcContent: nil, source: .kugou)
        }
        // 偶尔直接给明文
        if let text = String(data: data, encoding: .utf8), text.contains("[") {
            return LyricsDownloadResult(lrcContent: text, tlrcContent: nil, source: .kugou)
        }
        throw LyricsError.noLyricsFound
    }

    // MARK: - 网易云音乐搜索

    private func searchNetease(keywords: String, duration: TimeInterval?) async throws -> [LyricsSearchResult] {
        // 网易云音乐搜索 API（公开接口）
        let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let searchURL = "https://music.163.com/api/search/get?type=1&limit=10&s=\(encodedKeywords)"

        guard let url = URL(string: searchURL) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct NeteaseResponse: Codable {
            struct Result: Codable {
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
                /// 注意：这里**直接是数组**，不是 { songs: [...] } 包一层。
                /// 早期写成 SongsWrapper 导致解码永远失败、被 try? 吞掉。
                let songs: [Song]?
            }
            let result: Result?
        }

        let neteaseResp = try JSONDecoder().decode(NeteaseResponse.self, from: data)
        guard let songs = neteaseResp.result?.songs else { return [] }

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

        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return [] }

        struct QQResponse: Codable {
            struct Data: Codable {
                struct Song: Codable {
                    struct SongInfo: Codable {
                        let songid: Int
                        /// 歌词接口必须用 songmid（字符串），不能用 songid（数字）
                        let songmid: String?
                        let songname: String
                        let singer: [SingerInfo]?
                        let albumname: String?
                        let interval: Int?  // 秒
                        struct SingerInfo: Codable {
                            let name: String
                        }
                    }
                    /// 注意：字段名是 list，不是 song
                    let list: [SongInfo]?
                }
                let song: Song?
            }
            let data: Data?
        }

        let qqResp = try JSONDecoder().decode(QQResponse.self, from: data)
        guard let songs = qqResp.data?.song?.list else { return [] }

        return songs.compactMap { song in
            // 没有 songmid 就无法取歌词，直接跳过
            guard let mid = song.songmid, !mid.isEmpty else { return nil }
            let songDuration = TimeInterval(song.interval ?? 0)
            let lrcURL = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(mid)&format=json&nobase64=1"
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
