import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - 播放模式
enum PlayMode: String, CaseIterable {
    case sequential = "顺序播放"
    case shuffle = "随机播放"
    case singleRepeat = "单曲循环"

    var iconName: String {
        switch self {
        case .sequential: return "repeat"
        case .shuffle: return "shuffle"
        case .singleRepeat: return "repeat.1"
        }
    }
}

// MARK: - 播放状态
enum PlaybackState {
    case idle
    case loading
    case playing
    case paused
    case finished
}

// MARK: - 音频播放器核心
final class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()

    // MARK: Published 属性（UI 绑定）
    @Published var playbackState: PlaybackState = .idle
    @Published var currentSong: Song?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playMode: PlayMode = .sequential
    @Published var volume: Float = 1.0 {
        didSet { avPlayer?.volume = volume }
    }

    // MARK: 私有属性
    private var avPlayer: AVPlayer?
    private var timeObserver: Any?
    private var playerItemObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?

    /// 当前播放队列
    private var queue: [Song] = []
    /// 当前播放索引
    private var currentIndex: Int = -1
    /// 乱序播放的索引序列
    private var shuffledIndices: [Int] = []

    // MARK: - 初始化
    override private init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionNotification()
    }

    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("❌ AudioSession 配置失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 播放控制

    /// 加载播放队列并播放
    func play(song: Song, queue: [Song]) {
        self.queue = queue
        if let index = queue.firstIndex(where: { $0.id == song.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        prepareShuffledIndices()
        loadAndPlay(song: song)
    }

    /// 播放单个歌曲
    func play(song: Song) {
        play(song: song, queue: [song])
    }

    /// 播放当前队列中的歌曲
    private func loadAndPlay(song: Song) {
        stop()
        currentSong = song
        playbackState = .loading

        let url = URL(fileURLWithPath: song.resolvedFilePath)
        let playerItem = AVPlayerItem(url: url)

        // 监听状态
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.playbackState = .playing
                    self?.duration = item.duration.seconds.isFinite ? item.duration.seconds : song.duration
                    self?.updateNowPlayingInfo()
                case .failed:
                    print("❌ 播放失败: \(item.error?.localizedDescription ?? "未知错误")")
                    self?.playbackState = .idle
                default:
                    break
                }
            }
        }

        avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer?.volume = volume
        avPlayer?.play()

        // 添加时间观察器（每秒更新 10 次）
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    /// 播放 / 暂停切换
    func togglePlayPause() {
        guard let player = avPlayer else { return }
        if player.rate > 0 {
            player.pause()
            playbackState = .paused
        } else {
            player.play()
            playbackState = .playing
        }
        updateNowPlayingInfo()
    }

    /// 暂停
    func pause() {
        avPlayer?.pause()
        playbackState = .paused
        updateNowPlayingInfo()
    }

    /// 恢复播放
    func resume() {
        avPlayer?.play()
        playbackState = .playing
        updateNowPlayingInfo()
    }

    /// 停止并释放资源
    func stop() {
        avPlayer?.pause()
        avPlayer?.replaceCurrentItem(with: nil)

        if let observer = timeObserver {
            avPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }

        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        statusObserver?.invalidate()
        statusObserver = nil

        currentTime = 0
        duration = 0
        playbackState = .idle
    }

    /// 跳转到指定时间
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        avPlayer?.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
    }

    /// 快进（秒）
    func forward(_ seconds: TimeInterval = 15) {
        let target = min(currentTime + seconds, duration)
        seek(to: target)
    }

    /// 快退（秒）
    func rewind(_ seconds: TimeInterval = 15) {
        let target = max(currentTime - seconds, 0)
        seek(to: target)
    }

    // MARK: - 切歌

    func playNext() {
        guard !queue.isEmpty else { return }
        let nextIndex: Int
        switch playMode {
        case .sequential:
            nextIndex = (currentIndex + 1) % queue.count
        case .shuffle:
            if let currentShuffledIdx = shuffledIndices.firstIndex(of: currentIndex),
               currentShuffledIdx + 1 < shuffledIndices.count {
                nextIndex = shuffledIndices[currentShuffledIdx + 1]
            } else {
                reshuffle()
                nextIndex = shuffledIndices.first ?? 0
            }
        case .singleRepeat:
            nextIndex = currentIndex
        }
        currentIndex = nextIndex
        loadAndPlay(song: queue[currentIndex])
    }

    func playPrevious() {
        guard !queue.isEmpty else { return }
        // 如果播放超过 3 秒，重新播放当前歌曲
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let prevIndex: Int
        switch playMode {
        case .sequential:
            prevIndex = (currentIndex - 1 + queue.count) % queue.count
        case .shuffle:
            if let currentShuffledIdx = shuffledIndices.firstIndex(of: currentIndex),
               currentShuffledIdx > 0 {
                prevIndex = shuffledIndices[currentShuffledIdx - 1]
            } else {
                prevIndex = shuffledIndices.last ?? 0
            }
        case .singleRepeat:
            prevIndex = currentIndex
        }
        currentIndex = prevIndex
        loadAndPlay(song: queue[currentIndex])
    }

    /// 切换播放模式
    func togglePlayMode() {
        let modes = PlayMode.allCases
        if let current = modes.firstIndex(of: playMode) {
            playMode = modes[(current + 1) % modes.count]
        }
    }

    // MARK: - 乱序辅助

    private func prepareShuffledIndices() {
        shuffledIndices = Array(0..<queue.count).shuffled()
        // 确保当前歌曲在乱序播放的首位
        if let idx = shuffledIndices.firstIndex(of: currentIndex) {
            shuffledIndices.swapAt(0, idx)
        }
    }

    private func reshuffle() {
        let current = currentIndex
        var remaining = Array(0..<queue.count)
        remaining.removeAll { $0 == current }
        shuffledIndices = [current] + remaining.shuffled()
    }

    // MARK: - 播放结束处理

    @objc private func playerDidFinishPlaying() {
        playbackState = .finished
        // 记录播放完成
        if let song = currentSong {
            NotificationCenter.default.post(
                name: .songDidFinishPlaying,
                object: nil,
                userInfo: ["song": song]
            )
        }
        // 自动播放下一首
        DispatchQueue.main.async { [weak self] in
            self?.playNext()
        }
    }

    // MARK: - 锁屏 / 控制中心集成

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: avPlayer?.rate ?? 0
        ]

        // 加载封面图
        if let coverImage = song.coverImage {
            let artwork = MPMediaItemArtwork(boundsSize: coverImage.size) { _ in coverImage }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - 音频中断处理

    private func setupInterruptionNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - 通知扩展名
extension Notification.Name {
    static let songDidFinishPlaying = Notification.Name("songDidFinishPlaying")
}
