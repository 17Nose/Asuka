import SwiftUI

/// 毛玻璃卡片组件
struct GlassmorphicCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 20
    var blurRadius: CGFloat = 10
    var opacity: CGFloat = 0.15
    var shadowRadius: CGFloat = 10
    var padding: CGFloat = 16

    init(
        cornerRadius: CGFloat = 20,
        blurRadius: CGFloat = 10,
        opacity: CGFloat = 0.15,
        shadowRadius: CGFloat = 10,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.blurRadius = blurRadius
        self.opacity = opacity
        self.shadowRadius = shadowRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: Color.black.opacity(0.12),
                radius: shadowRadius,
                x: 0,
                y: 4
            )
    }
}

/// 沉浸式毛玻璃卡片（更透明的变体）
struct ImmersiveCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 24

    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ZStack {
        ColorPalette.gradientPrimary.ignoresSafeArea()

        VStack(spacing: 20) {
            GlassmorphicCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("毛玻璃卡片")
                        .font(.headline)
                    Text("半透明模糊背景效果")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            ImmersiveCard {
                HStack {
                    Image(systemName: "music.note")
                        .font(.title)
                    Text("沉浸式卡片")
                        .font(.headline)
                }
                .padding()
            }
        }
        .padding()
    }
}
