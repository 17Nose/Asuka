import SwiftUI

/// 全局色彩系统
///
/// **设计取向**
/// 之前整个 App 都刷同一种蓝紫（`#6C5CE7`），按钮、进度条、高亮、渐变全是它 ——
/// 这种做法很省事，但冷、平、没有性格。
///
/// 现在改成「暖调主导 + 冷色撞色」：
/// - **珊瑚红 → 落日橙** 做主渐变：暖、有温度，放在深色沉浸背景上比冷蓝更抓眼
/// - **薄荷绿** 做辅色/播放态：和暖主色形成冷暖碰撞，是「年轻感」的来源
/// - **玫瑰粉 / 葡萄紫** 做强调与点缀
/// - 背景也去掉了原来的藏蓝，换成中性的暖灰，避免全屏泛蓝
struct ColorPalette {

    // MARK: - 基础色板

    /// 珊瑚红 —— 主色
    static let coral  = Color(hex: "FF6B6B")
    /// 落日橙 —— 主渐变尾色
    static let sunset = Color(hex: "FF9F43")
    /// 琥珀黄 —— 高亮/标签
    static let amber  = Color(hex: "FFD166")
    /// 薄荷绿 —— 辅色 / 播放态
    static let mint   = Color(hex: "3DDC97")
    /// 葡萄紫 —— 冷色点缀
    static let grape  = Color(hex: "A78BFA")
    /// 玫瑰粉 —— 强调
    static let rose   = Color(hex: "F368A4")

    // MARK: - 语义色

    static let primary   = coral
    static let secondary = mint
    static let accent    = rose

    static let success = mint
    static let warning = amber
    static let error   = coral

    // MARK: - 渐变

    /// 主渐变：珊瑚 → 落日（暖）
    static let gradientPrimary = LinearGradient(
        colors: [coral, sunset],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 播放态渐变：薄荷 → 青碧（冷），和主渐变撞色
    static let gradientPlaying = LinearGradient(
        colors: [mint, Color(hex: "2BB8A8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 冷色渐变：葡萄 → 玫瑰（点缀用）
    static let gradientCool = LinearGradient(
        colors: [grape, rose],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 背景色

    /// 暖白（不是冷灰）
    static let backgroundLight = Color(hex: "FAF8F5")
    /// 中性偏暖的深色（去掉了原来的藏蓝 #1A1A2E）
    static let backgroundDark  = Color(hex: "1C1A1F")
    static let surfaceLight = Color.white
    static let surfaceDark  = Color(hex: "26232B")

    // MARK: - 歌手/专辑的撞色组

    /// 给列表项、头像等按索引取色，刻意让相邻颜色跨度大一些，撞出年轻感
    static let hues: [Color] = [
        coral,
        mint,
        grape,
        sunset,
        rose,
        Color(hex: "A3E635"),   // 青柠
        Color(hex: "22D3EE"),   // 靛青
        amber,
    ]
}

// MARK: - Hex 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
