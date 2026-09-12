import SwiftUI

/// 全屏播放器界面
///
/// 版式对齐咪咕音乐：
/// - 背景从封面提取主色调铺成渐变（不是模糊封面）
/// - 圆角方形大封面占上半屏
/// - 歌曲信息左对齐 + 标签胶囊
/// - 操作 / 进度 / 控制全部收在屏幕下段，纯白图标无底色
/// - 左右滑动在「播放 / 歌词」两页间切换
struct NowPlayingView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var waveformSamples: [CGFloat] = []

    /// 当前页：0 = 播放器，1 = 歌词
    @State private var page: Int = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景：由封面主色调铺成的渐变（不是模糊封面）
            PlayerBackground(coverPath: viewModel.currentSong?.resolvedCoverArtPath)

            VStack(spacing: 0) {
                topBar

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

                bottomControls
            }
        }
        // 注：这里不要再挂 .animation(value: viewModel.playbackState) ——
        // 那会让所有随播放状态变化的属性（封面、按钮…）统统走动画，
        // 暂停时整个页面会跟着「闪」一下。各控件自己有需要的动画。
        //
        // 强制深色：白色图标与文字全部压在深色封面主色上，浅色模式下会失对比。
        .environment(\.colorScheme, .dark)
        // 注：这里刻意**不加**下滑关闭手势 —— 页面本身是左右翻页的 TabView，
        // 外层再挂 DragGesture 会和系统翻页抢手势（表现就是"滑不动/点了没反应"）。
        // 退出统一走左上角的收起按钮。
        .onAppear {
            waveformSamples = WaveformGenerator.generate(count: 120)
        }
    }

    // MARK: - 顶部：收起 / 页签 / 分享

    private var topBar: some View {
        ZStack {
            // 中间页签（对齐咪咕把页面切换放在顶部正中的做法）
            HStack(spacing: 20) {
                pageTab(title: "播放", index: 0)
                pageTab(title: "歌词", index: 1)
            }

            HStack {
                Button {
                    HapticStyle.light.trigger()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BouncyButtonStyle(scale: 0.88))
                .accessibilityLabel("收起播放页")

                Spacer()

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    /// 顶部页签：选中项白色 + 下划线（咪咕的样式）
    private func pageTab(title: String, index: Int) -> some View {
        let isSelected = page == index

        return Button {
            HapticStyle.selection.trigger()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                page = index
            }
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Capsule()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(width: 22, height: 2.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 下段：操作 / 进度 / 控制

    private var bottomControls: some View {
        VStack(spacing: 14) {
            actionsRow

            VStack(alignment: .leading, spacing: 5) {
                ProgressSection(
                    waveformSamples: waveformSamples,
                    onSeek: { time in viewModel.seek(to: time) }
                )

                ProgressTimeLabel()
            }

            controlsRow
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    // MARK: - 第 0 页：播放器

    /// 上半屏：圆角方形封面 + 左对齐的歌曲信息
    ///
    /// 布局对齐咪咕：封面是「大头」，信息整体**左对齐**并带标签胶囊，
    /// 而不是居中的两三行字 —— 左对齐让页面有版式张力，也更适配长短不一的中文歌名。
    private var playerPage: some View {
        GeometryReader { geo in
            // 取「宽度减两边距」与「高度 86%」中较小者，保证各种屏幕都不顶破
            let side = min(geo.size.width - 56, geo.size.height * 0.86)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                PlayerCoverArt(
                    coverPath: viewModel.currentSong?.resolvedCoverArtPath,
                    size: side
                )
                .frame(maxWidth: .infinity)

                Spacer(minLength: 20)

                songInfoBlock
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 歌曲信息（左对齐 + 标签胶囊 + 喜欢）

    private var songInfoBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                Text(viewModel.currentSong?.title ?? "")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    if let song = viewModel.currentSong {
                        tagChip(song.displayArtist)
                        tagChip(song.format.uppercased())
                        if song.bitrate > 320 {
                            tagChip("无损", highlighted: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            favoriteButton
                .padding(.top, 2)
        }
    }

    /// 标签胶囊
    private func tagChip(_ text: String, highlighted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(highlighted ? ColorPalette.amber : .white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    highlighted
                        ? ColorPalette.amber.opacity(0.18)
                        : Color.white.opacity(0.14)
                )
            )
    }

    private var favoriteButton: some View {
        let isFavorite = viewModel.currentSong.map { viewModel.isFavorite($0) } ?? false

        return Button {
            HapticStyle.light.trigger()
            if let song = viewModel.currentSong {
                viewModel.toggleFavorite(song)
            }
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundColor(isFavorite ? ColorPalette.coral : .white.opacity(0.8))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.86))
        .accessibilityLabel(isFavorite ? "取消喜欢" : "喜欢")
    }

    // MARK: - 第 1 页：歌词

    private var lyricsPage: some View {
        EnhancedLyricsView(isPresented: $showLyrics, isEmbedded: true)
            .environmentObject(viewModel)
    }

    // MARK: - 页码指示点

    // MARK: - 背景层

    @ViewBuilder

    // MARK: - 顶部栏

    // MARK: - 增强版专辑封面

    // 封面已换成玩家页的 PlayerCoverArt（圆角方形），
    // 旧的 VinylRecordView（黑胶圆形 + 持续旋转）不再使用。
    // 旋转有个副作用：暂停时为了让唱片「停稳」会把角度归到 360 的整数倍，
    // 视觉上就是猛地转一下 —— 这也是暂停时"闪烁"的来源之一。

    // MARK: - 毛玻璃歌曲信息卡片

    // MARK: - 增强版播放控制

    /// 播放控制（整体缩小，收在屏幕下段）
    private var controlsRow: some View {
        HStack(spacing: 0) {
            // 播放模式
            ControlButton(
                systemName: viewModel.playMode.iconName,
                size: 15,
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
                size: 22,
                action: {
                    HapticStyle.medium.trigger()
                    viewModel.playPrevious()
                }
            )

            Spacer()

            playPauseButton

            Spacer()

            // 下一首
            ControlButton(
                systemName: "forward.fill",
                size: 22,
                action: {
                    HapticStyle.medium.trigger()
                    viewModel.playNext()
                }
            )

            Spacer()

            // 音量
            ControlButton(
                systemName: "speaker.wave.2.fill",
                size: 15,
                action: {
                    HapticStyle.light.trigger()
                }
            )
        }
    }

    /// 中心播放/暂停按钮（增强版动画）
    /// 播放 / 暂停
    ///
    /// 刻意保持「裸图标」：不加圆形底、不加主题色、不加呼吸光晕。
    /// 网易云、Apple Music 的播放页也是如此 —— 沉浸式背景上再叠一个实心圆按钮
    /// 会把画面切碎，也显得廉价。
    private var playPauseButton: some View {
        let isPlaying = viewModel.playbackState == .playing

        return Button(action: {
            HapticStyle.medium.trigger()
            viewModel.togglePlayPause()
        }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                // 「播放」三角形视觉重心偏左，右移一点点看起来才居中
                .offset(x: isPlaying ? 0 : 2)
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.88))
    }

    // MARK: - 底部操作卡片

    /// 底部四个操作按钮
    ///
    /// 布局说明：每个按钮都 `.frame(maxWidth: .infinity)` 四等分，
    /// 这样在窄屏（如 iPhone SE / mini）上也不会溢出到屏幕外。
    /// 操作行：一排纯白图标（对齐咪咕 —— 无底色、无文字标签）
    private var actionsRow: some View {
        let song = viewModel.currentSong

        return HStack(spacing: 0) {
            // 歌词
            ActionButton(icon: "text.bubble", label: nil) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    page = 1
                }
            }

            // 播放队列
            ActionButton(icon: "list.bullet", label: nil) {
                showQueue = true
            }

            // 播放模式
            ActionButton(
                icon: viewModel.playMode.iconName,
                label: nil,
                tint: viewModel.playMode == .sequential ? nil : ColorPalette.amber
            ) {
                viewModel.togglePlayMode()
            }

            ShareLink(item: shareText) {
                actionLabel(icon: "square.and.arrow.up", label: nil)
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
                actionLabel(icon: "ellipsis", label: nil)
            }
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

    /// 按钮外观（ShareLink / Menu 复用，保证一排图标视觉一致）
    private func actionLabel(icon: String, label: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.9))

            if let label = label {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
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
            // 时间放到进度条下方（咪咕的排版），这里不再左右各放一个
            showTimeLabels: false,
            onSeek: onSeek
        )
    }
}

// MARK: - 进度时间

/// 「00:42 / 03:59」——单独观察时钟，避免整个播放页跟着 10Hz 重绘
private struct ProgressTimeLabel: View {
    @ObservedObject private var clock = PlaybackClock.shared

    var body: some View {
        Text("\(PlaybackClock.format(clock.currentTime)) / \(PlaybackClock.format(clock.duration))")
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
    }
}

// MARK: - 播放页封面（圆角方形）

/// 大封面：圆角方形，占据上半屏
///
/// 刻意**不做旋转**。唱片式旋转除了好看没有任何功能意义，
/// 却要持续重绘一整块带阴影的大图层；而且暂停时为了让唱片「停稳」
/// 必须把角度归到 360 的整数倍，视觉上就是猛地转一下 ——
/// 这正是暂停时"闪一下"的来源。
struct PlayerCoverArt: View {
    let coverPath: String?
    let size: CGFloat

    private var cornerRadius: CGFloat { size * 0.06 }

    var body: some View {
        Group {
            if let path = coverPath, let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ColorPalette.gradientPrimary
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.white.opacity(0.55))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
    }
}

// MARK: - 控制按钮子组件

/// 播放控制栏里的次要按钮（播放模式 / 上一首 / 下一首 / 音量）
///
/// 保持纯白裸图标：不加底、不用主题色，靠图标本身的形态区分状态
/// （网易云、Apple Music 都是这样，沉浸背景上叠彩色按钮会显得杂乱）
struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(isActive ? .white : .white.opacity(0.72))
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.84))
    }
}

struct ActionButton: View {
    let icon: String
    /// 传 nil 则只画图标（咪咕的操作行就没有文字标签）
    var label: String?
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticStyle.light.trigger()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(tint ?? .white.opacity(0.9))

                if let label = label {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            // 等分，窄屏也不会溢出
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.86))
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
