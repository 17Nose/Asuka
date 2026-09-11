import Foundation
import Combine

/// 播放进度时钟
///
/// **为什么单独抽出来**
/// 播放进度需要 10Hz 刷新才能让进度条顺滑。如果它和 `PlayerViewModel` 混在一起，
/// 每次时间跳动都会触发 `objectWillChange`，导致**所有**观察 viewModel 的视图重渲染
/// —— 包括 275 行的歌曲列表、专辑网格等根本用不到时间的界面，卡顿就是这么来的。
///
/// 拆出来之后，只有真正显示进度的 `NowPlayingView` / `MiniPlayerView` 会跟着刷新。
@MainActor
final class PlaybackClock: ObservableObject {
    static let shared = PlaybackClock()

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private init() {}

    /// 播放进度 0...1
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    var currentTimeFormatted: String { Self.format(currentTime) }
    var remainingTimeFormatted: String { Self.format(duration - currentTime) }

    /// 换歌时重置
    func reset(to duration: TimeInterval) {
        currentTime = 0
        self.duration = duration
    }

    static func format(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
