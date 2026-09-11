import SwiftUI

/// 全屏播放器界面（增强版：自定义滑块 + 频谱 + 弹性动效）
struct NowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var waveformSamples: [CGFloat] = []
    @State private var coverScale: CGFloat = 1.0

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
                        ProgressSection(
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
        // 强制深色：这是沉浸式深色界面，且能让 .ultraThinMaterial 渲染成深色，
        // 否则浅色模式下白色图标压在浅色毛玻璃上会看不见（返回键曾因此"消失"）
        .environment(\.colorScheme, .dark)
        // 下滑关闭（纵向为主的手势才触发，避免和进度条拖动、列表滚动冲突）
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let dy = value.translation.height
                    let dx = value.translation.width
                    if dy > 70 && abs(dx) < abs(dy) * 0.6 {
                        HapticStyle.light.trigger()
                        dismiss()
                    }
                }
        )
        .onAppear {
            waveformSamples = WaveformGenerator.generate(count: 120)
        }
    }

    // MARK: - 背景层

    @ViewBuilder
    private var backgroundLayer: some View {
        if let image = viewModel.currentSong?.coverImage {
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
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)   // 44pt 是 iOS 最小可点区域
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.9))
            .accessibilityLabel("收起播放页")

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
                // 不要按"有没有歌词"禁用 —— 正是没歌词时才最需要进来用在线搜索
                .foregroundColor(showLyrics ? ColorPalette.primary : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(.white.opacity(0.15), lineWidth: 1)
                )
            }

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
                coverImagePath: viewModel.currentSong?.resolvedCoverArtPath,
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

                    // 图标切换动画（contentTransition(.symbolEffect) 需 iOS 17+，此处用透明度过渡）
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(ColorPalette.primary)
                        .offset(x: isPlaying ? 0 : 2)
                        .transition(.opacity)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(coverScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: coverScale)
        }
    }

    // MARK: - 底部操作卡片

    /// 底部四个操作按钮
    ///
    /// 布局说明：每个按钮都 `.frame(maxWidth: .infinity)` 四等分，
    /// 这样在窄屏（如 iPhone SE / mini）上也不会溢出到屏幕外。
    private var actionCard: some View {
        let song = viewModel.currentSong
        let isFavorite = song.map { viewModel.isFavorite($0) } ?? false

        return ImmersiveCard(cornerRadius: 16) {
            HStack(spacing: 0) {
                ActionButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    label: "喜欢",
                    tint: isFavorite ? ColorPalette.accent : nil
                ) {
                    if let song = song { viewModel.toggleFavorite(song) }
                }

                ActionButton(icon: "list.bullet", label: "队列") {
                    showQueue = true
                }

                ShareLink(item: shareText) {
                    actionLabel(icon: "square.and.arrow.up", label: "分享")
                }

                Menu {
                    if let song = song {
                        Section("歌曲信息") {
                            Text("\(song.title) · \(song.displayArtist)")
                            Text("\(song.format.uppercased()) · \(song.fileSizeFormatted)")
                        }
                    }
                    Section("播放模式") {
                        ForEach(PlayMode.allCases, id: \.rawValue) { mode in
                            Button {
                                while viewModel.playMode != mode { viewModel.togglePlayMode() }
                            } label: {
                                Label(mode.rawValue,
                                      systemImage: viewModel.playMode == mode ? "checkmark" : mode.iconName)
                            }
                        }
                    }
                } label: {
                    actionLabel(icon: "ellipsis.circle", label: "更多")
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
                .environmentObject(viewModel)
        }
    }

    /// 分享文案
    private var shareText: String {
        guard let song = viewModel.currentSong else { return "Rin" }
        return "\(song.title) - \(song.displayArtist)"
    }

    /// 按钮外观（ShareLink / Menu 复用，保证四个按钮视觉一致）
    private func actionLabel(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(.white.opacity(0.85))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - 增强版歌词覆盖层

    // 歌词覆盖层已替换为 EnhancedLyricsView 独立组件
}

// MARK: - 进度区

/// 单独观察 `PlaybackClock` 的子视图
///
/// 只有这一小块需要跟着 10Hz 的播放进度重绘；
/// 若把 clock 挂在 NowPlayingView 上，整页（含滚动内容、频谱、按钮）
/// 都会每秒重绘 10 次，白白掉帧。
private struct ProgressSection: View {
    @ObservedObject var clock = PlaybackClock.shared
    let waveformSamples: [CGFloat]
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        MusicProgressSlider(
            progress: Binding(
                get: { CGFloat(clock.progress) },
                set: { _ in }
            ),
            duration: clock.duration,
            currentTime: clock.currentTime,
            waveformSamples: waveformSamples,
            onSeek: onSeek
        )
    }
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
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(tint ?? .white.opacity(0.85))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            // 四等分，窄屏也不会溢出
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.88))
    }
}

// MARK: - 播放队列面板

struct QueueSheet: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.currentQueue.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 42))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("播放队列是空的")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(viewModel.currentQueue.enumerated()), id: \.element.id) { index, song in
                            HStack(spacing: 12) {
                                if viewModel.currentSong?.id == song.id {
                                    NowPlayingIndicator()
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 15, weight: viewModel.currentSong?.id == song.id ? .semibold : .regular))
                                        .foregroundColor(viewModel.currentSong?.id == song.id ? ColorPalette.primary : .primary)
                                        .lineLimit(1)
                                    Text(song.displayArtist)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(song.durationFormatted)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticStyle.light.trigger()
                                viewModel.play(song: song, from: viewModel.currentQueue)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("播放队列（\(viewModel.currentQueue.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(PlayerViewModel())
}
