import Foundation
import AVFoundation

/// 音频文件扫描器 — 扫描 App 内置音乐 + 用户导入的音乐
final class FileScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var scannedCount = 0

    /// 支持的音频格式
    /// 注：m4a / mp4 都是 MP4 容器；AVFoundation 能正常播放其中的音轨
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "mp4", "flac", "wav", "aac",
        "wma", "ogg", "aiff", "alac", "opus"
    ]

    /// App 内置音乐目录名（对应仓库 Resources/Music，构建时整体拷入 bundle）
    static let bundledMusicFolderName = "Music"

    /// 调用方自定义的扫描目录（默认 nil，走标准目录）
    private let customDirectories: [URL]?

    init(scanDirectories: [URL]? = nil) {
        self.customDirectories = scanDirectories
    }

    /// 实际要扫描的目录列表
    var scanDirectories: [URL] {
        if let custom = customDirectories {
            return custom
        }

        var dirs: [URL] = []

        // 1. App 内置音乐（随 IPA 打包，只读）
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent(Self.bundledMusicFolderName)
            if FileManager.default.fileExists(atPath: bundled.path) {
                dirs.append(bundled)
            }
        }

        // 2. 用户导入的音乐（文件 App / 爱思助手 / 应用内导入）
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            dirs.append(documents)
        }

        return dirs
    }

    /// 扫描所有目录，返回发现的音频文件 URL 列表
    func scan() async throws -> [URL] {
        await MainActor.run {
            isScanning = true
            progress = 0
            scannedCount = 0
        }

        var allFiles: [URL] = []

        for directory in scanDirectories {
            let files = try await scanDirectory(directory)
            allFiles.append(contentsOf: files)
        }

        await MainActor.run {
            isScanning = false
            progress = 1.0
            scannedCount = allFiles.count
        }

        return allFiles
    }

    /// 递归扫描单个目录（支持任意层级子文件夹）
    private func scanDirectory(_ directory: URL) async throws -> [URL] {
        var audioFiles: [URL] = []
        let fileManager = FileManager.default

        guard let isDirectory = try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
              isDirectory else {
            return audioFiles
        }

        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if Task.isCancelled { break }

            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues?.isDirectory == true { continue }

            let ext = fileURL.pathExtension.lowercased()
            if Self.supportedExtensions.contains(ext) {
                audioFiles.append(fileURL)
            }
        }

        return audioFiles
    }

    /// 扫描并返回文件路径字符串列表（方便与数据库交互）
    func scanFilePaths() async throws -> [String] {
        let urls = try await scan()
        return urls.map { $0.path }
    }
}
