import SwiftUI

/// App 入口
@main
struct RinApp: App {
    @StateObject private var playerViewModel = PlayerViewModel()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(playerViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        // 导航栏外观
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // TabBar 外观
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
