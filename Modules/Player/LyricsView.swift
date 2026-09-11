import SwiftUI

/// 增强版歌词视图（拖拽定位 + 逐字高亮 + 翻译行 + 在线搜索）
struct EnhancedLyricsView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    /// 逐字高亮需要跟着播放进度走，所以必须观察时钟
    @ObservedObject private var clock = PlaybackClock.shared
    @Binding var isPresented: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showSearchSheet = false
    @State private var selectedSearchResult: LyricsSearchResult?

    var body: some View {
        ZStack {
            // 背景层
            backgroundLayer

            // 歌词滚动内容
            VStack(spacing: 0) {
                // 顶部控制栏
                lyricsHeaderBar
                    .padding(.horizontal, 20)
                    .padding(.top, 56)

                Spacer()

                if viewModel.isSearchingLyrics {
                    // 加载状态
                    loadingState
                } else if viewModel.displayLyrics.isEmpty {
                    // 空歌词状态
                    emptyLyricsState
                } else {
                    // 歌词滚动区
                    lyricsScrollContent
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            LyricsSearchSheet(
                viewModel: viewModel,
                isPresented: $showSearchSheet
            )
        }
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

    private var lyricsScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // 顶部留白
                    Color.clear.frame(height: UIScreen.main.bounds.height * 0.35)

                    ForEach(Array(viewModel.displayLyrics.enumerated()), id: \.element.id) { index, line in
                        if !line.text.isEmpty {
                            lyricRowView(index: index, line: line)
                                .id(index)
                        }
                    }

                    // 底部留白
                    Color.clear.frame(height: UIScreen.main.bounds.height * 0.35)
                }
            }
            .simultaneousGesture(lyricsDragGesture)
            .mask(lyricsGradientMask)
            .onChange(of: viewModel.currentLyricIndex) { newIdx in
                guard !isDragging, let idx = newIdx else { return }
                let targetIndex = idx + 5
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(targetIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - 单行歌词

    @ViewBuilder
    private func lyricRowView(index: Int, line: DisplayLyricLine) -> some View {
        VStack(spacing: 4) {
            // 逐字高亮的歌词行
            if line.words.isEmpty {
                // 普通文本显示
                Text(line.text)
                    .font(.system(
                        size: line.isCurrent ? 22 : 15,
                        weight: line.isCurrent ? .bold : .regular,
                        design: .rounded
                    ))
                    .foregroundColor(lyricColor(isCurrent: line.isCurrent, isPast: line.isPast))
                    .scaleEffect(line.isCurrent ? 1.08 : 0.95)
                    .blur(radius: line.isCurrent ? 0 : 0.3)
            } else {
                // 逐字高亮显示
                wordByWordText(line: line)
            }

            // 翻译行
            if let translation = line.translation, !translation.isEmpty {
                Text(translation)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(
                        line.isCurrent
                            ? Color.white.opacity(0.5)
                            : .white.opacity(0.2)
                    )
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: line.isCurrent)
        .onTapGesture {
            // 点击歌词行跳转到对应时间
            if !line.isCurrent, let idx = viewModel.currentLyricIndex {
                let tapIndex = index - 5 // 减去 paddingLines
                if tapIndex >= 0, tapIndex < viewModel.lyricLines.count {
                    let targetTime = viewModel.lyricLines[tapIndex].time
                    HapticStyle.selection.trigger()
                    viewModel.seek(to: targetTime)
                }
            }
        }
    }

    /// 逐字高亮文本
    @ViewBuilder
    private func wordByWordText(line: DisplayLyricLine) -> some View {
        let currentTime = clock.currentTime
        // 找到当前行的开始时间
        let lineStartTime: TimeInterval = {
            if let idx = viewModel.currentLyricIndex,
               idx < viewModel.lyricLines.count {
                return viewModel.lyricLines[idx].time
            }
            return 0
        }()

        let lineElapsed = currentTime - lineStartTime
        let currentWordIdx = LRCParser.findCurrentWordIndex(
            words: line.words,
            lineElapsed: lineElapsed
        )

        // 构建富文本
        let attributedString = buildAttributedLyric(
            words: line.words,
            currentWordIndex: currentWordIdx,
            isCurrent: line.isCurrent,
            isPast: line.isPast
        )

        Text(attributedString)
            .font(.system(
                size: line.isCurrent ? 22 : 15,
                weight: line.isCurrent ? .bold : .regular,
                design: .rounded
            ))
            .scaleEffect(line.isCurrent ? 1.08 : 0.95)
    }

    private func buildAttributedLyric(
        words: [WordTiming],
        currentWordIndex: Int?,
        isCurrent: Bool,
        isPast: Bool
    ) -> AttributedString {
        var result = AttributedString()

        let baseColor = lyricUIColor(isCurrent: isCurrent, isPast: isPast)
        let highlightColor = isCurrent ? UIColor.white : UIColor.white.withAlphaComponent(0.7)

        for (i, word) in words.enumerated() {
            var part = AttributedString(word.text)
            if i == currentWordIndex && isCurrent {
                part.foregroundColor = highlightColor
                part.font = .systemFont(ofSize: 23, weight: .bold)
            } else {
                part.foregroundColor = baseColor
            }
            result += part
        }

        return result
    }

    // MARK: - 拖拽手势（手动定位歌词）

    private var lyricsDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false

                // 如果拖拽距离超过阈值，调整歌词位置
                let threshold: CGFloat = 30
                if abs(value.translation.height) > threshold {
                    // 根据拖拽方向调整当前歌词行
                    let direction = value.translation.height > 0 ? -1 : 1
                    if let current = viewModel.currentLyricIndex {
                        let newIndex = max(0, min(
                            viewModel.lyricLines.count - 1,
                            current + direction
                        ))
                        let targetTime = viewModel.lyricLines[newIndex].time
                        HapticStyle.selection.trigger()
                        viewModel.seek(to: targetTime)
                    }
                }

                withAnimation {
                    dragOffset = 0
                }
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

    // MARK: - 颜色辅助

    private func lyricColor(isCurrent: Bool, isPast: Bool) -> Color {
        if isCurrent { return .white }
        return isPast ? .white.opacity(0.22) : .white.opacity(0.55)
    }

    private func lyricUIColor(isCurrent: Bool, isPast: Bool) -> UIColor {
        if isCurrent { return .white }
        return isPast
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor.white.withAlphaComponent(0.55)
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
