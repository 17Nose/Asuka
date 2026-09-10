import SwiftUI
import UniformTypeIdentifiers

/// 音乐库主界面（增强版：视差滚动 + 动画头部 + 搜索动画 + 主题支持）
struct LibraryView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab: LibraryTab = .recommend
    @State private var isSearching = false
    @State private var headerOffset: CGFloat = 0
    @State private var showScanAnimation = false
    @State private var showImporter = false
    @State private var importResultMessage: String?

    enum LibraryTab: String, CaseIterable {
        case recommend = "推荐"
        case songs = "歌曲"
        case albums = "专辑"
        case artists = "歌手"

        var icon: String {
            switch self {
            case .recommend: return "sparkles"
            case .songs: return "music.note.list"
            case .albums: return "square.stack.fill"
            case .artists: return "music.mic"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 背景色跟随主题
                theme.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索栏（动画）
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Tab 选择器（视差效果）
                    tabPicker
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .offset(y: headerOffset * -0.3)
                        .opacity(1 - max(0, headerOffset / 100))

                    // 内容区
                    if isSearching && !viewModel.searchQuery.isEmpty {
                        SongListView(songs: viewModel.searchResults)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else {
                        tabContent
                    }

                    Spacer(minLength: 66) // 为 mini player 留空间
                }

                // 扫描进度提示
                if viewModel.isScanning {
                    scanningBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }

                // 迷你播放条
                MiniPlayerView()
                    .environmentObject(viewModel)
                    .zIndex(5)
            }
            .animation(.easeInOut(duration: 0.3), value: isSearching)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isScanning)
            .navigationBarHidden(true)
            // 主题色工具栏操作
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        // 主题切换
                        Menu {
                            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                                Button(action: { theme.themeMode = mode }) {
                                    Label(
                                        mode.rawValue,
                                        systemImage: theme.themeMode == mode
                                            ? "checkmark"
                                            : mode.icon
                                    )
                                }
                            }

                            Divider()

                            // 主题色选择
                            ForEach(ThemeManager.accentColors, id: \.name) { item in
                                Button(action: { theme.accentColor = item.color }) {
                                    Label(
                                        item.name,
                                        systemImage: theme.accentColor == item.color
                                            ? "checkmark"
                                            : "circle.fill"
                                    )
                                    .foregroundColor(item.color)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 16))
                                .foregroundColor(theme.textPrimary)
                        }

                        // 导入本地文件
                        Button(action: {
                            HapticStyle.light.trigger()
                            showImporter = true
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(theme.textPrimary)
                        }
                        .buttonStyle(BouncyButtonStyle(scale: 0.85))
                        .disabled(viewModel.isImporting)

                        // 扫描按钮
                        scanButton
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .mpeg4Movie, .wav, .aiff, .item],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .alert("导入完成", isPresented: Binding(
                get: { importResultMessage != nil },
                set: { if !$0 { importResultMessage = nil } }
            )) {
                Button("好", role: .cancel) { importResultMessage = nil }
            } message: {
                Text(importResultMessage ?? "")
            }
        }
    }

    // MARK: - 处理导入

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                await viewModel.importFiles(from: urls)
                if let error = viewModel.errorMessage {
                    importResultMessage = error
                    viewModel.errorMessage = nil
                } else {
                    importResultMessage = "已导入 \(urls.count) 个文件"
                }
            }

        case .failure(let error):
            importResultMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 搜索栏（增强动画）

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                // 搜索图标（旋转动画）
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isSearching ? 0 : 0))
                    .scaleEffect(isSearching ? 0.9 : 1.0)

                TextField("搜索歌曲、歌手、专辑...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .onSubmit { viewModel.search() }
                    .onChange(of: viewModel.searchQuery) { _ in
                        viewModel.search()
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isSearching = true
                        }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        HapticStyle.light.trigger()
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(isSearching ? 0.08 : 0.03),
                        radius: isSearching ? 8 : 4,
                        x: 0,
                        y: 2
                    )
            )

            // 取消按钮（弹性出现）
            if isSearching {
                Button("取消") {
                    HapticStyle.selection.trigger()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isSearching = false
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ColorPalette.primary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    // MARK: - Tab 选择器（胶囊样式）

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                Button(action: {
                    HapticStyle.selection.trigger()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                selectedTab == tab
                                    ? ColorPalette.primary
                                    : theme.surfaceColor
                            )
                            .shadow(
                                color: selectedTab == tab
                                    ? ColorPalette.primary.opacity(0.3)
                                    : .clear,
                                radius: 6,
                                y: 2
                            )
                    )
                }
                .buttonStyle(.plain)

                if tab != LibraryTab.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(theme.surfaceColor)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - Tab 内容

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .recommend:
            RecommendView()
                .environmentObject(viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .songs:
            SongListView(songs: viewModel.allSongs)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .albums:
            albumGridView
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        case .artists:
            artistListView
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }

    // MARK: - 专辑网格（视差效果）

    /// 专辑聚合条目（拆成独立类型，避免 SwiftUI 类型检查超时）
    struct AlbumItem: Identifiable {
        let name: String
        let artist: String
        let coverPath: String?
        let songs: [Song]
        var id: String { name }
        var songCount: Int { songs.count }
    }

    private var albumItems: [AlbumItem] {
        let grouped = Dictionary(grouping: viewModel.allSongs) {
            $0.album.isEmpty ? "未知专辑" : $0.album
        }
        return grouped.keys.sorted().map { key in
            let songs = grouped[key] ?? []
            return AlbumItem(
                name: key,
                artist: songs.first?.artist ?? "",
                coverPath: songs.first?.coverArtPath,
                songs: songs
            )
        }
    }

    private var albumGridView: some View {
        Group {
            if viewModel.allSongs.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 155, maximum: 175), spacing: 14)],
                        spacing: 18
                    ) {
                        ForEach(albumItems) { item in
                            albumCard(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
            }
        }
    }

    private func albumCard(_ item: AlbumItem) -> some View {
        AlbumCardView(
            albumName: item.name,
            artist: item.artist,
            coverPath: item.coverPath,
            songCount: item.songCount
        )
        .onTapGesture {
            HapticStyle.medium.trigger()
            guard let first = item.songs.first else { return }
            viewModel.play(song: first, from: item.songs)
        }
    }

    // MARK: - 歌手列表

    private var artistListView: some View {
        let grouped = Dictionary(grouping: viewModel.allSongs) {
            $0.artist.isEmpty ? "未知歌手" : $0.artist
        }

        return Group {
            if viewModel.allSongs.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(Array(grouped.keys.sorted().enumerated()), id: \.element) { index, artist in
                        let songs = grouped[artist] ?? []
                        ArtistRowView(
                            artist: artist,
                            songCount: songs.count,
                            index: index
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticStyle.medium.trigger()
                            viewModel.play(song: songs[0], from: songs)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - 空状态（主题自适应）

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 浮动音乐图标
            ZStack {
                Circle()
                    .fill(ColorPalette.primary.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "music.note.list")
                    .font(.system(size: 50))
                    .foregroundColor(ColorPalette.primary.opacity(0.5))
                    .floatingAnimation(isActive: true, amplitude: 8)
            }

            VStack(spacing: 8) {
                Text("还没有歌曲")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(theme.textPrimary)

                Text("点击右上角按钮扫描本地音乐")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
            }

            // 扫描按钮（光泽效果）
            Button(action: {
                HapticStyle.heavy.trigger()
                Task { await viewModel.scanFiles() }
            }) {
                Label("开始扫描音乐", systemImage: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
            }
            .buttonStyle(ShinyButtonStyle(color: ColorPalette.primary, height: 46))
            .frame(width: 220)

            Spacer()
        }
        .padding(.bottom, 80)
    }

    // MARK: - 扫描按钮

    private var scanButton: some View {
        Button(action: {
            HapticStyle.medium.trigger()
            Task { await viewModel.scanFiles() }
        }) {
            if viewModel.isScanning {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(ColorPalette.primary)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(theme.textPrimary)
                    .rotationEffect(.degrees(showScanAnimation ? 360 : 0))
                    .animation(
                        viewModel.isScanning
                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.isScanning
                    )
            }
        }
        .disabled(viewModel.isScanning)
        .buttonStyle(BouncyButtonStyle(scale: 0.85))
    }

    // MARK: - 扫描进度横幅

    private var scanningBanner: some View {
        VStack {
            HStack(spacing: 12) {
                // 旋转光盘动画
                Image(systemName: "opticaldisc")
                    .font(.system(size: 18))
                    .foregroundColor(ColorPalette.primary)
                    .rotationEffect(.degrees(showScanAnimation ? 360 : 0))
                    .animation(
                        .linear(duration: 2).repeatForever(autoreverses: false),
                        value: showScanAnimation
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("正在扫描音乐文件...")
                        .font(.system(size: 13, weight: .medium))

                    // 进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 3)

                            Capsule()
                                .fill(ColorPalette.gradientPrimary)
                                .frame(width: geo.size.width * viewModel.scanProgress, height: 3)
                                .animation(.easeInOut, value: viewModel.scanProgress)
                        }
                    }
                    .frame(height: 3)
                }

                Text("\(Int(viewModel.scanProgress * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
        .onAppear { showScanAnimation = true }
    }
}

// MARK: - 歌手行视图

struct ArtistRowView: View {
    let artist: String
    let songCount: Int
    let index: Int

    var body: some View {
        HStack(spacing: 14) {
            // 头像（渐变背景 + 首字母）
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                hueColor.opacity(0.7),
                                hueColor.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Text(String(artist.prefix(1)))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(artist)
                    .font(.system(size: 16, weight: .medium))

                Text("\(songCount) 首歌曲")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    /// 根据索引生成不同色调
    private var hueColor: Color {
        let colors: [Color] = [
            ColorPalette.primary,
            Color(hex: "0984E3"),
            Color(hex: "00B894"),
            Color(hex: "E17055"),
            Color(hex: "FD79A8"),
            Color(hex: "6C5CE7"),
            Color(hex: "00CEC9"),
        ]
        return colors[index % colors.count]
    }
}

// MARK: - 专辑卡片

struct AlbumCardView: View {
    let albumName: String
    let artist: String
    let coverPath: String?
    let songCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImage
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(albumName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(artist.isEmpty ? "未知歌手" : artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("\(songCount) 首")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let path = coverPath,
           let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(ColorPalette.gradientPrimary.opacity(0.3))
                .overlay(
                    Image(systemName: "music.note.list")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.system(size: 24))
                )
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(PlayerViewModel())
}
