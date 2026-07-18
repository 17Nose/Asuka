import SwiftUI

/// 全屏播放器界面（增强版：自定义滑块 + 频谱 + 弹性动效）
struct NowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    @State private var showShareSheet = false
    @State private var waveformSamples: [CGFloat] = []
    @State private var coverScale: CGFloat = 1.0
    @State private var bgRotation: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // 动态背景层
            backgroundLayer

            // 主内容
            VStack(spacing: 0) {
                // 顶部栏
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // 可滚动内容
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        // 专辑封面区域（增强版）
                        enhancedAlbumArtSection
                            .padding(.top, 12)

                        // 歌曲信息（毛玻璃卡片）
                        songInfoCard
                            .padding(.horizontal, 32)

                        // 自定义进度条（带波形）
                        MusicProgressSlider(
                            progress: Binding(
                                get: { viewModel.progress },
                                set: { _ in }
                            ),
                            duration: viewModel.duration,
                            currentTime: viewModel.currentTime,
                            waveformSamples: waveformSamples,
                            onSeek: { time in viewModel.seek(to: time) }
                        )
                        .padding(.horizontal, 32)

                        // 播放控制
                        enhancedControlsSection
                            .padding(.horizontal, 32)

                        // 底部操作栏（毛玻璃卡片）
                        actionCard
                            .padding(.horizontal, 32)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 20)
                }

                // 实时频谱条
                if viewModel.playbackState == .playing {
                    LiveSpectrumView(isPlaying: true)
                        .frame(height: 32)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            // 歌词覆盖层（增强版：逐字高亮 + 翻译 + 在线搜索）
            if showLyrics {
                EnhancedLyricsView(isPresented: $showLyrics)
                    .environmentObject(viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showLyrics)
        .animation(.easeInOut(duration: 0.4), value: viewModel.playbackState)
        .onAppear {
            // 生成模拟波形数据
            waveformSamples = WaveformGenerator.generate(count: 120)
            // 慢速背景旋转
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                bgRotation = 360
            }
        }
    }

    // MARK: - 背景层

    @ViewBuilder
    private var backgroundLayer: some View {
        if let path = viewModel.currentSong?.coverArtPath,
           let image = UIImage(contentsOfFile: path) {
            ZStack {
                // 放大的模糊封面
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 50)
                    .scaleEffect(1.3)

                // 渐变遮罩
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 动态光晕
                Circle()
                    .fill(ColorPalette.primary.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(y: -100)
                    .floatingAnimation(isActive: true, amplitude: 20)
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                ColorPalette.gradientPrimary
                    .ignoresSafeArea()

                // 装饰性光晕
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: -200)
                    .floatingAnimation(isActive: true, amplitude: 30)

                Circle()
                    .fill(ColorPalette.secondary.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -80, y: 100)
                    .floatingAnimation(isActive: true, amplitude: -20)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - 顶部栏

    private var headerBar: some View {
        HStack {
            // 收起按钮（弹性交互）
            Button(action: {
                HapticStyle.light.trigger()
                dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.9))

            Spacer()

            // 歌词切换按钮
            Button(action: {
                HapticStyle.medium.trigger()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showLyrics.toggle()
                }
            }) {
                Label(
                    showLyrics ? "关闭歌词" : "歌词",
                    systemImage: showLyrics ? "text.bubble.fill" : "text.bubble"
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    viewModel.lyricLines.isEmpty
                        ? .white.opacity(0.3)
                        : (showLyrics ? ColorPalette.primary : .white.opacity(0.8))
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .disabled(viewModel.lyricLines.isEmpty)

            Spacer()

            // 更多菜单
            Menu {
                Section("播放模式") {
                    ForEach(PlayMode.allCases, id: \.rawValue) { mode in
                        Button(action: {
                            while viewModel.playMode != mode {
                                viewModel.togglePlayMode()
                            }
                        }) {
                            Label(
                                mode.rawValue,
                                systemImage: viewModel.playMode == mode
                                    ? "checkmark"
                                    : mode.iconName
                            )
                        }
                    }
                }

                Section("音质") {
                    Button(action: {}) {
                        Label("均衡器", systemImage: "slider.horizontal.3")
                    }
                    Button(action: {}) {
                        Label("睡眠定时", systemImage: "moon.zzz")
                    }
                }

                Section("信息") {
                    if let song = viewModel.currentSong {
                        Button(action: {}) {
                            Label("文件信息: \(song.format.uppercased()) \(song.fileSizeFormatted)",
                                  systemImage: "doc.text")
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 增强版专辑封面

    private var enhancedAlbumArtSection: some View {
        VStack(spacing: 0) {
            VinylRecordView(
                coverImagePath: viewModel.currentSong?.coverArtPath,
                isPlaying: viewModel.playbackState == .playing,
                size: 280
            )
            .scaleEffect(coverScale)
            .shadow(
                color: viewModel.playbackState == .playing
                    ? ColorPalette.primary.opacity(0.3)
                    : .black.opacity(0.2),
                radius: viewModel.playbackState == .playing ? 30 : 15,
                x: 0,
                y: 10
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: coverScale)
            .onChange(of: viewModel.playbackState) { state in
                if state == .playing {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        coverScale = 1.05
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                            coverScale = 1.0
                        }
                    }
                }
            }
        }
    }

    // MARK: - 毛玻璃歌曲信息卡片

    private var songInfoCard: some View {
        ImmersiveCard(cornerRadius: 20) {
            VStack(spacing: 6) {
                if let song = viewModel.currentSong {
                    // 歌名（滚动跑马灯如果太长）
                    Text(song.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .id(song.id)
                        .transition(.opacity.combined(with: .move(edge: .leading)))

                    // 歌手
                    Text(song.displayArtist)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)

                    // 专辑 + 音质标签
                    HStack(spacing: 8) {
                        if !song.album.isEmpty {
                            Text(song.album)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }

                        // 格式标签
                        Text(song.format.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)

                        // 音质标签
                        if song.bitrate > 320 {
                            Text("Hi-Res")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 增强版播放控制

    private var enhancedControlsSection: some View {
        HStack(spacing: 0) {
            // 播放模式
            ControlButton(
                systemName: viewModel.playMode.iconName,
                size: 18,
                isActive: viewModel.playMode != .sequential,
                action: {
                    HapticStyle.selection.trigger()
                    viewModel.togglePlayMode()
                }
            )

            Spacer()

            // 上一首
            ControlButton(
                systemName: "backward.fill",
                size: 26,
                action: {
                    HapticStyle.medium.trigger()
                    viewModel.playPrevious()
                }
            )

            Spacer()

            // 中心播放/暂停（弹性 + 光晕）
            playPauseButton

            Spacer()

            // 下一首
            ControlButton(
                systemName: "forward.fill",
                size: 26,
                action: {
                    HapticStyle.medium.trigger()
                    viewModel.playNext()
                }
            )

            Spacer()

            // 音量/均衡器
            ControlButton(
                systemName: "speaker.wave.2.fill",
                size: 18,
                action: {
                    HapticStyle.light.trigger()
                }
            )
        }
        .padding(.vertical, 8)
    }

    /// 中心播放/暂停按钮（增强版动画）
    private var playPauseButton: some View {
        let isPlaying = viewModel.playbackState == .playing

        return ZStack {
            // 外层光晕（播放时呼吸）
            if isPlaying {
                Circle()
                    .fill(ColorPalette.primary.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .scaleEffect(coverScale == 1.05 ? 1.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: coverScale
                    )
            }

            // 按钮主体
            Button(action: {
                HapticStyle.heavy.trigger()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    coverScale = 0.85
                }
                viewModel.togglePlayPause()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                        coverScale = 1.0
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 74, height: 74)
                        .shadow(
                            color: isPlaying
                                ? ColorPalette.primary.opacity(0.5)
                                : Color.black.opacity(0.15),
                            radius: isPlaying ? 16 : 8,
                            x: 0,
                            y: 4
                        )

                    // 图标切换动画
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(ColorPalette.primary)
                        .offset(x: isPlaying ? 0 : 2)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(coverScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: coverScale)
        }
    }

    // MARK: - 底部操作卡片

    private var actionCard: some View {
        ImmersiveCard(cornerRadius: 16) {
            HStack(spacing: 0) {
                Spacer()

                ActionButton(icon: "heart", label: "喜欢") {
                    HapticStyle.light.trigger()
                }

                Spacer()

                ActionButton(icon: "list.bullet", label: "队列") {
                    HapticStyle.light.trigger()
                }

                Spacer()

                ActionButton(icon: "text.line.first.and.arrowtriangle.forward", label: "分享") {
                    HapticStyle.light.trigger()
                    showShareSheet = true
                }

                Spacer()

                ActionButton(icon: "ellipsis.circle", label: "更多") {
                    HapticStyle.light.trigger()
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 增强版歌词覆盖层

    // 歌词覆盖层已替换为 EnhancedLyricsView 独立组件
}

// MARK: - 控制按钮子组件

struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    var isActive: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    isPressed = false
                }
            }
        }) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(isActive ? ColorPalette.primary : .white.opacity(0.8))
                .frame(width: 44, height: 44)
        }
        .scaleEffect(isPressed ? 0.8 : 1.0)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .buttonStyle(.plain)
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(PlayerViewModel())
}
