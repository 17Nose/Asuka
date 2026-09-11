import SwiftUI

/// 自定义进度滑块（带弹性效果和波形预览）
struct MusicProgressSlider: View {
    @Binding var progress: CGFloat       // 0...1
    var duration: TimeInterval
    var currentTime: TimeInterval
    var waveformSamples: [CGFloat] = []
    var onSeek: ((TimeInterval) -> Void)?

    @State private var isDragging = false
    @State private var dragProgress: CGFloat = 0
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)

    /// 把手直径。常量 —— 放大只走 scaleEffect，避免布局尺寸变化引起位移
    private static let knobSize: CGFloat = 16

    private var displayProgress: CGFloat {
        isDragging ? dragProgress : progress
    }

    /// 把手的水平偏移量
    /// - 进度 0 → 0（把手中心在轨道起点）
    /// - 进度 1 → trackWidth - knobSize（把手中心在轨道终点）
    private func knobOffset(trackWidth: CGFloat, progress: CGFloat) -> CGFloat {
        let usable = max(0, trackWidth - Self.knobSize)
        return usable * min(max(progress, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            // 主滑块
            sliderTrack
                .frame(height: 24)

            // 时间标签
            HStack {
                Text(formatTime(isDragging ? dragProgress * duration : currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTime(-(duration - (isDragging ? dragProgress * duration : currentTime))))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 滑块轨道

    private var sliderTrack: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 5)

                // 波形预览
                if !waveformSamples.isEmpty {
                    waveformOverlay(width: geo.size.width)
                }

                // 播放进度（发光）
                ZStack(alignment: .trailing) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ColorPalette.primary,
                                    ColorPalette.primary.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * displayProgress), height: 5)

                    // 进度末端光晕
                    Circle()
                        .fill(ColorPalette.primary)
                        .frame(width: 6, height: 6)
                        .blur(radius: 3)
                }

                // 滑块把手
                //
                // 关键：frame 尺寸**保持常量**，放大只走 scaleEffect。
                // 之前写的是 `.frame(width: isDragging ? 22 : 16)`，尺寸一变，
                // ZStack 里左对齐的子视图中心就右移了几个点，再叠加 scaleEffect，
                // 表现就是「拖动时把手一边变大一边往右跑」。
                Circle()
                    .fill(Color.white)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .overlay(
                        Circle()
                            .stroke(ColorPalette.primary, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.25), radius: isDragging ? 6 : 3, x: 0, y: 2)
                    .scaleEffect(isDragging ? 1.35 : 1.0)
                    .offset(x: knobOffset(trackWidth: geo.size.width, progress: displayProgress))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            hapticFeedback.prepare()
                        }
                        let pct = min(max(0, value.location.x / geo.size.width), 1)
                        dragProgress = pct
                        hapticFeedback.impactOccurred(intensity: min(1, max(0, abs(pct - progress) * 2)))
                    }
                    .onEnded { value in
                        let pct = min(max(0, value.location.x / geo.size.width), 1)
                        let targetTime = pct * duration
                        onSeek?(targetTime)
                        isDragging = false
                    }
            )
            // 点击跳转
            .onTapGesture { location in
                let pct = min(max(0, location.x / geo.size.width), 1)
                let targetTime = pct * duration
                withAnimation(.easeOut(duration: 0.2)) {
                    onSeek?(targetTime)
                }
            }
        }
    }

    // MARK: - 波形覆盖层

    private func waveformOverlay(width: CGFloat) -> some View {
        let barCount = min(waveformSamples.count, Int(width / 3))
        let step = max(1, waveformSamples.count / max(barCount, 1))
        let samples = stride(from: 0, to: waveformSamples.count, by: step).map { waveformSamples[$0] }

        return HStack(spacing: 1.5) {
            ForEach(0..<samples.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        CGFloat(i) / CGFloat(samples.count) <= progress
                            ? ColorPalette.primary.opacity(0.3)
                            : Color.secondary.opacity(0.15)
                    )
                    .frame(width: 2, height: max(2, samples[i] * 40))
            }
        }
        .frame(height: 40)
        .allowsHitTesting(false)
    }

    // MARK: - 时间格式化

    private func formatTime(_ time: TimeInterval) -> String {
        let absTime = abs(time)
        let minutes = Int(absTime) / 60
        let seconds = Int(absTime) % 60
        let prefix = time < 0 ? "-" : ""
        return "\(prefix)\(minutes):\(String(format: "%02d", seconds))"
    }
}

/// 更简洁的进度条变体
struct SimpleProgressBar: View {
    let progress: CGFloat
    var height: CGFloat = 3
    var color: Color = ColorPalette.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                    .frame(height: height)

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: height)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        MusicProgressSlider(
            progress: .constant(0.35),
            duration: 232,
            currentTime: 81,
            waveformSamples: WaveformGenerator.generate(count: 120)
        )
        .padding(.horizontal, 32)

        MusicProgressSlider(
            progress: .constant(0.7),
            duration: 195,
            currentTime: 136,
            waveformSamples: []
        )
        .padding(.horizontal, 32)

        SimpleProgressBar(progress: 0.6)
            .frame(height: 3)
            .padding(.horizontal, 32)
    }
    .padding()
}
