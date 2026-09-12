import SwiftUI

/// 歌手详情页（Apple Music 风格）
///
/// 结构：大头像 + 歌手名 + 统计 → 播放/随机按钮 → 专辑横滑 → 全部歌曲
struct ArtistDetailView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var theme = ThemeManager.shared

    let artistName: String

    private var albums: [AlbumItem] {
        LibraryGrouping.albums(byArtist: artistName, from: viewModel.allSongs)
    }

    private var songs: [Song] {
        LibraryGrouping.songs(byArtist: artistName, from: viewModel.allSongs)
    }

    private var summary: String {
        "\(albums.count) 张专辑 · \(songs.count) 首歌"
    }

    /// 按歌手名生成稳定的主题色，不同歌手颜色不同
    private var accent: Color {
        let palette = ColorPalette.hues
        let index = abs(artistName.hashValue) % palette.count
        return palette[index]
    }

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actionButtons

                    if !albums.isEmpty {
                        albumsSection
                    }

                    if !songs.isEmpty {
                        songsSection
                    }
                }
                // 底部留白，避免被常驻的迷你播放条遮住
                .padding(.bottom, 110)
            }
        }
        // 根视图隐藏了导航栏，这里显式恢复，确保返回按钮可见
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(artistName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 148, height: 148)
                    .shadow(color: accent.opacity(0.35), radius: 22, y: 10)

                Text(String(artistName.prefix(1)))
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text(artistName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(summary)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - 播放按钮

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                playAll(shuffled: false)
            } label: {
                Label("播放", systemImage: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(ColorPalette.primary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .disabled(songs.isEmpty)

            Button {
                playAll(shuffled: true)
            } label: {
                Label("随机播放", systemImage: "shuffle")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(theme.surfaceColor)
                    .foregroundColor(ColorPalette.primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ColorPalette.primary.opacity(0.25), lineWidth: 1)
                    )
            }
            .disabled(songs.isEmpty)
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.96))
        .padding(.horizontal, 20)
    }

    // MARK: - 专辑横滑

    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("专辑")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(albums) { album in
                        NavigationLink(value: LibraryRoute.album(name: album.name, artist: album.artist)) {
                            AlbumCardView(
                                albumName: album.name,
                                artist: album.yearDisplay ?? album.artist,
                                coverPath: album.coverPath,
                                songCount: album.songCount
                            )
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 全部歌曲

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("全部歌曲")
            SongRowList(songs: songs)
        }
    }

    // MARK: - 辅助

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 20)
    }

    private func playAll(shuffled: Bool) {
        guard !songs.isEmpty else { return }
        HapticStyle.medium.trigger()
        let queue = shuffled ? songs.shuffled() : songs
        viewModel.play(song: queue[0], from: queue)
    }
}

#Preview {
    NavigationStack {
        ArtistDetailView(artistName: "周杰伦")
            .environmentObject(PlayerViewModel())
    }
}
