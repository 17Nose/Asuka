import SwiftUI

/// 音频波形可视化组件
struct WaveformView: View {
    let samples: [CGFloat]     // 归一化采样数据 (0...1)
    let progress: CGFloat      // 播放进度 (0...1)
    var playedColor: Color = ColorPalette.primary
    var unplayedColor: Color = Color.secondary.opacity(0.3)
    var barWidth: CGFloat = 2
    var barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: barSpacing) {
                ForEach(0..<samples.count, id: \.self) { index in
                    let sample = samples[index]
                    let position = CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                    let isPlayed = position <= progress

                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isPlayed ? playedColor : unplayedColor)
                        .frame(
                            width: barWidth,
                            height: max(2, sample * geo.size.height)
                        )
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
        }
    }
}

/// 实时频谱（装饰性，非真实音频分析）
///
/// 旧实现用 `Timer` 每 0.15 秒随机重排 30 根柱子，每根都挂 spring 动画 ——
/// 播放时持续产生大量动画事务。改用 `TimelineView` 按固定节拍驱动，
/// 高度由确定性函数算出，开销大幅下降。
struct LiveSpectrumView: View {
    let isPlaying: Bool
    var barCount: Int = 30
    var color: Color = ColorPalette.primary

    private let tickInterval: TimeInterval = 0.2

    var body: some View {
        if isPlaying {
            TimelineView(.periodic(from: .now, by: tickInterval)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / tickInterval)
                GeometryReader { geo in
                    let width = max(1.5, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
                    HStack(spacing: 2) {
                        ForEach(0..<barCount, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(color)
                                .frame(
                                    width: width,
                                    height: max(3, Self.height(tick: tick, index: index) * geo.size.height)
                                )
                        }
                    }
                }
            }
        }
    }

    /// 确定性的伪随机高度（用正弦叠加，避免 random 导致每帧都不同）
    private static func height(tick: Int, index: Int) -> CGFloat {
        let t = Double(tick), i = Double(index)
        let value = 0.5
            + sin(t * 0.9 + i * 0.7) * 0.28
            + sin(t * 1.7 + i * 0.3) * 0.14
        return CGFloat(min(max(value, 0.08), 1.0))
    }
}

/// 生成模拟波形数据
enum WaveformGenerator {
    static func generate(count: Int = 100) -> [CGFloat] {
        var samples: [CGFloat] = []
        let phase: CGFloat = 0

        for i in 0..<count {
            // 多频叠加模拟真实波形
            let base = sin(CGFloat(i) * 0.1 + phase) * 0.5 + 0.5
            let mid = sin(CGFloat(i) * 0.3 + phase * 1.7) * 0.3
            let high = sin(CGFloat(i) * 0.7 + phase * 2.3) * 0.15
            let noise = CGFloat.random(in: -0.05...0.05)

            var sample = base * 0.6 + mid * 0.25 + high * 0.1 + noise
            sample = min(max(sample, 0.05), 0.95)
            samples.append(sample)
        }

        return samples
    }

    /// 从渐变生成（更平滑）
    static func smooth(count: Int = 100) -> [CGFloat] {
        (0..<count).map { i in
            let x = CGFloat(i) / CGFloat(count)
            // 高斯型波形（中间高，两端低）
            let gaussian = exp(-pow((x - 0.5) * 3, 2))
            let variation = sin(x * .pi * 3) * 0.2
            return max(0.05, min(0.95, gaussian + variation))
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        WaveformView(
            samples: WaveformGenerator.generate(count: 80),
            progress: 0.4
        )
        .frame(height: 40)
        .padding()

        LiveSpectrumView(isPlaying: true)
            .frame(height: 40)
            .padding()
    }
    .background(Color(hex: "1A1A2E"))
}
