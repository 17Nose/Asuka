import SwiftUI

/// 全屏播放器界面（增强版：自定义滑块 + 频谱 + 弹性动效）
struct NowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var waveformSamples: [CGFloat] = []
    @State private var coverScale: CGFloat = 1.0

    /// 当前页：0 = 播放器，1 = 歌词
    @State private var page: Int = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // 动态背景层
            backgroundLayer

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // 左右滑动切页：左=播放器，右=歌词
                //
                // 用 TabView 的 page 模式而不是自己写手势：
                // 系统实现天然处理了与内部滚动、进度条拖动的手势竞争。
                TabView(selection: $page) {
                    playerPage
                        .tag(0)
                    lyricsPage
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                // 注：这里原本有一条「实时频谱」动画。它不是真实音频分析，
                // 而是每 0.2 秒重排 26 根柱子，持续占用 GPU 且没有任何信息量，
                // 播放页的卡顿主要来自它 —— 已移除。

                // 以下为两页共用：进度、控制、操作
                ProgressSection(
                    waveformSamples: waveformSamples,
                    onSeek: { time in viewModel.seek(to: time) }
                )
                .padding(.horizontal, 32)
                .padding(.top, 6)

                enhancedControlsSection
                    .padding(.horizontal, 32)
                    .padding(.top, 10)

                actionCard
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.playbackState)
        // 强制深色：这是沉浸式深色界面，且能让 .ultraThinMaterial 渲染成深色，
        // 否则浅色模式下白色图标压在浅色毛玻璃上会看不见（返回键曾因此"消失"）
        .environment(\.colorScheme, .dark)
        // 注：这里刻意**不加**下滑关闭手势 —— 页面本身是左右翻页的 TabView，
        // 外层再挂 DragGesture 会和系统翻页抢手势（表现就是"滑不动/点了没反应"）。
        // 退出统一走左上角的收起按钮。
        .onAppear {
            waveformSamples = WaveformGenerator.generate(count: 120)
        }
    }

    // MARK: - 第 0 页：播放器

    private var playerPage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                enhancedAlbumArtSection
                    .padding(.top, 4)

                songInfoCard
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - 第 1 页：歌词

    private var lyricsPage: some View {
        EnhancedLyricsView(isPresented: $showLyrics, isEmbedded: true)
            .environmentObject(viewModel)
    }

    // MARK: - 页码指示点

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.white.opacity(0.9) : Color.white.opacity(0.25))
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: page)
        .accessibilityHidden(true)
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

                // 装饰性光晕（静态）
                //
                // 这里原来是 floatingAnimation 持续飘动的大面积模糊圆，
                // 意味着每一帧都要重新合成一块 350pt、blur 80 的图层 ——
                // 纯粹装饰却极其吃 GPU。改成静止后视觉几乎无差别，帧率明显改善。
                Circle()
                    .fill(ColorPalette.primary.opacity(0.08))
                    .frame(width: 350, height: 350)
                    .blur(radius: 80)
                    .offset(y: -100)
            }
            .ignoresSafeArea()
        } else {
            ZStack {
                ColorPalette.gradientPrimary
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 100, y: -200)

                Circle()
                    .fill(ColorPalette.secondary.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -80, y: 100)
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

            // 中间抓手：既是「可下拉关闭」的视觉提示，
            // 也让这一整条顶部栏成为可拖拽区域
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 40, height: 5)

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
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        // 下拉关闭只挂在顶部栏这一条 ——
        // 页面中间是左右翻页的 TabView，在那里挂拖拽手势会抢掉系统翻页
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dy = value.translation.height
                    let dx = value.translation.width
                    if dy > 55 && abs(dx) < abs(dy) {
                        HapticStyle.light.trigger()
                        dismiss()
                    }
                }
        )
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

    /// 歌曲信息（歌名 / 歌手 / 专辑）
    ///
    /// 刻意**不加**卡片背景 —— 播放页整块都是沉浸式背景，
    /// 再叠一层纯色/毛玻璃会显得很脏（参考网易云、Apple Music 都是纯文字压在背景上）。
    private var songInfoCard: some View {
        VStack(spacing: 6) {
            if let song = viewModel.currentSong {
                Text(song.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .id(song.id)
                    .transition(.opacity.combined(with: .move(edge: .leading)))

                Text(song.displayArtist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if !song.album.isEmpty {
                    Text(song.album)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
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

        return Group {
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
            .padding(.vertical, 8)
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
