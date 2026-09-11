import Foundation
import GRDB

/// 数据库管理器 — 使用 GRDB.swift 封装 SQLite 操作
final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {}

    // MARK: - 初始化数据库

    func setup() throws {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first!

        // 确保目录存在
        try FileManager.default.createDirectory(
            at: documentsPath, withIntermediateDirectories: true
        )

        let dbPath = documentsPath.appendingPathComponent(Constants.databaseFileName).path
        print("📁 数据库路径: \(dbPath)")

        dbQueue = try DatabaseQueue(path: dbPath)
        try createTables()
        try migrate()
    }

    // MARK: - 轻量迁移

    /// 补充后来新增的列
    /// 所有表都是 `ifNotExists` 建的，新增列对**已存在的库**不会生效，
    /// 必须显式 ALTER TABLE。这里按需幂等执行，重复运行无副作用。
    private func migrate() throws {
        guard let dbQueue = dbQueue else { return }

        try dbQueue.write { db in
            let existingColumns = try Row
                .fetchAll(db, sql: "PRAGMA table_info(song)")
                .compactMap { $0["name"] as String? }

            if !existingColumns.contains("track_number") {
                try db.execute(sql: "ALTER TABLE song ADD COLUMN track_number INTEGER")
                print("✅ 迁移：song 表新增 track_number 列")
            }
        }
    }

    func getQueue() throws -> DatabaseQueue {
        guard let queue = dbQueue else {
            throw DatabaseError.notInitialized
        }
        return queue
    }

    // MARK: - 建表

    private func createTables() throws {
        guard let dbQueue = dbQueue else { return }

        try dbQueue.write { db in
            // 歌曲表
            try db.create(table: "song", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("file_path", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("artist", .text)
                t.column("album", .text)
                t.column("album_artist", .text)
                t.column("genre", .text)
                t.column("year", .integer)
                t.column("track_number", .integer)
                t.column("duration", .double)
                t.column("file_size", .integer)
                t.column("format", .text)
                t.column("bitrate", .integer)
                t.column("sample_rate", .integer)
                t.column("cover_art_path", .text)
                t.column("date_added", .datetime).notNull()
                t.column("date_modified", .datetime)
            }

            // 播放记录表
            try db.create(table: "play_record", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("song_id", .text).notNull().references("song", onDelete: .cascade)
                t.column("played_at", .datetime).notNull()
                t.column("play_duration", .double)
                t.column("skipped", .boolean).defaults(to: false)
                t.column("source", .text)
            }

            // 播放列表表
            try db.create(table: "playlist", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("cover_image_path", .text)
                t.column("is_smart", .boolean).defaults(to: false)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // 播放列表-歌曲关联表
            try db.create(table: "playlist_song", ifNotExists: true) { t in
                t.column("playlist_id", .text).notNull().references("playlist", onDelete: .cascade)
                t.column("song_id", .text).notNull().references("song", onDelete: .cascade)
                t.column("sort_order", .integer).notNull()
                t.primaryKey(["playlist_id", "song_id"])
            }

            // 歌词缓存表
            try db.create(table: "lyrics_cache", ifNotExists: true) { t in
                t.column("song_id", .text).primaryKey().references("song", onDelete: .cascade)
                t.column("lrc_content", .text)
                t.column("tlrc_content", .text)
                t.column("source", .text)
                t.column("fetched_at", .datetime)
            }

            // 全文搜索索引
            try db.create(virtualTable: "song_fts", ifNotExists: true, using: FTS5()) { t in
                t.column("title")
                t.column("artist")
                t.column("album")
                t.content = "song"
            }

            print("✅ 数据库表创建成功")
        }
    }

    // MARK: - 清空数据库

    /// 清空全部音乐库数据（路径失效时的重建流程会用到）
    func clearAll() throws {
        guard let dbQueue = dbQueue else { return }
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM playlist_song")
            try db.execute(sql: "DELETE FROM play_record")
            try db.execute(sql: "DELETE FROM lyrics_cache")
            try db.execute(sql: "DELETE FROM song")
            try db.execute(sql: "DELETE FROM playlist")
            // song_fts 是 external-content 表，删了 song 之后必须重建索引，
            // 否则残留的索引行会指向已删除的 rowid
            try db.execute(sql: "INSERT INTO song_fts(song_fts) VALUES('rebuild')")
        }
    }
}

// MARK: - 数据库错误
enum DatabaseError: Error {
    case notInitialized
    case songNotFound
    case insertFailed
    case searchFailed
}
