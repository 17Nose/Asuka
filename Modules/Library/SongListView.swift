import SwiftUI

/// 歌曲列表视图
struct SongListView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    let songs: [Song]
    let showAlbumArt: Bool

    init(songs: [Song], showAlbumArt: Bool = true) {
        self.songs = songs
        self.showAlbumArt = showAlbumArt
    }

    var body: some View {
        if viewModel.isLoading {
            // 骨架屏加载
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    SongRowShimmer()
                }
            }
        } else if songs.isEmpty {
            // 空状态
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("还没有歌曲")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("点击右上角扫描本地音乐文件")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80)
        } else {
            List {
                ForEach(songs) { song in
                    SongRowView(song: song, showAlbumArt: showAlbumArt)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.play(song: song, from: songs)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteSong(song)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - 歌曲行视图

struct SongRowView: View {
    let song: Song
    let showAlbumArt: Bool
    /// 专辑页传入音轨号，行首显示曲序；为 nil 时按原样显示封面缩略图
    var trackNumber: Int? = nil
    @EnvironmentObject var viewModel: PlayerViewModel

    var isCurrentSong: Bool {
        viewModel.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            if let number = trackNumber {
                // 专辑页：行首曲目号
                Text(String(number))
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(isCurrentSong ? ColorPalette.primary : .secondary)
                    .frame(width: 28, alignment: .trailing)
            } else if showAlbumArt {
                albumArtThumbnail
            }

            // 歌曲信息
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 15, weight: isCurrentSong ? .semibold : .regular))
                    .foregroundColor(isCurrentSong ? ColorPalette.primary : .primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(song.displayArtist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if !song.album.isEmpty {
                        Text("·")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(song.album)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // 右侧信息
            VStack(alignment: .trailing, spacing: 4) {
                if isCurrentSong && viewModel.playbackState == .playing {
                    // 播放中的波形动画
                    NowPlayingIndicator()
                }

                Text(song.durationFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// 封面缩略图（无封面时用渐变占位）
    private var albumArtThumbnail: some View {
        Group {
            if let path = song.coverArtPath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(isCurrentSong
                          ? AnyShapeStyle(ColorPalette.gradientPlaying)
                          : AnyShapeStyle(ColorPalette.gradientPrimary.opacity(0.3)))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 14))
                    )
            }
        }
        .frame(width: 48, height: 48)
        .cornerRadius(6)
    }
}

// MARK: - 播放中指示器（小波形动画）

/// 「正在播放」的小波形指示器
///
/// ⚠️ 旧实现用 `Timer.scheduledTimer` 且**从不 invalidate**：
/// 视图消失后定时器仍在跑，随着列表滚动会不断累积，白白消耗 CPU。
/// 改用 `TimelineView`，视图移除时自动停止。
struct NowPlayingIndicator: View {
    private let patterns: [[CGFloat]] = [
        [0.5, 0.9, 0.4, 1.0, 0.6],
        [0.9, 0.4, 1.0, 0.5, 0.8],
        [0.4, 1.0, 0.6, 0.8, 0.5],
        [1.0, 0.6, 0.8, 0.4, 0.9],
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % patterns.count
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ColorPalette.primary)
                        .frame(width: 2.5, height: 12 * patterns[index][i])
                }
            }
            .animation(.easeInOut(duration: 0.3), value: index)
        }
    }
}

#Preview {
    SongListView(songs: [])
        .environmentObject(PlayerViewModel())
}
