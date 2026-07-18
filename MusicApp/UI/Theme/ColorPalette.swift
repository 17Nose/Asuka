import SwiftUI

/// 全局色彩系统
struct ColorPalette {

    // MARK: - 主题色
    static let primary = Color(hex: "6C5CE7")      // 紫色主色调
    static let secondary = Color(hex: "00CEC9")    // 青色辅色
    static let accent = Color(hex: "FD79A8")       // 粉色强调

    // MARK: - 功能色
    static let success = Color(hex: "00B894")
    static let warning = Color(hex: "FDCB6E")
    static let error = Color(hex: "E17055")

    // MARK: - 渐变
    static let gradientPrimary = LinearGradient(
        colors: [Color(hex: "6C5CE7"), Color(hex: "A29BFE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientPlaying = LinearGradient(
        colors: [Color(hex: "FD79A8"), Color(hex: "E17055")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - 背景色
    static let backgroundLight = Color(hex: "F8F9FA")
    static let backgroundDark = Color(hex: "1A1A2E")
    static let surfaceLight = Color.white
    static let surfaceDark = Color(hex: "16213E")
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
