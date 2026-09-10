import Foundation
import Combine
import SwiftUI

/// 播放器视图模型
@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: - 播放器状态（绑定 AudioPlayer）
    @Published var playbackState: PlaybackState = .idle
    @Published var currentSong: Song?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playMode: PlayMode = .sequential
    @Published var volume: Float = 1.0

    // MARK: - 音乐库状态
    @Published var allSongs: [Song] = []
    @Published var recentSongs: [Song] = []
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var isImporting = false
    @Published var scanProgress: Double = 0
    @Published var errorMessage: String?

    // MARK: - 歌词状态
    @Published var lyricLines: [LyricLine] = []
    @Published var currentLyricIndex: Int? = nil
    @Published var displayLyrics: [DisplayLyricLine] = []
    @Published var lyricMetadata: LyricsMetadata?

    // MARK: - 在线歌词搜索状态
    @Published var lyricSearchResults: [LyricsSearchResult] = []
    @Published var isSearchingLyrics = false
    @Published var lyricsSourceLabel: String = "本地"

    // MARK: - 搜索状态
    @Published var searchQuery = ""
    @Published var searchResults: [Song] = []

    // MARK: - 私有属性
    private let audioPlayer = AudioPlayer.shared
    private var repository: SongRepository?
    private let fileScanner = FileScanner()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        setupBindings()
        Task { await initializeDatabase() }
    }

    private func initializeDatabase() async {
        do {
            try DatabaseManager.shared.setup()
            let dbQueue = try DatabaseManager.shared.getQueue()
            repository = SongRepository(dbQueue: dbQueue)
            SmartPlaylistEngine.shared.setRepository(repository!)
            await loadSongs()
        } catch {
            errorMessage = "数据库初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 绑定 AudioPlayer 状态

    private func setupBindings() {
        // 使用 Timer 轮询 AudioPlayer 状态（简化 Combine 绑定方案）
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.playbackState = self.audioPlayer.playbackState
                self.currentSong = self.audioPlayer.currentSong
                self.currentTime = self.audioPlayer.currentTime
                self.duration = self.audioPlayer.duration
                self.playMode = self.audioPlayer.playMode
                self.volume = self.audioPlayer.volume

                // 更新歌词
                self.updateCurrentLyric()
            }
            .store(in: &cancellables)
    }

    // MARK: - 播放控制

    func play(song: Song, from queue: [Song]? = nil) {
        let playQueue = queue ?? allSongs
        audioPlayer.play(song: song, queue: playQueue)
        recordPlay(songId: song.id, skipped: false)

        // 加载歌词
        Task { await loadLyrics(for: song) }
    }

    func togglePlayPause() {
        audioPlayer.togglePlayPause()
    }

    func pause() {
        audioPlayer.pause()
    }

    func resume() {
        audioPlayer.resume()
    }

    func playNext() {
        audioPlayer.playNext()
        if let song = audioPlayer.currentSong {
            recordPlay(songId: song.id, skipped: false)
            Task { await loadLyrics(for: song) }
        }
    }

    func playPrevious() {
        audioPlayer.playPrevious()
        if let song = audioPlayer.currentSong {
            Task { await loadLyrics(for: song) }
        }
    }

    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }

    func forward(_ seconds: TimeInterval = 15) {
        audioPlayer.forward(seconds)
    }

    func rewind(_ seconds: TimeInterval = 15) {
        audioPlayer.rewind(seconds)
    }

    func togglePlayMode() {
        audioPlayer.togglePlayMode()
    }

    // MARK: - 音乐库管理

    func loadSongs() async {
        guard let repo = repository else { return }
        isLoading = true
        do {
            allSongs = try repo.getAll()
            recentSongs = try repo.getRecent(limit: 20)
        } catch {
            errorMessage = "加载歌曲失败: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func scanFiles() async {
        isScanning = true
        scanProgress = 0

        do {
            let filePaths = try await fileScanner.scanFilePaths()

            var newSongs: [Song] = []
            for (index, path) in filePaths.enumerated() {
                let url = URL(fileURLWithPath: path)
                if let song = try? await MetadataExtractor.extract(from: url) {
                    newSongs.append(song)
                }
                scanProgress = Double(index + 1) / Double(filePaths.count)
            }

            // 批量写入数据库
            if let repo = repository {
                try repo.upsertBatch(newSongs)
            }

            await loadSongs()
        } catch {
            errorMessage = "扫描文件失败: \(error.localizedDescription)"
        }

        isScanning = false
        scanProgress = 1.0
    }

    func deleteSong(_ song: Song) {
        guard let repo = repository else { return }
        try? repo.delete(song.id)
        allSongs.removeAll { $0.id == song.id }
    }

    // MARK: - 导入外部文件

    /// 把外部音频文件复制进 App 沙盒，然后重新扫描
    /// - Parameter urls: 来自「文件」App / AirDrop / 分享面板的文件 URL
    func importFiles(from urls: [URL]) async {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        isImporting = true
        var importedCount = 0
        var failedNames: [String] = []

        for url in urls {
            // 沙盒外的文件需要申请访问权限
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            let destination = documents.appendingPathComponent(url.lastPathComponent)
            do {
                // 同名文件直接覆盖，避免出现重复条目
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: url, to: destination)
                importedCount += 1
            } catch {
                failedNames.append(url.lastPathComponent)
                print("❌ 导入失败 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        isImporting = false

        if !failedNames.isEmpty {
            errorMessage = "\(failedNames.count) 个文件导入失败"
        }

        if importedCount > 0 {
            await scanFiles()
        }
    }

    // MARK: - 搜索

    func search() {
        guard let repo = repository, !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        do {
            // 优先 FTS5，失败则简单搜索
            if let results = try? repo.search(searchQuery), !results.isEmpty {
                searchResults = results
            } else {
                searchResults = try repo.simpleSearch(searchQuery)
            }
        } catch {
            searchResults = []
        }
    }

    // MARK: - 歌词加载

    /// 加载歌词（优先级：数据库缓存 → 本地文件 → 在线搜索提示）
    func loadLyrics(for song: Song) async {
        lyricLines = []
        currentLyricIndex = nil
        lyricMetadata = nil
        lyricsSourceLabel = "本地"

        // 1. 检查数据库缓存
        if let repo = repository,
           let cache = try? repo.getLyricsCache(songId: song.id),
           let lrcContent = cache.lrcContent {
            let (lines, meta) = LRCParser.parse(lrcContent)

            // 合并翻译
            var finalLines = lines
            if let tlrc = cache.tlrcContent {
                finalLines = LRCParser.mergeTranslation(mainLines: lines, translationContent: tlrc)
            }

            lyricLines = finalLines
            lyricMetadata = meta
            lyricsSourceLabel = cache.source
            updateDisplayLyrics()
            return
        }

        // 2. 查找本地 .lrc 文件
        let lrcPath = (song.filePath as NSString).deletingPathExtension + ".lrc"
        if FileManager.default.fileExists(atPath: lrcPath),
           let (lines, meta) = LRCParser.parse(filePath: lrcPath) {
            lyricLines = lines
            lyricMetadata = meta
            lyricsSourceLabel = "本地文件"
            updateDisplayLyrics()
            // 缓存到数据库
            saveLyricsToCache(songId: song.id, lrc: lines, meta: meta)
            return
        }

        // 3. 查找同目录下的 .lrc 文件
        let dir = (song.filePath as NSString).deletingLastPathComponent
        let baseName = ((song.filePath as NSString).lastPathComponent as NSString).deletingPathExtension
        let patterns = [
            "\(baseName).lrc",
            "\(song.artist) - \(song.title).lrc",
            "\(song.title).lrc"
        ]

        for pattern in patterns {
            let path = (dir as NSString).appendingPathComponent(pattern)
            if FileManager.default.fileExists(atPath: path),
               let (lines, meta) = LRCParser.parse(filePath: path) {
                lyricLines = lines
                lyricMetadata = meta
                lyricsSourceLabel = "本地文件"
                updateDisplayLyrics()
                saveLyricsToCache(songId: song.id, lrc: lines, meta: meta)
                return
            }
        }
    }

    // MARK: - 在线歌词搜索

    /// 搜索在线歌词
    func searchLyricsOnline(title: String, artist: String) async {
        isSearchingLyrics = true
        lyricSearchResults = []

        do {
            let results = try await LyricsFetcher.shared.search(
                title: title,
                artist: artist,
                duration: currentSong?.duration
            )
            lyricSearchResults = results
        } catch {
            errorMessage = "歌词搜索失败: \(error.localizedDescription)"
        }

        isSearchingLyrics = false
    }

    /// 下载并应用搜索结果中的歌词
    func downloadLyrics(result: LyricsSearchResult) async {
        isSearchingLyrics = true

        do {
            let download = try await LyricsFetcher.shared.download(result: result)
            let (lines, meta) = LRCParser.parse(download.lrcContent)

            // 合并翻译歌词
            var finalLines = lines
            if let tlrc = download.tlrcContent {
                finalLines = LRCParser.mergeTranslation(mainLines: lines, translationContent: tlrc)
            }

            lyricLines = finalLines
            lyricMetadata = meta
            lyricsSourceLabel = result.source.rawValue

            // 保存到数据库缓存
            if let song = currentSong {
                saveLyricsToCache(
                    songId: song.id,
                    lrcContent: download.lrcContent,
                    tlrcContent: download.tlrcContent,
                    source: result.source.rawValue
                )
            }

            updateDisplayLyrics()
        } catch {
            errorMessage = "歌词下载失败: \(error.localizedDescription)"
        }

        isSearchingLyrics = false
    }

    // MARK: - 歌词缓存

    private func saveLyricsToCache(
        songId: String,
        lrc: [LyricLine]? = nil,
        meta: LyricsMetadata? = nil,
        lrcContent: String? = nil,
        tlrcContent: String? = nil,
        source: String = "本地"
    ) {
        guard let repo = repository else { return }

        let lrcStr: String?
        if let lines = lrc {
            lrcStr = LRCParser.generateLRC(lines: lines, metadata: meta)
        } else {
            lrcStr = lrcContent
        }

        let cache = LyricsCache(
            songId: songId,
            lrcContent: lrcStr,
            tlrcContent: tlrcContent,
            source: source
        )
        try? repo.saveLyricsCache(cache)
    }

    // MARK: - 歌词同步

    private func updateCurrentLyric() {
        guard !lyricLines.isEmpty else { return }
        let newIndex = LRCParser.findCurrentLineIndex(lines: lyricLines, currentTime: currentTime)
        if newIndex != currentLyricIndex {
            currentLyricIndex = newIndex
            updateDisplayLyrics()
        }
    }

    /// 生成显示用歌词数据（带逐字时间 + 翻译）
    private func updateDisplayLyrics() {
        displayLyrics = LRCParser.displayLines(
            lines: lyricLines,
            currentIndex: currentLyricIndex,
            currentTime: currentTime
        )
    }

    // MARK: - 播放记录

    private func recordPlay(songId: String, skipped: Bool) {
        guard let repo = repository else { return }
        try? repo.recordPlay(
            songId: songId,
            duration: currentTime,
            skipped: skipped,
            source: "library"
        )
    }

    // MARK: - 进度值（0-1）
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    /// 当前时间格式化
    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    /// 剩余时间格式化
    var remainingTimeFormatted: String {
        formatTime(duration - currentTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
