import Foundation
import AVFoundation

/// 音频文件扫描器 — 扫描设备本地音频文件
final class FileScanner: ObservableObject {
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var scannedCount = 0

    /// 支持的音频格式
    static let supportedExtensions: Set<String> = [
        "mp3", "flac", "wav", "m4a", "aac",
        "wma", "ogg", "aiff", "alac", "opus"
    ]

    /// 扫描目录列表
    private let scanDirectories: [URL]

    init(scanDirectories: [URL]? = nil) {
        if let dirs = scanDirectories {
            self.scanDirectories = dirs
        } else {
            // 默认扫描 Documents 和 Music 目录
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first ?? documents
            self.scanDirectories = [documents, music]
        }
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

    /// 递归扫描单个目录
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
            // 检查是否取消
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
