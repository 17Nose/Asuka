import SwiftUI

/// 歌手头像的来源
///
/// 优先级：
/// 1. **手动放入 `Resources/Artists/` 的照片**（随 IPA 打包，文件名 = 歌手名）
/// 2. 该歌手最早一张专辑的封面 —— 对周杰伦来说就是《Jay》那张，本身就有人像
/// 3. 都没有时回退到「首字 + 渐变圆」
///
/// 放照片的方法：仓库 → `Resources/Artists/` → 上传，文件名写成歌手名，
/// 例如 `周杰伦.jpg`。支持 jpg / jpeg / png / heic。
enum ArtistArtwork {

    /// App 包内的歌手照片目录名（对应仓库 Resources/Artists）
    private static let bundledFolderName = "Artists"

    /// 结果带缓存 —— 目录查找与图片解码都不便宜，而列表滚动会频繁调用
    private static var cache: [String: UIImage?] = [:]

    /// 包内预置的歌手照片（没有则 nil）
    static func bundledPhoto(for artist: String) -> UIImage? {
        if let cached = cache[artist] { return cached }

        let image = lookup(artist)
        cache[artist] = image
        return image
    }

    private static func lookup(_ artist: String) -> UIImage? {
        guard !artist.isEmpty,
              let resource = Bundle.main.resourceURL else { return nil }

        let directory = resource.appendingPathComponent(bundledFolderName)
        guard FileManager.default.fileExists(atPath: directory.path) else { return nil }

        for ext in ["jpg", "jpeg", "png", "heic"] {
            let url = directory.appendingPathComponent("\(artist).\(ext)")
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}
