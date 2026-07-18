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
    @EnvironmentObject var viewModel: PlayerViewModel

    var isCurrentSong: Bool {
        viewModel.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            // 封面或序号
            if showAlbumArt {
                Group {
                    if let path = song.coverArtPath,
                       let image = UIImage(contentsOfFile: path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(isCurrentSong
                                  ? ColorPalette.gradientPlaying
                                  : ColorPalette.gradientPrimary.opacity(0.3))
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
}

// MARK: - 播放中指示器（小波形动画）

struct NowPlayingIndicator: View {
    @State private var heights: [CGFloat] = [0.3, 0.6, 0.9, 0.6, 0.3]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(ColorPalette.primary)
                    .frame(width: 2.5, height: 12 * heights[i])
                    .animation(
                        Animation.easeInOut(duration: 0.4 + Double(i) * 0.1)
                            .repeatForever(autoreverses: true),
                        value: heights[i]
                    )
            }
        }
        .onAppear {
            heights = [0.8, 0.3, 1.0, 0.5, 0.7]
            animateWaves()
        }
    }

    private func animateWaves() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            heights = (0..<5).map { _ in CGFloat.random(in: 0.3...1.0) }
        }
    }
}

#Preview {
    SongListView(songs: [])
        .environmentObject(PlayerViewModel())
}
