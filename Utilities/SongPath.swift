import Foundation

/// 音频文件路径的「安装无关」表示
///
/// **为什么需要这一层**
/// iOS 应用的沙盒路径里带一段随机 UUID，**每次重新安装都会变**：
/// ```
/// 旧: /var/mobile/Containers/Data/Application/AAAA-1111/Documents/歌.m4a
/// 新: /var/mobile/Containers/Data/Application/BBBB-2222/Documents/歌.m4a
/// ```
/// 如果把绝对路径直接存进数据库，重装后所有路径都会指向已经不存在的容器 ——
/// 表现就是「歌单还在、但一首也播不了、封面也全没了」。
///
/// 所以数据库里只存相对路径（带一个来源前缀），用到时再还原成当前安装的绝对路径。
enum SongPath {

    /// 沙盒文档目录（用户导入的音乐）
    private static let documentsMarker = "documents://"
    /// App 包内资源（随 IPA 打包的内置音乐）
    private static let bundleMarker = "bundle://"
    /// 缓存目录（封面图）
    private static let cachesMarker = "caches://"

    // MARK: - 当前安装的目录

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    static var bundleResourceDirectory: URL? {
        Bundle.main.resourceURL
    }

    // MARK: - 规范化（存库前调用）

    /// 把绝对路径转成与安装无关的形式
    static func normalize(_ absolutePath: String) -> String {
        // 已经是相对形式，直接返回（重复调用安全）
        if isNormalized(absolutePath) { return absolutePath }

        return prefix(for: absolutePath) + stripPrefix(absolutePath)
    }

    /// 是否已经是与安装无关的形式
    static func isNormalized(_ path: String) -> Bool {
        path.hasPrefix(documentsMarker)
            || path.hasPrefix(bundleMarker)
            || path.hasPrefix(cachesMarker)
    }

    // MARK: - 还原（使用时调用）

    /// 把存库的相对路径还原成当前安装下的绝对路径
    static func resolve(_ storedPath: String) -> String {
        if storedPath.hasPrefix(documentsMarker) {
            let relative = String(storedPath.dropFirst(documentsMarker.count))
            return documentsDirectory.appendingPathComponent(relative).path
        }
        if storedPath.hasPrefix(bundleMarker) {
            let relative = String(storedPath.dropFirst(bundleMarker.count))
            if let resource = bundleResourceDirectory {
                return resource.appendingPathComponent(relative).path
            }
        }
        if storedPath.hasPrefix(cachesMarker) {
            let relative = String(storedPath.dropFirst(cachesMarker.count))
            return cachesDirectory.appendingPathComponent(relative).path
        }
        // 不是已知形式：原样返回（例如外部路径）
        return storedPath
    }

    static func url(for storedPath: String) -> URL {
        URL(fileURLWithPath: resolve(storedPath))
    }

    // MARK: - 修复历史数据

    /// 把**旧版本存下的、已失效的绝对路径**转成相对形式
    ///
    /// 与 `normalize` 的区别：旧路径里的容器 UUID 和当前安装不一致，
    /// 无法用「是否以当前 Documents 开头」来判断，只能从路径中间找 `/Documents/` 这类锚点。
    static func salvage(_ storedPath: String) -> String {
        if isNormalized(storedPath) { return storedPath }

        // /Documents/ 之后的部分就是稳定的相对路径
        if let range = storedPath.range(of: "/Documents/") {
            return documentsMarker + String(storedPath[range.upperBound...])
        }
        // 封面图以前存在 Caches/CoverArt/
        if let range = storedPath.range(of: "/Caches/") {
            return cachesMarker + String(storedPath[range.upperBound...])
        }
        // 旧的内置音乐：.../Rin.app/Music/xxx
        if let range = storedPath.range(of: ".app/") {
            return bundleMarker + String(storedPath[range.upperBound...])
        }
        return storedPath
    }

    /// 取文件名，用于日志与兜底
    static func fileName(of storedPath: String) -> String {
        (resolve(storedPath) as NSString).lastPathComponent
    }

    // MARK: - 私有

    private static func prefix(for absolutePath: String) -> String {
        if absolutePath.hasPrefix(documentsDirectory.path + "/") { return documentsMarker }
        if let resource = bundleResourceDirectory,
           absolutePath.hasPrefix(resource.path + "/") { return bundleMarker }
        if absolutePath.hasPrefix(cachesDirectory.path + "/") { return cachesMarker }
        return ""   // 未知位置：保持绝对路径
    }

    private static func stripPrefix(_ absolutePath: String) -> String {
        let candidates: [(String, String)] = [
            (documentsDirectory.path + "/", documentsMarker),
            (cachesDirectory.path + "/", cachesMarker),
        ] + (bundleResourceDirectory.map { [($0.path + "/", bundleMarker)] } ?? [])

        for (prefix, marker) in candidates {
            if absolutePath.hasPrefix(prefix) {
                return String(absolutePath.dropFirst(prefix.count))
            }
        }
        return absolutePath
    }
}

// MARK: - 文件是否仍然存在

extension SongPath {
    /// 解析后文件是否存在（用于检测路径失效）
    static func exists(_ storedPath: String) -> Bool {
        FileManager.default.fileExists(atPath: resolve(storedPath))
    }
}
