import SwiftUI

// MARK: - 自定义转场动画

/// 从底部弹出 + 弹性效果
struct SpringBottomTransition: ViewModifier {
    let isPresented: Bool
    let dampingFraction: CGFloat

    init(isPresented: Bool, dampingFraction: CGFloat = 0.8) {
        self.isPresented = isPresented
        self.dampingFraction = dampingFraction
    }

    func body(content: Content) -> some View {
        content
            .offset(y: isPresented ? 0 : UIScreen.main.bounds.height)
            .animation(
                .spring(response: 0.55, dampingFraction: dampingFraction),
                value: isPresented
            )
    }
}

/// 缩放 + 透明度过渡（Hero 动画基础）
struct ScaleFadeTransition: ViewModifier {
    let isPresented: Bool
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPresented ? 1 : 0.8, anchor: anchor)
            .opacity(isPresented ? 1 : 0)
    }
}

/// 匹配几何变化（用于 Hero 动画）
struct MatchedGeometryEffect: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let isSource: Bool

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                anchor: .center,
                isSource: isSource
            )
    }
}

// MARK: - View 扩展

extension View {

    /// 弹性底部弹出
    func springBottomTransition(isPresented: Bool, damping: CGFloat = 0.8) -> some View {
        modifier(SpringBottomTransition(isPresented: isPresented, dampingFraction: damping))
    }

    /// 缩放淡入淡出
    func scaleFade(isPresented: Bool, anchor: UnitPoint = .center) -> some View {
        modifier(ScaleFadeTransition(isPresented: isPresented, anchor: anchor))
    }

    /// Hero 匹配几何动画
    func heroAnimation(id: String, namespace: Namespace.ID, isSource: Bool = true) -> some View {
        modifier(MatchedGeometryEffect(id: id, namespace: namespace, isSource: isSource))
    }

    /// 自定义转场（滑动 + 缩放）
    func slideInFromBottom(then fade: Bool = true) -> some View {
        self.transition(
            .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.95)),
                removal: .move(edge: .bottom)
                    .combined(with: .opacity)
            )
        )
    }

    /// 列表项延迟出现动画
    func staggeredAppear(index: Int, baseDelay: Double = 0.05) -> some View {
        self.opacity(1)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.7)
                .delay(baseDelay * Double(index)),
                value: true
            )
    }
}

// MARK: - 自定义转场动画结构
//
// 说明：基于 `Transition.body(content:phase:)` 的自定义 Transition 需要 iOS 17+。
// 本项目最低支持 iOS 16，因此自定义转场统一用上面的
// `.slideInFromBottom()` / `.scaleFade()` / `.springBottomTransition()` 实现。

// MARK: - 导航动画命名空间

/// 全局动画命名空间（用于跨视图共享）
struct AnimationNamespace {
    static let nowPlaying = "nowPlaying"
    static let albumArt = "albumArt"
    static let songTitle = "songTitle"
    static let progressBar = "progressBar"
}

/// 共享的命名空间环境 Key
struct TransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var transitionNamespace: Namespace.ID? {
        get { self[TransitionNamespaceKey.self] }
        set { self[TransitionNamespaceKey.self] = newValue }
    }
}
