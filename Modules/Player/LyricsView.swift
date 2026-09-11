import SwiftUI

/// 增强版歌词视图（拖拽定位 + 逐字高亮 + 翻译行 + 在线搜索）
struct EnhancedLyricsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool

    /// 作为播放页的其中一页嵌入时为 true：
    /// 隐去自己的背景与关闭按钮，也不留全屏模式的顶部留白
    var isEmbedded: Bool = false

    // 注：这里**不**观察 PlaybackClock。歌词列表只需要在「换行」时重绘，
    // 逐字高亮交给 KaraokeLyricLine 单独处理，否则整个列表每秒重绘 10 次。
    @State private var showSearchSheet = false

    var body: some View {
        ZStack {
            if !isEmbedded {
                backgroundLayer
            }

            VStack(spacing: 0) {
                if isEmbedded {
                    embeddedToolbar
                } else {
                    lyricsHeaderBar
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                    Spacer()
                }

                if viewModel.isSearchingLyrics {
                    loadingState
                } else if viewModel.displayLyrics.isEmpty {
                    emptyLyricsState
                } else {
                    lyricsScrollContent
                }

                if !isEmbedded {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showSearchSheet) {
            LyricsSearchSheet(
                viewModel: viewModel,
                isPresented: $showSearchSheet
            )
        }
    }

    // MARK: - 嵌入模式的紧凑工具栏

    /// 嵌入播放页时用它代替全屏顶部栏（保留在线搜索入口）
    private var embeddedToolbar: some View {
        HStack(spacing: 12) {
            if !viewModel.displayLyrics.isEmpty {
                Text(viewModel.lyricsSourceLabel)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            Button {
                HapticStyle.light.trigger()
                showSearchSheet = true
            } label: {
                Label("在线搜索", systemImage: "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(BouncyButtonStyle(scale: 0.9))
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - 背景层

    private var backgroundLayer: some View {
        ZStack {
            // 深色磨砂
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()

            // 装饰性光晕
            Circle()
                .fill(ColorPalette.primary.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(y: -150)
        }
    }

    // MARK: - 顶部控制栏

    private var lyricsHeaderBar: some View {
        HStack {
            // 关闭按钮
            Button(action: {
                HapticStyle.light.trigger()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // 标题
            VStack(spacing: 4) {
                Text("歌词")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                if let song = viewModel.currentSong {
                    Text("\(song.title) - \(song.displayArtist)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            // 搜索在线歌词
            Button(action: {
                HapticStyle.medium.trigger()
                showSearchSheet = true
            }) {
                Image(systemName: "globe")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text("正在搜索歌词...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - 空歌词状态

    private var emptyLyricsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.35))

            VStack(spacing: 8) {
                Text("暂无歌词")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text("在音乐文件中未找到内嵌歌词")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 10) {
                Text("你可以：")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))

                HStack(spacing: 16) {
                    emptyActionButton(
                        icon: "doc.badge.plus",
                        text: "同目录放 .lrc 文件",
                        action: {}
                    )

                    emptyActionButton(
                        icon: "globe",
                        text: "在线搜索歌词",
                        action: {
                            HapticStyle.medium.trigger()
                            showSearchSheet = true
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
    }

    private func emptyActionButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(ColorPalette.primary)
                    .frame(width: 50, height: 50)
                    .background(ColorPalette.primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(text)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.92))
    }

    // MARK: - 歌词滚动内容

    /// 歌词滚动区
    ///
    /// 滚动由 `ScrollViewReader` 驱动：当前行变化时把它滚到容器正中。
    /// 上下各留「半个容器高」的空白，这样第一句和最后一句也能居中对齐。
    private var lyricsScrollContent: some View {
        GeometryReader { geo in
            let halfHeight = max(80, geo.size.height / 2 - 36)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: halfHeight)

                        ForEach(viewModel.displayLyrics) { line in
                            if !line.text.isEmpty {
                                lyricRow(line)
                                    .id(line.index)
                            }
                        }

                        Color.clear.frame(height: halfHeight)
                    }
                }
                .mask(lyricsGradientMask)
                .onChange(of: viewModel.currentLyricIndex) { newIndex in
                    scrollToCurrent(proxy: proxy, index: newIndex, animated: true)
                }
                .onAppear {
                    scrollToCurrent(proxy: proxy, index: viewModel.currentLyricIndex, animated: false)
                }
            }
        }
    }

    /// 把当前行滚到正中
    private func scrollToCurrent(proxy: ScrollViewProxy, index: Int?, animated: Bool) {
        guard let index = index else { return }
        let target = LRCParser.displayIndex(ofLyricIndex: index)

        // 行可能还没被 LazyVStack 创建出来，放到下一轮 runloop 再滚
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    // MARK: - 单行歌词

    @ViewBuilder
    private func lyricRow(_ line: DisplayLyricLine) -> some View {
        let isCurrent = line.isCurrent
        let currentDisplayIndex = (viewModel.currentLyricIndex ?? -1) + 5
        let distance = abs(line.index - currentDisplayIndex)
        let accent = ColorPalette.primary

        VStack(spacing: 3) {
            if isCurrent, !line.words.isEmpty {
                // 当前行带逐字时间轴 → 交给独立子视图做卡拉OK高亮
                KaraokeLyricLine(words: line.words, lineStartTime: lineStartTime)
            } else {
                Text(line.text)
                    .font(.system(
                        size: isCurrent ? 22 : 16,
                        weight: isCurrent ? .bold : .regular,
                        design: .rounded
                    ))
                    .foregroundColor(lyricColor(distance: distance, isCurrent: isCurrent))
                    .shadow(color: isCurrent ? .black.opacity(0.45) : .clear, radius: 8)
            }

            if let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(isCurrent ? .white.opacity(0.55) : .white.opacity(0.2))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        // 当前行略微放大 —— 行高固定，靠 scale 不会挤动其他行
        .scaleEffect(isCurrent ? 1.04 : 0.97, anchor: .center)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isCurrent)
        .contentShape(Rectangle())
        .onTapGesture {
            seekToLyric(at: line.index - 5)
        }
    }

    /// 当前行的起始时间（逐字高亮需要）
    private var lineStartTime: TimeInterval {
        guard let index = viewModel.currentLyricIndex,
              index >= 0, index < viewModel.lyricLines.count else { return 0 }
        return viewModel.lyricLines[index].time
    }

    /// 点击歌词跳转到对应时间
    private func seekToLyric(at index: Int) {
        guard index >= 0, index < viewModel.lyricLines.count else { return }
        HapticStyle.selection.trigger()
        viewModel.seek(to: viewModel.lyricLines[index].time)
    }

    /// 距离当前行越远越淡（Apple Music / 网易云的观感）
    private func lyricColor(distance: Int, isCurrent: Bool) -> Color {
        if isCurrent { return .white }
        switch distance {
        case 1:  return .white.opacity(0.5)
        case 2:  return .white.opacity(0.34)
        case 3:  return .white.opacity(0.22)
        default: return .white.opacity(0.14)
        }
    }

    // MARK: - 渐变遮罩

    private var lyricsGradientMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            Color.white
            LinearGradient(
                colors: [.white, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
        }
    }

}

// MARK: - 卡拉OK高亮行

/// 当前歌词行：按逐字时间轴做「已唱/未唱」的高亮
///
/// 单独拆成一个视图，是因为它必须跟着播放进度刷新（10Hz）。
/// 如果让整个歌词列表都观察时钟，每秒会重建上百行文本 —— 直接卡死。
/// 这里只有当前这一行会以 10Hz 重绘。
private struct KaraokeLyricLine: View {
    @ObservedObject private var clock = PlaybackClock.shared

    let words: [WordTiming]
    let lineStartTime: TimeInterval

    var body: some View {
        Text(attributed)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.45), radius: 8)
    }

    private var attributed: AttributedString {
        let elapsed = clock.currentTime - lineStartTime
        let sungIndex = LRCParser.findCurrentWordIndex(words: words, lineElapsed: elapsed)

        var result = AttributedString()
        for (index, word) in words.enumerated() {
            var part = AttributedString(word.text)
            let isSung = sungIndex.map { index <= $0 } ?? false
            // 显式写 UIColor，避免 AttributedString 在 SwiftUI / UIKit 两个
            // attribute scope 之间产生歧义
            part.foregroundColor = isSung
                ? UIColor.white
                : UIColor.white.withAlphaComponent(0.42)
            result += part
        }
        return result
    }
}

// MARK: - 歌词搜索弹窗

struct LyricsSearchSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool

    @State private var searchQuery: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索歌词...", text: $searchQuery)
                        .onSubmit { performSearch() }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                .padding()

                // 搜索结果
                if viewModel.lyricSearchResults.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.4))

                        if viewModel.isSearchingLyrics {
                            ProgressView("搜索中...")
                        } else {
                            Text(searchQuery.isEmpty
                                 ? "输入歌手+歌名搜索在线歌词"
                                 : "未找到匹配的歌词")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if !searchQuery.isEmpty {
                                Button("重试搜索") { performSearch() }
                                    .buttonStyle(BouncyButtonStyle())
                            }
                        }
                        Spacer()
                    }
                } else {
                    List {
                        Section("搜索结果（\(viewModel.lyricSearchResults.count)）") {
                            ForEach(viewModel.lyricSearchResults) { result in
                                LyricsResultRow(result: result) {
                                    Task {
                                        await viewModel.downloadLyrics(result: result)
                                        isPresented = false
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("在线歌词搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isPresented = false }
                }
            }
            .onAppear {
                if let song = viewModel.currentSong {
                    searchQuery = "\(song.displayArtist) \(song.title)"
                    performSearch()
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        let parts = searchQuery.components(separatedBy: " ")
        let artist = parts.count > 1 ? parts[0] : ""
        let title = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : searchQuery
        Task { await viewModel.searchLyricsOnline(title: title, artist: artist) }
    }
}

/// 单条搜索结果行
struct LyricsResultRow: View {
    let result: LyricsSearchResult
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 来源图标
                Image(systemName: sourceIcon)
                    .font(.system(size: 14))
                    .foregroundColor(sourceColor)
                    .frame(width: 36, height: 36)
                    .background(sourceColor.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)
                    Text(result.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.source.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(sourceColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.1))
                        .cornerRadius(4)

                    Text(formatDuration(result.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var sourceIcon: String {
        switch result.source {
        case .netease: return "n.circle.fill"
        case .qq: return "q.circle.fill"
        case .kugou: return "k.circle.fill"
        case .local: return "house.circle.fill"
        }
    }

    private var sourceColor: Color {
        switch result.source {
        case .netease: return Color(hex: "E60026")
        case .qq: return Color(hex: "31C27C")
        case .kugou: return Color(hex: "FF7F00")
        case .local: return .secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    EnhancedLyricsView(isPresented: .constant(true))
        .environmentObject(PlayerViewModel())
}
