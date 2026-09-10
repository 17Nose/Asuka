import SwiftUI

/// 专辑详情页（Apple Music 风格）
///
/// 结构：封面 + 专辑名 + 歌手 + 年份曲目数 → 播放/随机按钮 → 带曲序的曲目列表
struct AlbumDetailView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var theme = ThemeManager.shared

    let albumName: String
    let artistName: String

    private var songs: [Song] {
        LibraryGrouping.songs(inAlbum: albumName, artist: artistName, from: viewModel.allSongs)
    }

    private var coverPath: String? {
        songs.first(where: { $0.coverArtPath != nil })?.coverArtPath
    }

    private var year: Int {
        songs.map(\.year).first(where: { $0 > 0 }) ?? 0
    }

    private var summary: String {
        var parts: [String] = []
        if year > 0 { parts.append(String(year)) }
        parts.append("\(songs.count) 首")
        parts.append(artistName)
        return parts.joined(separator: " · ")
    }

    /// 有音轨号时用它做一张「真正有序」的播放队列
    private var orderedTracks: [Song] {
        LibraryGrouping.sortTracks(songs)
    }

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    actionButtons

                    if !songs.isEmpty {
                        SongRowList(
                            songs: orderedTracks,
                            showAlbumArt: false,
                            showTrackNumber: true
                        )
                    }
                }
                .padding(.bottom, 110)
            }
        }
        // 根视图隐藏了导航栏，这里显式恢复，确保返回按钮可见
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(albumName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 头部

    private var header: some View {
        VStack(spacing: 14) {
            coverView
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 18, y: 10)

            VStack(spacing: 6) {
                Text(albumName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(summary)
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var coverView: some View {
        if let path = coverPath,
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.gradientPrimary.opacity(0.35))
                .overlay(
                    Image(systemName: "music.note.list")
                        .font(.system(size: 46))
                        .foregroundColor(.white.opacity(0.7))
                )
        }
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

    // MARK: - 辅助

    private func playAll(shuffled: Bool) {
        guard !orderedTracks.isEmpty else { return }
        HapticStyle.medium.trigger()
        let queue = shuffled ? orderedTracks.shuffled() : orderedTracks
        viewModel.play(song: queue[0], from: queue)
    }
}

#Preview {
    NavigationStack {
        AlbumDetailView(albumName: "范特西", artistName: "周杰伦")
            .environmentObject(PlayerViewModel())
    }
}
