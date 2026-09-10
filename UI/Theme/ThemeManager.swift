import SwiftUI

// MARK: - 主题模式
enum ThemeMode: String, CaseIterable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - 主题管理器
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "theme_mode") }
    }
    @Published var accentColor: Color {
        didSet { saveAccentColor() }
    }

    private let defaults = UserDefaults.standard

    private init() {
        let modeRaw = defaults.string(forKey: "theme_mode") ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode.allCases.first { $0.rawValue == modeRaw } ?? .system
        self.accentColor = ThemeManager.loadAccentColor()
    }

    // MARK: - 主题色方案

    /// 预定义主题色
    static let accentColors: [(name: String, color: Color)] = [
        ("紫罗兰", Color(hex: "6C5CE7")),
        ("海洋蓝", Color(hex: "0984E3")),
        ("珊瑚粉", Color(hex: "FD79A8")),
        ("翡翠绿", Color(hex: "00B894")),
        ("日落橙", Color(hex: "E17055")),
        ("青碧", Color(hex: "00CEC9")),
        ("暗夜紫", Color(hex: "A29BFE")),
        ("玫瑰金", Color(hex: "E84393")),
    ]

    /// 获取当前主题的背景色
    var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1A1A2E") : Color(hex: "F8F9FA")
    }

    /// 获取当前主题的表面色
    var surfaceColor: Color {
        colorScheme == .dark ? Color(hex: "16213E") : .white
    }

    /// 获取当前主题的文字色
    var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "2D3436")
    }

    var textSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.6) : Color(hex: "636E72")
    }

    /// 获取毛玻璃材质
    var material: Material {
        colorScheme == .dark ? .ultraThinMaterial : .regularMaterial
    }

    // MARK: - 色彩方案
    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - 持久化
    private func saveAccentColor() {
        // 用 UserDefaults 无法直接存 Color，用 hex 字符串代替
        // 简化处理：存储索引
        if let index = Self.accentColors.firstIndex(where: { $0.color == accentColor }) {
            defaults.set(index, forKey: "accent_color_index")
        }
    }

    private static func loadAccentColor() -> Color {
        let index = UserDefaults.standard.integer(forKey: "accent_color_index")
        guard index < accentColors.count else { return accentColors[0].color }
        return accentColors[index].color
    }
}

// MARK: - 主题环境 Key
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - 主题修饰器
struct ThemedNavigationBar: ViewModifier {
    @ObservedObject var theme = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(theme.colorScheme)
    }
}

extension View {
    func themed() -> some View {
        modifier(ThemedNavigationBar())
    }
}
