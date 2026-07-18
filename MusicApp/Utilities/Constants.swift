import Foundation

/// 全局常量
enum Constants {

    /// App 信息
    static let appName = "MusicApp"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    /// 支持的音频格式
    static let supportedAudioExtensions = [
        "mp3", "flac", "wav", "m4a", "aac",
        "wma", "ogg", "aiff", "alac", "opus"
    ]

    /// 播放器默认值
    static let defaultForwardSeconds: TimeInterval = 15
    static let defaultRewindSeconds: TimeInterval = 15
    static let seekBarUpdateInterval: TimeInterval = 0.1

    /// 封面缓存
    static let coverArtDirectory = "CoverArt"

    /// 数据库
    static let databaseFileName = "music_app.sqlite"
}
