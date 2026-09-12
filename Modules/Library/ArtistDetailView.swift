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

    // MARK: - 歌手头像

    /// 头部：有照片 → 满宽横幅；没有 → 圆形头像
    ///
    /// 放照片的方法见 `ArtistArtwork`：仓库 `Resources/Artists/<歌手名>.jpg`。
    @ViewBuilder
    private var header: some View {
        if let photo = ArtistArtwork.bundledPhoto(for: artistName) {
            bannerHeader(photo)
        } else {
            circularHeader
        }
    }

    /// 满宽横幅
    ///
    /// 歌手照片通常是横图（比如这张 3.15:1 的），塞进圆形会被裁掉大半。
    /// 铺成横幅既完整展示，也是 Apple Music 歌手页的做法。
    private func bannerHeader(_ photo: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                // 底部渐隐到页面背景，避免横幅和下方文字硬切一刀
                .overlay(
                    LinearGradient(
                        colors: [.clear, theme.backgroundColor.opacity(0.85)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(artistName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.textPrimary)

                Text(summary)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.horizontal, 20)
        }
    }

    /// 没有照片时的圆形头像 + 居中姓名
    private var circularHeader: some View {
        VStack(spacing: 14) {
            avatar

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
    }

    /// 圆形头像（照片 → 最早专辑封面 → 首字渐变圆）
    @ViewBuilder
    private var avatar: some View {
        let side: CGFloat = 148

        Group {
            if let path = representativeCoverPath,
               let cover = UIImage(contentsOfFile: path) {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [accent, accent.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(String(artistName.prefix(1)))
                        .font(.system(size: 62, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    /// 代表封面：专辑按年份倒序排列，取最后一张 = 最早那张
    private var representativeCoverPath: String? {
        albums.last?.coverPath
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
