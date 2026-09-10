import Foundation
import GRDB

/// 歌曲数据仓库
final class SongRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - 歌曲 CRUD

    /// 插入或更新一首歌曲
    func upsert(_ song: Song) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO song (id, file_path, title, artist, album, album_artist,
                    genre, year, duration, file_size, format, bitrate, sample_rate,
                    cover_art_path, date_added, date_modified)
                VALUES (:id, :file_path, :title, :artist, :album, :album_artist,
                    :genre, :year, :duration, :file_size, :format, :bitrate, :sample_rate,
                    :cover_art_path, :date_added, :date_modified)
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    artist = excluded.artist,
                    album = excluded.album,
                    album_artist = excluded.album_artist,
                    genre = excluded.genre,
                    year = excluded.year,
                    duration = excluded.duration,
                    file_size = excluded.file_size,
                    format = excluded.format,
                    bitrate = excluded.bitrate,
                    sample_rate = excluded.sample_rate,
                    cover_art_path = excluded.cover_art_path,
                    date_modified = excluded.date_modified
                """,
                arguments: StatementArguments(song.dictionary)
            )
        }
    }

    /// 批量插入或更新
    func upsertBatch(_ songs: [Song]) throws {
        try dbQueue.write { db in
            for song in songs {
                try db.execute(
                    sql: """
                    INSERT INTO song (id, file_path, title, artist, album, album_artist,
                        genre, year, duration, file_size, format, bitrate, sample_rate,
                        cover_art_path, date_added, date_modified)
                    VALUES (:id, :file_path, :title, :artist, :album, :album_artist,
                        :genre, :year, :duration, :file_size, :format, :bitrate, :sample_rate,
                        :cover_art_path, :date_added, :date_modified)
                    ON CONFLICT(id) DO UPDATE SET
                        title = excluded.title,
                        artist = excluded.artist,
                        album = excluded.album,
                        album_artist = excluded.album_artist,
                        genre = excluded.genre,
                        year = excluded.year,
                        duration = excluded.duration,
                        file_size = excluded.file_size,
                        format = excluded.format,
                        bitrate = excluded.bitrate,
                        sample_rate = excluded.sample_rate,
                        cover_art_path = excluded.cover_art_path,
                        date_modified = excluded.date_modified
                    """,
                    arguments: StatementArguments(song.dictionary)
                )
            }
        }
    }

    /// 根据 ID 获取歌曲
    func getById(_ id: String) throws -> Song? {
        try dbQueue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM song WHERE id = ?", arguments: [id])
                .map(Song.fromRow)
        }
    }

    /// 获取所有歌曲
    func getAll() throws -> [Song] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM song ORDER BY date_added DESC")
                .map(Song.fromRow)
        }
    }

    /// 获取最近添加的歌曲
    func getRecent(limit: Int = 20) throws -> [Song] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM song ORDER BY date_added DESC LIMIT ?",
                arguments: [limit]
            ).map(Song.fromRow)
        }
    }

    /// 删除歌曲
    func delete(_ id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM song WHERE id = ?", arguments: [id])
        }
    }

    /// 获取歌曲总数
    func count() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM song") ?? 0
        }
    }

    // MARK: - 搜索

    /// 全文搜索
    func search(_ query: String) throws -> [Song] {
        try dbQueue.read { db in
            let sql = """
            SELECT s.* FROM song s
            INNER JOIN song_fts ON s.id = song_fts.rowid
            WHERE song_fts MATCH ?
            ORDER BY rank
            LIMIT 50
            """
            return try Row.fetchAll(db, sql: sql, arguments: [query])
                .map(Song.fromRow)
        }
    }

    /// 简单模糊搜索（备用）
    func simpleSearch(_ query: String) throws -> [Song] {
        let pattern = "%\(query)%"
        return try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT * FROM song
                WHERE title LIKE ? OR artist LIKE ? OR album LIKE ?
                ORDER BY date_added DESC LIMIT 50
                """,
                arguments: [pattern, pattern, pattern]
            ).map(Song.fromRow)
        }
    }

    // MARK: - 按维度查询

    /// 按歌手分组
    func groupByArtist() throws -> [(artist: String, count: Int)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT artist, COUNT(*) as count FROM song
                WHERE artist != '' GROUP BY artist ORDER BY count DESC
                """
            ).map { ($0["artist"] ?? "未知歌手", $0["count"] ?? 0) }
        }
    }

    /// 按专辑分组
    func groupByAlbum() throws -> [(album: String, artist: String, count: Int)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                SELECT album, MAX(artist) as artist, COUNT(*) as count FROM song
                WHERE album != '' GROUP BY album ORDER BY count DESC
                """
            ).map { ($0["album"] ?? "未知专辑", $0["artist"] ?? "", $0["count"] ?? 0) }
        }
    }

    /// 获取某位歌手的歌曲
    func getByArtist(_ artist: String) throws -> [Song] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM song WHERE artist = ? ORDER BY album, title",
                arguments: [artist]
            ).map(Song.fromRow)
        }
    }

    // MARK: - 播放记录

    /// 记录播放
    func recordPlay(songId: String, duration: TimeInterval, skipped: Bool, source: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO play_record (song_id, played_at, play_duration, skipped, source)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [songId, Date(), duration, skipped, source]
            )
        }
    }

    /// 获取播放历史
    func getPlayHistory(limit: Int = 50) throws -> [PlayRecord] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM play_record ORDER BY played_at DESC LIMIT ?",
                arguments: [limit]
            ).map(PlayRecord.fromRow)
        }
    }

    // MARK: - 歌词缓存

    /// 保存歌词缓存
    func saveLyricsCache(_ cache: LyricsCache) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO lyrics_cache (song_id, lrc_content, tlrc_content, source, fetched_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(song_id) DO UPDATE SET
                    lrc_content = excluded.lrc_content,
                    tlrc_content = excluded.tlrc_content,
                    source = excluded.source,
                    fetched_at = excluded.fetched_at
                """,
                arguments: [
                    cache.id,
                    cache.lrcContent,
                    cache.tlrcContent,
                    cache.source,
                    cache.fetchedAt
                ]
            )
        }
    }

    /// 获取歌词缓存
    func getLyricsCache(songId: String) throws -> LyricsCache? {
        try dbQueue.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM lyrics_cache WHERE song_id = ?",
                arguments: [songId]
            ).map(LyricsCache.fromRow)
        }
    }

    /// 删除歌词缓存
    func deleteLyricsCache(songId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM lyrics_cache WHERE song_id = ?",
                arguments: [songId]
            )
        }
    }

    // MARK: - 播放列表 CRUD

    /// 保存播放列表（含歌曲关联）
    func savePlaylist(_ playlist: Playlist) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO playlist (id, name, description, cover_image_path, is_smart, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    description = excluded.description,
                    cover_image_path = excluded.cover_image_path,
                    is_smart = excluded.is_smart,
                    updated_at = excluded.updated_at
                """,
                arguments: [
                    playlist.id,
                    playlist.name,
                    playlist.description,
                    playlist.coverImagePath,
                    playlist.isSmart,
                    playlist.createdAt,
                    Date()
                ]
            )

            // 关联歌曲
            try db.execute(sql: "DELETE FROM playlist_song WHERE playlist_id = ?", arguments: [playlist.id])
            for (index, song) in playlist.songs.enumerated() {
                try db.execute(
                    sql: "INSERT INTO playlist_song (playlist_id, song_id, sort_order) VALUES (?, ?, ?)",
                    arguments: [playlist.id, song.id, index]
                )
            }
        }
    }

    /// 获取所有播放列表
    func getAllPlaylists() throws -> [Playlist] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM playlist ORDER BY updated_at DESC")
            return rows.map { row in
                let songs = (try? Row.fetchAll(
                    db,
                    sql: """
                    SELECT s.* FROM song s
                    JOIN playlist_song ps ON s.id = ps.song_id
                    WHERE ps.playlist_id = ?
                    ORDER BY ps.sort_order
                    """,
                    arguments: [row["id"] as String]
                ).map(Song.fromRow)) ?? []

                return Playlist(
                    id: row["id"],
                    name: row["name"] ?? "",
                    description: row["description"] ?? "",
                    coverImagePath: row["cover_image_path"],
                    isSmart: row["isSmart"] ?? false,
                    createdAt: row["created_at"] ?? Date(),
                    updatedAt: row["updated_at"] ?? Date(),
                    songs: songs
                )
            }
        }
    }

    /// 删除播放列表
    func deletePlaylist(_ id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM playlist WHERE id = ?", arguments: [id])
        }
    }
}

// MARK: - Song <-> Row 转换
extension Song {
    var dictionary: [String: DatabaseValueConvertible?] {
        [
            "id": id,
            "file_path": filePath,
            "title": title,
            "artist": artist,
            "album": album,
            "album_artist": albumArtist,
            "genre": genre,
            "year": year,
            "duration": duration,
            "file_size": fileSize,
            "format": format,
            "bitrate": bitrate,
            "sample_rate": sampleRate,
            "cover_art_path": coverArtPath,
            "date_added": dateAdded,
            "date_modified": dateModified
        ]
    }

    static func fromRow(_ row: Row) -> Song {
        Song(
            id: row["id"],
            filePath: row["file_path"],
            title: row["title"] ?? "未知歌曲",
            artist: row["artist"] ?? "",
            album: row["album"] ?? "",
            albumArtist: row["album_artist"] ?? "",
            genre: row["genre"] ?? "",
            year: row["year"] ?? 0,
            duration: row["duration"] ?? 0,
            fileSize: row["file_size"] ?? 0,
            format: row["format"] ?? "mp3",
            bitrate: row["bitrate"] ?? 0,
            sampleRate: row["sample_rate"] ?? 44100,
            coverArtPath: row["cover_art_path"],
            dateAdded: row["date_added"] ?? Date(),
            dateModified: row["date_modified"] ?? Date()
        )
    }
}

// MARK: - PlayRecord <-> Row 转换
extension PlayRecord {
    static func fromRow(_ row: Row) -> PlayRecord {
        PlayRecord(
            id: row["id"],
            songId: row["song_id"],
            playedAt: row["played_at"] ?? Date(),
            playDuration: row["play_duration"] ?? 0,
            skipped: row["skipped"] ?? false,
            source: row["source"] ?? "library"
        )
    }
}

// MARK: - LyricsCache <-> Row 转换
extension LyricsCache {
    static func fromRow(_ row: Row) -> LyricsCache {
        LyricsCache(
            songId: row["song_id"],
            lrcContent: row["lrc_content"],
            tlrcContent: row["tlrc_content"],
            source: row["source"] ?? "local",
            fetchedAt: row["fetched_at"] ?? Date()
        )
    }
}
