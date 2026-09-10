import Foundation

// MARK: - AI 推荐数据模型

/// 推荐歌曲条目
///
/// 注意：`matchedLocalSong` 持有 `Song`（非 Codable），
/// 因此必须排除在 CodingKeys 之外并给出默认值，否则无法合成 Codable 实现。
struct RecommendedTrack: Identifiable, Codable {
    var id = UUID()
    var songId: String? = nil          // 匹配到的本地歌曲 ID
    var title: String = ""
    var artist: String = ""
    var album: String? = nil
    var genre: String? = nil
    var reason: String = ""            // AI 推荐理由
    var score: Double = 0              // 匹配分数 (0-1)
    var matchedLocalSong: Song? = nil  // 匹配到的本地歌曲（不参与编解码）

    enum CodingKeys: String, CodingKey {
        case songId, title, artist, album, genre, reason, score
    }
}

/// AI 推荐结果
struct AIRecommendation: Codable {
    let playlistName: String
    let description: String
    let tracks: [RecommendedTrack]
    let mood: String?
    let generatedAt: Date

    init(playlistName: String, description: String, tracks: [RecommendedTrack], mood: String? = nil) {
        self.playlistName = playlistName
        self.description = description
        self.tracks = tracks
        self.mood = mood
        self.generatedAt = Date()
    }
}

/// 用户播放偏好分析
struct UserPreferenceProfile {
    let totalPlayCount: Int
    let topArtists: [(artist: String, count: Int)]
    let topGenres: [(genre: String, count: Int)]
    let topSongs: [(song: Song, count: Int)]
    let avgSessionDuration: TimeInterval
    let preferredTimeOfDay: String
    let skipRate: Double
    let recentMoods: [String]
}

// MARK: - AI 推荐服务

final class AIService {
    static let shared = AIService()

    /// API 类型
    enum APIProvider: String, CaseIterable {
        case claude = "Claude"
        case openAI = "OpenAI"
        case none = "离线模式"
    }

    var selectedProvider: APIProvider = .none

    private let session: URLSession

    // API Key（用户需要配置）
    private var claudeAPIKey: String? {
        UserDefaults.standard.string(forKey: "claude_api_key")
    }
    private var openAIAPIKey: String? {
        UserDefaults.standard.string(forKey: "openai_api_key")
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // 恢复上次选择
        if let saved = UserDefaults.standard.string(forKey: "ai_provider"),
           let provider = APIProvider.allCases.first(where: { $0.rawValue == saved }) {
            self.selectedProvider = provider
        }
    }

    // MARK: - 主入口：生成推荐

    /// 基于播放历史生成 AI 推荐
    func generateRecommendations(
        profile: UserPreferenceProfile,
        mode: RecommendationMode = .dailyMix
    ) async throws -> AIRecommendation {
        switch selectedProvider {
        case .claude:
            return try await generateWithClaude(profile: profile, mode: mode)
        case .openAI:
            return try await generateWithOpenAI(profile: profile, mode: mode)
        case .none:
            return generateOffline(profile: profile, mode: mode)
        }
    }

    /// 为当前歌曲生成相似推荐
    func generateSimilarTracks(
        currentSong: Song,
        allSongs: [Song]
    ) async throws -> [RecommendedTrack] {
        switch selectedProvider {
        case .claude:
            return try await similarWithClaude(song: currentSong)
        case .openAI:
            return try await similarWithOpenAI(song: currentSong)
        case .none:
            return findSimilarLocal(song: currentSong, allSongs: allSongs)
        }
    }

    // MARK: - Claude API

    private func generateWithClaude(
        profile: UserPreferenceProfile,
        mode: RecommendationMode
    ) async throws -> AIRecommendation {
        guard let apiKey = claudeAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey("请先配置 Claude API Key")
        }

        let prompt = buildRecommendationPrompt(profile: profile, mode: mode)

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("无效响应")
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.networkError("Claude API 错误 (\(httpResponse.statusCode)): \(errorBody)")
        }

        struct ClaudeResponse: Codable {
            struct Content: Codable {
                let text: String?
            }
            let content: [Content]?
        }

        let resp = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = resp.content?.first?.text,
              let jsonData = text.data(using: .utf8) else {
            throw AIServiceError.parseError
        }

        return try parseAIResponse(jsonData: jsonData, mode: mode)
    }

    // MARK: - OpenAI API

    private func generateWithOpenAI(
        profile: UserPreferenceProfile,
        mode: RecommendationMode
    ) async throws -> AIRecommendation {
        guard let apiKey = openAIAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey("请先配置 OpenAI API Key")
        }

        let prompt = buildRecommendationPrompt(profile: profile, mode: mode)

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "你是一个专业的音乐推荐助手。请始终返回有效的 JSON。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 2048,
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIServiceError.networkError("OpenAI API 请求失败")
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String?
                }
                let message: Message?
            }
            let choices: [Choice]?
        }

        let resp = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = resp.choices?.first?.message?.content,
              let jsonData = text.data(using: .utf8) else {
            throw AIServiceError.parseError
        }

        return try parseAIResponse(jsonData: jsonData, mode: mode)
    }

    // MARK: - 相似歌曲（Claude）

    private func similarWithClaude(song: Song) async throws -> [RecommendedTrack] {
        guard let apiKey = claudeAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey("请先配置 Claude API Key")
        }

        let prompt = """
        当前正在播放歌曲 "\(song.title)" - \(song.artist)。
        歌手的其他作品和风格相似的歌曲有哪些？
        请推荐 10 首风格相似的歌曲。

        以 JSON 格式返回：
        {
          "tracks": [
            {
              "title": "歌曲名",
              "artist": "歌手名",
              "reason": "推荐理由（一句话，中文）",
              "score": 0.95
            }
          ]
        }
        """

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2048,
            "messages": [["role": "user", "content": prompt]],
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await session.data(for: request)

        struct CR: Codable {
            struct C: Codable { let text: String? }
            let content: [C]?
        }

        let resp = try JSONDecoder().decode(CR.self, from: data)
        guard let text = resp.content?.first?.text,
              let jsonData = text.data(using: .utf8) else {
            throw AIServiceError.parseError
        }

        struct TracksWrapper: Codable {
            let tracks: [RecommendedTrack]
        }
        let wrapper = try JSONDecoder().decode(TracksWrapper.self, from: jsonData)
        return wrapper.tracks
    }

    // MARK: - 相似歌曲（OpenAI）

    private func similarWithOpenAI(song: Song) async throws -> [RecommendedTrack] {
        guard let apiKey = openAIAPIKey, !apiKey.isEmpty else {
            throw AIServiceError.noAPIKey("请先配置 OpenAI API Key")
        }

        let prompt = """
        推荐 10 首与 "\(song.title)" - \(song.artist) 风格相似的歌曲。
        JSON: {"tracks": [{"title":"...", "artist":"...", "reason":"...", "score":0.9}]}
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "你是一个音乐推荐专家，只返回JSON。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 2048,
            "response_format": ["type": "json_object"]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "content-type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await session.data(for: request)

        struct OR: Codable {
            struct C: Codable { struct M: Codable { let content: String? }; let message: M? }
            let choices: [C]?
        }

        let resp = try JSONDecoder().decode(OR.self, from: data)
        guard let text = resp.choices?.first?.message?.content,
              let jsonData = text.data(using: .utf8) else {
            throw AIServiceError.parseError
        }

        struct TW: Codable { let tracks: [RecommendedTrack] }
        let wrapper = try JSONDecoder().decode(TW.self, from: jsonData)
        return wrapper.tracks
    }

    // MARK: - 离线推荐算法

    func generateOffline(profile: UserPreferenceProfile, mode: RecommendationMode) -> AIRecommendation {
        var tracks: [RecommendedTrack] = []
        let reasons = offlineRecommendationReasons(mode: mode)

        // 基于播放次数推荐 Top 歌曲
        let topSongs = profile.topSongs.prefix(10)
        for (rank, item) in topSongs.enumerated() {
            let reasonIdx = min(rank, reasons.count - 1)
            tracks.append(RecommendedTrack(
                songId: item.song.id,
                title: item.song.title,
                artist: item.song.artist,
                album: item.song.album,
                genre: item.song.genre,
                reason: reasons[reasonIdx],
                score: Double(10 - rank) / 10.0,
                matchedLocalSong: item.song
            ))
        }

        return AIRecommendation(
            playlistName: mode.defaultPlaylistName,
            description: "基于您的播放历史自动生成（离线模式）",
            tracks: tracks,
            mood: mode.moodHint
        )
    }

    /// 本地相似歌曲查找
    func findSimilarLocal(song: Song, allSongs: [Song]) -> [RecommendedTrack] {
        var scored: [(song: Song, score: Double)] = []

        for candidate in allSongs where candidate.id != song.id {
            var score: Double = 0

            // 同歌手 +40%
            if candidate.artist == song.artist && !song.artist.isEmpty {
                score += 0.4
            }
            // 同专辑 +30%
            if candidate.album == song.album && !song.album.isEmpty {
                score += 0.3
            }
            // 同流派 +20%
            if candidate.genre == song.genre && !song.genre.isEmpty {
                score += 0.2
            }
            // 风格相近 + 随机
            score += Double.random(in: 0...0.1)

            if score > 0 {
                scored.append((candidate, min(score, 1.0)))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(10)
            .map { item in
                let reasons = [
                    "同一歌手的更多佳作", "专辑中的其他曲目",
                    "风格相似的歌曲", "您可能会喜欢的旋律",
                    "同流派的热门曲目"
                ]
                return RecommendedTrack(
                    songId: item.song.id,
                    title: item.song.title,
                    artist: item.song.artist,
                    album: item.song.album,
                    genre: item.song.genre,
                    reason: reasons.randomElement() ?? "为您推荐",
                    score: item.score,
                    matchedLocalSong: item.song
                )
            }
    }

    // MARK: - 玩家偏好分析

    /// 从播放记录构建用户偏好画像
    func buildProfile(from history: [PlayRecord], allSongs: [Song]) -> UserPreferenceProfile {
        let songMap = Dictionary(uniqueKeysWithValues: allSongs.map { ($0.id, $0) })

        let validRecords = history.filter { $0.isValidPlay }

        // Top 歌手
        var artistCount: [String: Int] = [:]
        // Top 流派
        var genreCount: [String: Int] = [:]
        // Top 歌曲
        var songCount: [String: Int] = [:]

        var totalDuration: TimeInterval = 0
        var skipCount = 0

        for record in history {
            if let song = songMap[record.songId] {
                let artist = song.artist.isEmpty ? "未知" : song.artist
                let genre = song.genre.isEmpty ? "未知" : song.genre
                artistCount[artist, default: 0] += 1
                genreCount[genre, default: 0] += 1
                songCount[record.songId, default: 0] += 1
            }
            totalDuration += record.playDuration
            if record.skipped { skipCount += 1 }
        }

        let topArtists = artistCount.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
        let topGenres = genreCount.sorted { $0.value > $1.value }.prefix(8).map { ($0.key, $0.value) }
        let topSongs = songCount.sorted { $0.value > $1.value }
            .prefix(20)
            .compactMap { (id, count) -> (song: Song, count: Int)? in
                guard let song = songMap[id] else { return nil }
                return (song, count)
            }

        let skipRate = history.isEmpty ? 0 : Double(skipCount) / Double(history.count)

        // 分析时段偏好
        let hourCounts = history.map { Calendar.current.component(.hour, from: $0.playedAt) }
        var timeOfDay = "全天"
        let morning = hourCounts.filter { 5...11 ~= $0 }.count
        let afternoon = hourCounts.filter { 12...17 ~= $0 }.count
        let evening = hourCounts.filter { 18...23 ~= $0 }.count
        let night = hourCounts.filter { 0...4 ~= $0 }.count
        let maxCount = max(morning, afternoon, evening, night)
        if maxCount == morning { timeOfDay = "早晨" }
        else if maxCount == afternoon { timeOfDay = "下午" }
        else if maxCount == evening { timeOfDay = "晚间" }
        else if maxCount == night { timeOfDay = "深夜" }

        return UserPreferenceProfile(
            totalPlayCount: history.count,
            topArtists: topArtists,
            topGenres: topGenres,
            topSongs: topSongs,
            avgSessionDuration: history.isEmpty ? 0 : totalDuration / Double(history.count),
            preferredTimeOfDay: timeOfDay,
            skipRate: skipRate,
            recentMoods: inferMoods(from: topGenres)
        )
    }

    // MARK: - 辅助方法

    /// 构建推荐 Prompt
    private func buildRecommendationPrompt(
        profile: UserPreferenceProfile,
        mode: RecommendationMode
    ) -> String {
        let artistList = profile.topArtists.prefix(8)
            .map { "\($0.artist)(\($0.count)次)" }.joined(separator: ", ")
        let genreList = profile.topGenres.prefix(5)
            .map { $0.genre }.joined(separator: ", ")

        return """
        你是一个专业的音乐推荐系统。根据以下用户播放数据生成个性化推荐：

        【用户画像】
        - 总播放次数：\(profile.totalPlayCount)
        - 最爱歌手：\(artistList)
        - 偏好流派：\(genreList)
        - 收听时段偏好：\(profile.preferredTimeOfDay)
        - 跳过率：\(String(format: "%.1f%%", profile.skipRate * 100))

        【推荐模式】\(mode.description)

        【要求】
        1. 推荐 10 首歌曲（可以是用户曲库中的，也可以推荐新曲）
        2. 每首歌给出中文推荐理由（1句话，自然亲切）
        3. 给出匹配分数（0.0-1.0）
        4. 推荐歌单名称（有创意、贴合用户偏好）
        5. 如果适合，标注情绪标签（如：放松、活力、感伤）

        返回 JSON 格式：
        {
          "playlistName": "歌单名称",
          "description": "歌单描述",
          "mood": "情绪标签",
          "tracks": [
            {
              "title": "歌曲名",
              "artist": "歌手名",
              "album": "专辑名",
              "genre": "流派",
              "reason": "推荐理由（中文）",
              "score": 0.95
            }
          ]
        }
        """
    }

    /// 解析 AI 返回的 JSON
    private func parseAIResponse(jsonData: Data, mode: RecommendationMode) throws -> AIRecommendation {
        struct AIResponse: Codable {
            let playlistName: String?
            let description: String?
            let mood: String?
            let tracks: [RecommendedTrack]?
        }

        let aiResp = try JSONDecoder().decode(AIResponse.self, from: jsonData)
        guard let tracks = aiResp.tracks, !tracks.isEmpty else {
            throw AIServiceError.parseError
        }

        return AIRecommendation(
            playlistName: aiResp.playlistName ?? mode.defaultPlaylistName,
            description: aiResp.description ?? "为您精心推荐的音乐",
            tracks: tracks,
            mood: aiResp.mood
        )
    }

    /// 离线推荐理由
    private func offlineRecommendationReasons(mode: RecommendationMode) -> [String] {
        switch mode {
        case .dailyMix:
            return [
                "您的近期最爱，百听不厌",
                "播放次数最多的宝藏歌曲",
                "每天必听的经典曲目",
                "根据您的品味精选",
                "循环播放最多的那首",
                "您反复回味的旋律",
                "这段时间的心头好",
                "打开就会不自觉哼唱的",
                "被您听了无数遍的",
                "绝对是您的菜"
            ]
        case .moodRadio:
            return [
                "适合当前心情的旋律",
                "让心情更加舒畅",
                "情绪共鸣的音乐",
                "这一刻的完美配乐",
                "声音里的情绪色彩"
            ]
        case .discoverSimilar:
            return [
                "惊喜发现，风格相近",
                "偷偷藏着的宝藏歌曲",
                "和最爱风格相似的冷门好歌",
                "这个风格您一定会喜欢"
            ]
        }
    }

    /// 从流派推断情绪
    private func inferMoods(from topGenres: [(genre: String, count: Int)]) -> [String] {
        let genreSet = Set(topGenres.map { $0.genre.lowercased() })
        var moods: [String] = []

        let moodMap: [String: [String]] = [
            "摇滚": ["充满力量", "热血", "释放"],
            "流行": ["轻松", "愉快", "活力"],
            "古典": ["沉静", "优雅", "专注"],
            "爵士": ["慵懒", "惬意", "放松"],
            "电子": ["动感", "未来感", "律动"],
            "民谣": ["温暖", "治愈", "怀旧"],
            "嘻哈": ["自信", "洒脱", "率性"],
            "金属": ["力量", "爆发", "激情"],
            "轻音乐": ["安宁", "舒缓", "冥想"],
        ]

        for genre in genreSet {
            for (key, values) in moodMap {
                if genre.contains(key) {
                    moods.append(contentsOf: values)
                }
            }
        }

        return Array(Set(moods)).prefix(5).map { $0 }
    }
}

// MARK: - 推荐模式

enum RecommendationMode: CaseIterable {
    case dailyMix
    case moodRadio
    case discoverSimilar

    var title: String {
        switch self {
        case .dailyMix: return "每日推荐"
        case .moodRadio: return "心情电台"
        case .discoverSimilar: return "发现相似"
        }
    }

    var icon: String {
        switch self {
        case .dailyMix: return "calendar.badge.clock"
        case .moodRadio: return "theatermasks"
        case .discoverSimilar: return "sparkle.magnifyingglass"
        }
    }

    var description: String {
        switch self {
        case .dailyMix: return "每日更新，基于您的收听习惯生成个性化推荐"
        case .moodRadio: return "根据时段和心情，匹配最合适的音乐氛围"
        case .discoverSimilar: return "基于当前播放歌曲，发现风格相近的好音乐"
        }
    }

    var defaultPlaylistName: String {
        switch self {
        case .dailyMix: return "每日推荐"
        case .moodRadio: return "心情电台"
        case .discoverSimilar: return "发现相似"
        }
    }

    var moodHint: String? {
        switch self {
        case .dailyMix: return "日常"
        case .moodRadio:
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5...9: return "清晨活力"
            case 10...14: return "午后慵懒"
            case 15...19: return "傍晚放松"
            case 20...23: return "夜晚感性"
            default: return "深夜宁静"
            }
        case .discoverSimilar: return "探索"
        }
    }
}

// MARK: - 错误类型

enum AIServiceError: LocalizedError {
    case noAPIKey(String)
    case networkError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let msg): return msg
        case .networkError(let msg): return "网络错误: \(msg)"
        case .parseError: return "AI 返回数据解析失败，请重试"
        }
    }
}
