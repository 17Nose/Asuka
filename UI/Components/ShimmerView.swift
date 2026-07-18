import SwiftUI

/// 骨架屏加载效果
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.15),
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.15)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: phase * geometry.size.width)
                .animation(
                    Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
                .onAppear { phase = 1 }
        }
    }
}

/// 歌曲列表骨架屏
struct SongRowShimmer: View {
    var body: some View {
        HStack(spacing: 12) {
            ShimmerView()
                .frame(width: 48, height: 48)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 8) {
                ShimmerView()
                    .frame(height: 14)
                    .cornerRadius(4)
                ShimmerView()
                    .frame(width: 120, height: 12)
                    .cornerRadius(4)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
