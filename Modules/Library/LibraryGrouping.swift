import Foundation

// MARK: - 聚合模型

/// 专辑聚合条目
struct AlbumItem: Identifiable {
    let name: String
    let artist: String
    let coverPath: String?
    let year: Int
    /// 已按音轨号排序
    let songs: [Song]

    /// 唯一键用「歌手 + 专辑名」，避免不同歌手的同名专辑互相覆盖
    var id: String { "\(artist)\u{1F}\(name)" }

    var songCount: Int { songs.count }

    /// 年份展示（无年份时 nil）
    var yearDisplay: String? { year > 0 ? String(year) : nil }
}

/// 歌手聚合条目
struct ArtistItem: Identifiable {
    let name: String
    let songCount: Int
    let albumCount: Int
    var id: String { name }

    /// "12 首歌 · 3 张专辑"
    var summary: String {
        "\(songCount) 首歌 · \(albumCount) 张专辑"
    }
}

// MARK: - 分组逻辑（集中一处，避免各视图各写一套）

enum LibraryGrouping {

    /// 专辑列表（专辑内按音轨号排序，专辑间新专辑在前）
    static func albums(from songs: [Song]) -> [AlbumItem] {
        var buckets: [String: [Song]] = [:]
        for song in songs {
            buckets[albumKey(for: song), default: []].append(song)
        }

        return buckets.values
            .compactMap { group -> AlbumItem? in
                guard let first = group.first else { return nil }
                return AlbumItem(
                    name: first.displayAlbum,
                    artist: first.groupingArtist,
                    // 优先取组内有封面的那首
                    coverPath: group.first(where: { $0.coverArtPath != nil })?.coverArtPath,
                    year: group.map(\.year).first(where: { $0 > 0 }) ?? 0,
                    songs: sortTracks(group)
                )
            }
            .sorted(by: albumOrder)
    }

    /// 歌手列表（歌曲数降序）
    static func artists(from songs: [Song]) -> [ArtistItem] {
        Dictionary(grouping: songs, by: \.groupingArtist)
            .map { name, group in
                ArtistItem(
                    name: name,
                    songCount: group.count,
                    albumCount: Set(group.map(\.displayAlbum)).count
                )
            }
            .sorted { lhs, rhs in
                if lhs.songCount != rhs.songCount { return lhs.songCount > rhs.songCount }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// 某歌手名下的专辑
    static func albums(byArtist artist: String, from songs: [Song]) -> [AlbumItem] {
        albums(from: songs.filter { $0.groupingArtist == artist })
    }

    /// 某歌手名下的全部歌曲
    static func songs(byArtist artist: String, from songs: [Song]) -> [Song] {
        songs.filter { $0.groupingArtist == artist }
    }

    /// 某张专辑的曲目
    static func songs(inAlbum album: String, artist: String, from songs: [Song]) -> [Song] {
        sortTracks(songs.filter {
            $0.displayAlbum == album && $0.groupingArtist == artist
        })
    }

    /// 专辑内曲序：有音轨号的按音轨号，没有的按标题，且无音轨号的排后面
    static func sortTracks(_ songs: [Song]) -> [Song] {
        songs.sorted { lhs, rhs in
            let l = lhs.trackNumber
            let r = rhs.trackNumber
            if l > 0 && r > 0 { return l < r }
            if l > 0 { return true }
            if r > 0 { return false }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - 私有

    /// 专辑分组键 = 歌手 + 专辑名
    private static func albumKey(for song: Song) -> String {
        "\(song.groupingArtist)\u{1F}\(song.displayAlbum)"
    }

    /// 专辑排序：有年份的按年份降序（新专辑在前），无年份的排最后
    private static func albumOrder(_ lhs: AlbumItem, _ rhs: AlbumItem) -> Bool {
        if lhs.year != rhs.year {
            if lhs.year == 0 { return false }
            if rhs.year == 0 { return true }
            return lhs.year > rhs.year
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Song 分组辅助

extension Song {
    /// 分组用歌手名：优先 albumArtist，回退 artist，都为空则「未知歌手」
    var groupingArtist: String {
        let name = albumArtist.isEmpty ? artist : albumArtist
        return name.isEmpty ? "未知歌手" : name
    }
}
