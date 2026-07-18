import Foundation
import Combine

/// 智能歌单管理引擎
@MainActor
final class SmartPlaylistEngine: ObservableObject {
    static let shared = SmartPlaylistEngine()

    @Published var dailyRecommendation: AIRecommendation?
    @Published var moodRecommendation: AIRecommendation?
    @Published var similarTracks: [RecommendedTrack] = []
    @Published var isGenerating = false
    @Published var lastGeneratedDate: Date?
    @Published var generationError: String?

    private let aiService = AIService.shared
    private var repository: SongRepository?

    private init() {}

    func setRepository(_ repo: SongRepository) {
        self.repository = repo
    }

    // MARK: - 每日推荐

    func generateDailyMix() async {
        guard let repo = repository else { return }
        isGenerating = true
        generationError = nil

        do {
            // 获取播放历史
            let history = try repo.getPlayHistory(limit: 100)
            let allSongs = try repo.getAll()

            // 构建用户画像
            let profile = aiService.buildProfile(from: history, allSongs: allSongs)

            // 调用 AI 生成推荐
            var recommendation = try await aiService.generateRecommendations(
                profile: profile,
                mode: .dailyMix
            )

            // 匹配本地曲库
            recommendation = matchToLocalLibrary(recommendation, allSongs: allSongs)

            dailyRecommendation = recommendation
            lastGeneratedDate = Date()

            // 保存为智能歌单
            saveAsSmartPlaylist(recommendation)

        } catch {
            generationError = error.localizedDescription

            // 离线降级
            if let repo = repository,
               let history = try? repo.getPlayHistory(limit: 50),
               let allSongs = try? repo.getAll() {
                let profile = aiService.buildProfile(from: history, allSongs: allSongs)
                let offline = aiService.generateOffline(profile: profile, mode: .dailyMix)
                dailyRecommendation = matchToLocalLibrary(offline, allSongs: allSongs)
            }
        }

        isGenerating = false
    }

    // MARK: - 心情电台

    func generateMoodRadio() async {
        guard let repo = repository else { return }
        isGenerating = true
        generationError = nil

        do {
            let history = try repo.getPlayHistory(limit: 100)
            let allSongs = try repo.getAll()
            let profile = aiService.buildProfile(from: history, allSongs: allSongs)

            var recommendation = try await aiService.generateRecommendations(
                profile: profile,
                mode: .moodRadio
            )
            recommendation = matchToLocalLibrary(recommendation, allSongs: allSongs)

            moodRecommendation = recommendation

            // 如果当前有匹配的心情，自动播放
            if !recommendation.tracks.isEmpty {
                saveAsSmartPlaylist(recommendation)
            }
        } catch {
            generationError = error.localizedDescription

            // 离线降级
            if let repo = repository,
               let history = try? repo.getPlayHistory(limit: 50),
               let allSongs = try? repo.getAll() {
                let profile = aiService.buildProfile(from: history, allSongs: allSongs)
                let offline = aiService.generateOffline(profile: profile, mode: .moodRadio)
                moodRecommendation = matchToLocalLibrary(offline, allSongs: allSongs)
            }
        }

        isGenerating = false
    }

    // MARK: - 发现相似

    func discoverSimilar(to song: Song) async {
        guard let repo = repository else { return }
        isGenerating = true
        generationError = nil

        do {
            let allSongs = try repo.getAll()
            var tracks = try await aiService.generateSimilarTracks(
                currentSong: song,
                allSongs: allSongs
            )

            // 匹配本地曲库
            tracks = matchTracksToLocal(tracks, allSongs: allSongs)

            similarTracks = tracks
        } catch {
            generationError = error.localizedDescription

            // 离线降级
            if let repo = repository,
               let allSongs = try? repo.getAll() {
                similarTracks = aiService.findSimilarLocal(song: song, allSongs: allSongs)
            }
        }

        isGenerating = false
    }

    // MARK: - 定时刷新

    /// 检查是否需要每日刷新（每天自动更新一次）
    func checkDailyRefresh() {
        guard let lastDate = lastGeneratedDate else {
            Task { await generateDailyMix() }
            return
        }

        if !Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            Task { await generateDailyMix() }
        }
    }

    /// 获取当前时段的心情推荐
    func getTimeBasedMood() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...9: return "清晨 · 活力唤醒 🌅"
        case 10...12: return "上午 · 专注时光 ☀️"
        case 13...15: return "午后 · 慵懒小憩 😴"
        case 16...18: return "傍晚 · 放空时刻 🌆"
        case 19...22: return "夜晚 · 感性时光 🌙"
        default: return "深夜 · 安静陪伴 ✨"
        }
    }

    // MARK: - 本地曲库匹配

    private func matchToLocalLibrary(_ recommendation: AIRecommendation, allSongs: [Song]) -> AIRecommendation {
        let matchedTracks = matchTracksToLocal(recommendation.tracks, allSongs: allSongs)
        return AIRecommendation(
            playlistName: recommendation.playlistName,
            description: recommendation.description,
            tracks: matchedTracks,
            mood: recommendation.mood
        )
    }

    private func matchTracksToLocal(_ tracks: [RecommendedTrack], allSongs: [Song]) -> [RecommendedTrack] {
        return tracks.map { track in
            var mutable = track

            // 精确匹配：同名 + 同歌手
            if let match = allSongs.first(where: {
                $0.title.lowercased() == track.title.lowercased() &&
                ($0.artist.lowercased() == track.artist.lowercased() ||
                 $0.artist.isEmpty || track.artist.isEmpty)
            }) {
                mutable = RecommendedTrack(
                    songId: match.id,
                    title: match.title,
                    artist: match.artist,
                    album: match.album,
                    genre: match.genre,
                    reason: track.reason,
                    score: track.score,
                    matchedLocalSong: match
                )
            }

            // 模糊匹配：同歌名
            else if let match = allSongs.first(where: {
                $0.title.lowercased() == track.title.lowercased()
            }) {
                mutable = RecommendedTrack(
                    songId: match.id,
                    title: match.title,
                    artist: match.artist,
                    album: match.album,
                    genre: match.genre,
                    reason: track.reason,
                    score: track.score * 0.85,
                    matchedLocalSong: match
                )
            }

            return mutable
        }
    }

    // MARK: - 保存智能歌单

    private func saveAsSmartPlaylist(_ recommendation: AIRecommendation) {
        guard let repo = repository else { return }

        let playlist = Playlist(
            id: "smart_\(recommendation.playlistName.hashValue)",
            name: recommendation.playlistName,
            description: recommendation.description,
            isSmart: true,
            songs: recommendation.tracks.compactMap { $0.matchedLocalSong }
        )

        try? repo.savePlaylist(playlist)
    }
}
