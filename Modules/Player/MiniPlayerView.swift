import SwiftUI

/// 底部迷你播放条（增强版：弹性动画 + 微交互 + 频谱条）
struct MiniPlayerView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @State private var showNowPlaying = false
    @State private var isPressed = false
    @State private var miniProgress: CGFloat = 0
    @State private var coverRotation: Double = 0

    var body: some View {
        if let song = viewModel.currentSong {
            VStack(spacing: 0) {
                // 流光进度条
                progressLine

                HStack(spacing: 12) {
                    // 旋转封面
                    rotatingCover(for: song)

                    // 歌曲信息
                    songInfo(for: song)
                        .onTapGesture { expandPlayer() }

                    Spacer()

                    // 播放控制
                    HStack(spacing: 16) {
                        Button(action: {
                            HapticStyle.medium.trigger()
                            viewModel.togglePlayPause()
                        }) {
                            Image(systemName: viewModel.playbackState == .playing
                                  ? "pause.fill"
                                  : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(ColorPalette.primary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(BouncyButtonStyle(scale: 0.85))

                        Button(action: {
                            HapticStyle.light.trigger()
                            viewModel.playNext()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(BouncyButtonStyle(scale: 0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    // 毛玻璃背景
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: .black.opacity(0.1),
                    radius: 8, x: 0, y: -2
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.height < -20 {
                            isPressed = true
                        }
                    }
                    .onEnded { value in
                        isPressed = false
                        if value.translation.height < -40 {
                            expandPlayer()
                        }
                    }
            )
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingView()
                    .environmentObject(viewModel)
            }
        }
    }

    // MARK: - 流光进度条

    private var progressLine: some View {
        MiniProgressLine(isPlaying: viewModel.playbackState == .playing)
    }

    // MARK: - 旋转封面

    private func rotatingCover(for song: Song) -> some View {
        Group {
            if let path = song.coverArtPath,
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(ColorPalette.gradientPrimary)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 12))
                    )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        )
        .rotationEffect(.degrees(coverRotation))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .animation(
            viewModel.playbackState == .playing
                ? .linear(duration: 8).repeatForever(autoreverses: false)
                : .easeOut(duration: 0.4),
            value: viewModel.playbackState
        )
        .onChange(of: viewModel.playbackState) { state in
            if state == .playing {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    coverRotation += 360
                }
            }
        }
        .onTapGesture { expandPlayer() }
    }

    // MARK: - 歌曲信息

    private func songInfo(for song: Song) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // 歌名（播放时滚动）
            MarqueeText(
                text: song.title,
                font: .systemFont(ofSize: 14, weight: .semibold),
                isScrolling: viewModel.playbackState == .playing
            )
            .frame(height: 18)

            HStack(spacing: 4) {
                Text(song.displayArtist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !song.album.isEmpty {
                    Text("· \(song.album)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            }

            // 播放指示条
            if viewModel.playbackState == .playing {
                EqualizerBars()
            }
        }
    }

    // MARK: - 展开全屏播放器

    private func expandPlayer() {
        HapticStyle.medium.trigger()
        showNowPlaying = true
    }
}

// MARK: - 迷你进度条

/// 单独观察 `PlaybackClock` 的子视图
///
/// 只有这条 2pt 的线需要跟着 10Hz 播放进度重绘，
/// 把它从 MiniPlayerView 里拆出来，避免整条迷你播放条每秒重绘 10 次。
private struct MiniProgressLine: View {
    @ObservedObject var clock = PlaybackClock.shared
    let isPlaying: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 2)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [ColorPalette.primary, ColorPalette.primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * clock.progress, height: 2)

                if isPlaying {
                    Circle()
                        .fill(ColorPalette.primary)
                        .frame(width: 4, height: 4)
                        .blur(radius: 2)
                        .offset(x: geo.size.width * clock.progress - 2)
                }
            }
            .animation(.linear(duration: 0.1), value: clock.progress)
        }
        .frame(height: 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - 播放指示条

/// 极轻量的播放指示（三根跳动的小竖条）
///
/// ⚠️ 旧实现用的是：
/// ```
/// .animation(.easeInOut(...).repeatForever(), value: UUID())
/// ```
/// `UUID()` 每次渲染都会生成新值，SwiftUI 便认为「动画目标每帧都在变」，
/// 于是每帧重启一次 `repeatForever` 动画 —— 这是播放时严重掉帧的主要元凶之一。
/// 改成 `TimelineView` 按固定节拍驱动，只在需要时重绘这一小块。
struct EqualizerBars: View {
    private let patterns: [[CGFloat]] = [
        [6, 11, 8],
        [11, 7, 12],
        [8, 12, 6],
        [12, 8, 10],
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let index = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % patterns.count
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ColorPalette.primary.opacity(0.7))
                        .frame(width: 2.5, height: patterns[index][i])
                }
            }
            .frame(height: 12, alignment: .center)
            .animation(.easeInOut(duration: 0.4), value: index)
        }
    }
}

// MARK: - 跑马灯文字（SwiftUI 版本）

struct MarqueeText: View {
    let text: String
    let font: UIFont
    let isScrolling: Bool

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width

            Text(text)
                .font(Font(font))
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textWidth = textGeo.size.width
                        }
                    }
                )
                .offset(x: isScrolling ? offset : 0)
                .animation(
                    isScrolling && textWidth > containerWidth
                        ? .linear(duration: Double(textWidth / 30))
                            .repeatForever(autoreverses: false)
                        : .default,
                    value: isScrolling
                )
                .onChange(of: isScrolling) { scrolling in
                    if scrolling && textWidth > containerWidth {
                        offset = -(textWidth + 20)
                    } else {
                        offset = 0
                    }
                }
        }
        .clipped()
    }
}

#Preview {
    MiniPlayerView()
        .environmentObject(PlayerViewModel())
}
