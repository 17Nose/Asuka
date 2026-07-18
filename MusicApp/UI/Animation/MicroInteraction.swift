import SwiftUI

// MARK: - 微动效按钮样式

/// 弹性缩放按钮（点击时缩小再弹回）
struct BouncyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.9
    var duration: Double = 0.2

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(
                .spring(response: duration, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

/// 带光泽扫过的按钮
struct ShinyButtonStyle: ButtonStyle {
    var color: Color = ColorPalette.primary
    var height: CGFloat = 48

    @State private var isShimmering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                ZStack {
                    color
                    // 光泽扫过
                    GeometryReader { geo in
                        Color.white.opacity(0.3)
                            .frame(width: geo.size.width * 0.3)
                            .blur(radius: 8)
                            .offset(x: isShimmering ? geo.size.width : -geo.size.width * 0.3)
                            .animation(
                                Animation.linear(duration: 2).repeatForever(autoreverses: false),
                                value: isShimmering
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(color: color.opacity(0.4), radius: 12, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onAppear { isShimmering = true }
    }
}

// MARK: - 触觉反馈

enum HapticStyle {
    case light
    case medium
    case heavy
    case selection
    case success

    func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - View 扩展：微动效

extension View {

    /// 按下时缩放
    func pressAnimation(scale: CGFloat = 0.95) -> some View {
        self.modifier(PressEffectModifier(scale: scale))
    }

    /// 浮动动画（模仿 Apple Music 正在播放效果）
    func floatingAnimation(isActive: Bool, amplitude: CGFloat = 6) -> some View {
        self.modifier(FloatingModifier(isActive: isActive, amplitude: amplitude))
    }

    /// 呼吸动画（渐变脉冲）
    func breathingAnimation(isActive: Bool) -> some View {
        self.modifier(BreathingModifier(isActive: isActive))
    }

    /// 点击波纹效果
    func rippleEffect() -> some View {
        self.modifier(RippleModifier())
    }
}

// MARK: - 按压效果

struct PressEffectModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed { HapticStyle.light.trigger() }
                        isPressed = true
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - 浮动动画

struct FloatingModifier: ViewModifier {
    let isActive: Bool
    let amplitude: CGFloat

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? offset : 0)
            .animation(
                Animation.easeInOut(duration: 2)
                    .repeatForever(autoreverses: true),
                value: offset
            )
            .onChange(of: isActive) { active in
                if active {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        offset = amplitude
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - 呼吸动画（脉冲）

struct BreathingModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                value: isActive
            )
    }
}

// MARK: - 波纹效果

struct RippleModifier: ViewModifier {
    @State private var ripples: [Ripple] = []

    struct Ripple: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0.3
        var opacity: Double = 0.6
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    ForEach(ripples) { ripple in
                        Circle()
                            .stroke(ColorPalette.primary.opacity(ripple.opacity), lineWidth: 2)
                            .scaleEffect(ripple.scale)
                            .opacity(ripple.opacity)
                            .animation(.easeOut(duration: 0.6), value: ripple.scale)
                    }
                }
            )
            .onTapGesture {
                let ripple = Ripple()
                ripples.append(ripple)

                withAnimation(.easeOut(duration: 0.6)) {
                    if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                        ripples[idx].scale = 2.0
                        ripples[idx].opacity = 0
                    }
                }

                // 清理
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    ripples.removeAll { $0.id == ripple.id }
                }
            }
    }
}

// MARK: - 自定义开关动画

struct AnimatedToggle: View {
    @Binding var isOn: Bool
    var onColor: Color = ColorPalette.primary

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(isOn ? onColor : Color.secondary.opacity(0.2))
                .frame(width: 48, height: 28)

            Circle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                .frame(width: 22, height: 22)
                .offset(x: isOn ? 11 : -11)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        }
        .onTapGesture {
            HapticStyle.selection.trigger()
            withAnimation { isOn.toggle() }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        Button("弹性按钮") {}
            .buttonStyle(BouncyButtonStyle())
            .padding(.horizontal)

        Button("光泽按钮") {}
            .buttonStyle(ShinyButtonStyle())
            .padding(.horizontal)

        AnimatedToggle(isOn: .constant(true))
        AnimatedToggle(isOn: .constant(false))

        Circle()
            .fill(ColorPalette.primary)
            .frame(width: 60, height: 60)
            .floatingAnimation(isActive: true, amplitude: 8)
    }
    .padding()
}
