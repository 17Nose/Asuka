import SwiftUI
import UIKit

// MARK: - 封面主色调提取

/// 从专辑封面提取主色调
///
/// 咪咕、Apple Music 播放页的背景都不是「模糊封面」，而是**从封面里提炼出一种颜色**
/// 铺成纯色渐变 —— 这样整页色调统一、有氛围，又不会被照片细节干扰阅读。
///
/// 直接对整图求平均会得到灰扑扑的褐色，所以这里：
/// 1. 先缩到 8×8（等于分块采样，顺便抹掉细节）
/// 2. 丢弃过暗/过亮的像素（黑边、白底会把结果拉灰）
/// 3. 按**饱和度加权**平均 —— 让鲜艳的颜色占更大话语权
enum CoverColorExtractor {

    /// 提取结果做了柔化处理（适合当页面背景）
    private static var cache: [String: UIColor] = [:]

    static func color(forPath path: String) -> UIColor? {
        if let cached = cache[path] { return cached }
        guard let image = UIImage(contentsOfFile: path),
              let raw = image.dominantColor else { return nil }

        let tuned = raw.tunedForPlayerBackground()
        cache[path] = tuned
        return tuned
    }
}

extension UIImage {

    /// 主色调：8×8 分块 + 饱和度加权平均
    var dominantColor: UIColor? {
        guard let cgImage = cgImage else { return nil }

        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)

        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, totalWeight: CGFloat = 0

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let cr = CGFloat(pixels[i]) / 255
            let cg = CGFloat(pixels[i + 1]) / 255
            let cb = CGFloat(pixels[i + 2]) / 255

            let maxC = max(cr, max(cg, cb))
            let minC = min(cr, min(cg, cb))
            let brightness = maxC
            let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC

            // 近乎全黑或全白的像素不参与统计
            guard brightness > 0.15, brightness < 0.95 else { continue }

            // 越鲜艳权重越高
            let weight = 0.2 + saturation * 3
            r += cr * weight
            g += cg * weight
            b += cb * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }
        return UIColor(red: r / totalWeight, green: g / totalWeight, blue: b / totalWeight, alpha: 1)
    }
}

extension UIColor {

    /// 调成适合当播放页背景的色调
    ///
    /// 封面原色可能是浅粉也可能是深灰，直接铺满不是太亮就是太闷。
    /// 统一拉一点饱和度、把亮度压进 0.28–0.52 这个区间，
    /// 既保证白字可读，又保留封面的色彩性格。
    func tunedForPlayerBackground() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }

        return UIColor(
            hue: h,
            saturation: min(s * 1.25 + 0.08, 1),
            brightness: min(max(b, 0.28), 0.52),
            alpha: 1
        )
    }

    /// 按增量调整亮度（用于渐变的两端）
    func adjustingBrightness(by delta: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: s, brightness: min(max(b + delta, 0), 1), alpha: a)
    }
}

// MARK: - 播放页背景

/// 播放页背景：由封面主色铺成的竖向渐变
///
/// 比「模糊封面 + 黑色遮罩」干净得多 —— 后者既吃 GPU，
/// 又因为叠了半透明黑而把整页压得发闷。
struct PlayerBackground: View {
    let coverPath: String?

    var body: some View {
        let base = resolvedBaseColor

        LinearGradient(
            colors: [
                Color(base).opacity(0.95),
                Color(base),
                Color(base.adjustingBrightness(by: -0.16)),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// 没有封面时退回品牌暖色，保证不会突然变成一坨灰
    private var resolvedBaseColor: UIColor {
        if let path = coverPath, let color = CoverColorExtractor.color(forPath: path) {
            return color
        }
        return UIColor(ColorPalette.coral).tunedForPlayerBackground()
    }
}
