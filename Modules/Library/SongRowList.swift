import SwiftUI

/// 可直接嵌入 `ScrollView` 的歌曲行列表
///
/// 详情页整体是一个 `ScrollView`，而 `SongListView` 内部用的是 `List`，
/// 嵌套滚动会出问题 —— 所以详情页统一用这个基于 `LazyVStack` 的版本，
/// 行本身仍然复用 `SongRowView`。
struct SongRowList: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    let songs: [Song]
    /// 是否显示封面缩略图（专辑页不显示，改用音轨号）
    var showAlbumArt: Bool = true
    /// 是否在行首显示音轨号
    var showTrackNumber: Bool = false
    var horizontalPadding: CGFloat = 20

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                SongRowView(
                    song: song,
                    showAlbumArt: showAlbumArt,
                    trackNumber: showTrackNumber ? (song.trackNumber > 0 ? song.trackNumber : index + 1) : nil
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticStyle.light.trigger()
                    viewModel.play(song: song, from: songs)
                }

                if index < songs.count - 1 {
                    Divider()
                        .padding(.leading, horizontalPadding + 40)
                }
            }
        }
    }
}
