import Foundation

/// 音乐库导航路由
///
/// 用「值」驱动导航，配合 `NavigationLink(value:)` + `.navigationDestination(for:)`。
/// 专辑携带歌手名，避免不同歌手的同名专辑串台。
enum LibraryRoute: Hashable {
    case artist(String)
    case album(name: String, artist: String)
}
