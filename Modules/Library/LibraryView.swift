import SwiftUI
import UniformTypeIdentifiers

/// 音乐库主界面（增强版：视差滚动 + 动画头部 + 搜索动画 + 主题支持）
struct LibraryView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var theme = ThemeManager.shared
    @State private var selectedTab: LibraryTab = .recommend
    @State private var isSearching = false
    @State private var showScanAnimation = false
    @State private var showImporter = false
    /// 导航栈路径 —— 需要一个可清空的引用，底部标签栏才能「一键回到根」
    @State private var navPath = NavigationPath()
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
        ZStack(alignment: .bottom) {
            // 背景色跟随主题
            theme.backgroundColor
                .ignoresSafeArea()

            NavigationStack(path: $navPath) {
                rootContent
                    // 用 .toolbar(.hidden) 而非 navigationBarHidden：
                    // 后者在 iOS 16 下会把 push 出来的子页面导航栏和返回按钮一起压掉
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: LibraryRoute.self) { route in
                        switch route {
                        case .artist(let name):
                            ArtistDetailView(artistName: name)
                        case .album(let name, let artist):
                            AlbumDetailView(albumName: name, artistName: artist)
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

            // 扫描进度提示
            if viewModel.isScanning {
                scanningBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // 迷你播放条 + 底部标签栏
            //
            // 都放在 NavigationStack 外层：这样 push 到歌手/专辑详情页时它们依然常驻
            VStack(spacing: 0) {
                MiniPlayerView()
                    .environmentObject(viewModel)

                floatingTabBar
            }
            .zIndex(5)
        }
        .animation(.easeInOut(duration: 0.3), value: isSearching)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isScanning)
    }

    // MARK: - 底部标签栏

    /// 只有图标，**没有底板**
    ///
    /// 之前给它套了一层 `.ultraThinMaterial` 玻璃。问题是：
    /// 浅色模式下这个材质渲染出来就是一片浅白，压在本就偏白的页面背景上，
    /// 看起来不是"玻璃"而是"一块白色面板占了一行"。
    ///
    /// 去掉底板后图标直接浮在内容上 —— 这也是 Apple Music、网易云的做法。
    /// 为了保证压在专辑封面上也看得清，给图标加一层很淡的阴影做描边感。
    private var floatingTabBar: some View {
        HStack(spacing: 2) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                Button {
                    HapticStyle.selection.trigger()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                    // 标签栏浮在导航栈之外，push 到歌手/专辑详情页时依然可见。
                    // 不清空路径的话，点标签只会换 selectedTab，
                    // 界面还停在详情页上 —— 看起来就是「点了没反应」。
                    if !navPath.isEmpty {
                        navPath = NavigationPath()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? ColorPalette.primary : theme.textSecondary)
                    .shadow(color: theme.backgroundColor.opacity(0.6), radius: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Group {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(ColorPalette.primary.opacity(0.12))
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    // MARK: - 导航栈根内容

    private var rootContent: some View {
        VStack(spacing: 0) {
            headerBar

            // 内容区
            if isSearching && !viewModel.searchQuery.isEmpty {
                SongListView(songs: viewModel.searchResults)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                tabContent
            }
        }
        // 关键：内容**铺满整个屏幕高度**，只在可滚动区域底部加一段内边距。
        //
        // 这样列表会从悬浮标签栏底下穿过 —— 透过毛玻璃能看到滚过去的封面和文字，
        // 才是 Apple Music 那种「玻璃浮在内容上」的感觉。
        // 之前是用 Spacer 在布局里硬留一行，玻璃下面什么都没有，看起来就是块实心条。
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 116)
        }
    }

    // MARK: - 顶部栏（搜索 + 操作按钮）

    /// 操作按钮直接放在这里，**不能**放导航栏的 toolbar 里：
    /// 导航栏在本页是隐藏的，放进去等于放进看不见的地方（导入按钮曾因此无法点击）
    private var headerBar: some View {
        HStack(spacing: 10) {
            searchBar
            themeMenu
            importButton
            scanButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// 主题切换
    private var themeMenu: some View {
        Menu {
            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                Button(action: { theme.themeMode = mode }) {
                    Label(
                        mode.rawValue,
                        systemImage: theme.themeMode == mode ? "checkmark" : mode.icon
                    )
                }
            }

            Divider()

            ForEach(ThemeManager.accentColors, id: \.name) { item in
                Button(action: { theme.accentColor = item.color }) {
                    Label(
                        item.name,
                        systemImage: theme.accentColor == item.color ? "checkmark" : "circle.fill"
                    )
                    .foregroundColor(item.color)
                }
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 17))
                .foregroundColor(theme.textPrimary)
                .frame(width: 34, height: 34)
        }
    }

    /// 导入本地文件
    private var importButton: some View {
        Button {
            HapticStyle.light.trigger()
            showImporter = true
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 17))
                .foregroundColor(theme.textPrimary)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(BouncyButtonStyle(scale: 0.85))
        .disabled(viewModel.isImporting)
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

    // MARK: - Tab 内容

    /// 用分页 TabView 承载四个标签页 —— 支持**左右滑动切换**（Apple Music 的手感）
    ///
    /// 之前是 `switch selectedTab` 手写切换，只能点、不能滑。
    /// 换成 `.page` 样式后，滑动和点击共用同一个 `selectedTab`，双向同步。
    /// 每页内部仍是各自的 List / ScrollView，纵向滚动与横向翻页互不冲突。
    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            ForEach(LibraryTab.allCases, id: \.self) { tab in
                pageContent(for: tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private func pageContent(for tab: LibraryTab) -> some View {
        switch tab {
        case .recommend:
            RecommendView()
                .environmentObject(viewModel)
        case .songs:
            SongListView(songs: viewModel.allSongs)
        case .albums:
            albumGridView
        case .artists:
            artistListView
        }
    }

    // MARK: - 专辑网格（视差效果）

    private var albumItems: [AlbumItem] {
        LibraryGrouping.albums(from: viewModel.allSongs)
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

    /// 点专辑进详情页（不再直接播放）
    private func albumCard(_ item: AlbumItem) -> some View {
        NavigationLink(value: LibraryRoute.album(name: item.name, artist: item.artist)) {
            AlbumCardView(
                albumName: item.name,
                artist: item.yearDisplay ?? item.artist,
                coverPath: item.coverPath,
                songCount: item.songCount
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 歌手列表

    private var artistItems: [ArtistItem] {
        LibraryGrouping.artists(from: viewModel.allSongs)
    }

    private var artistListView: some View {
        Group {
            if viewModel.allSongs.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(Array(artistItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: LibraryRoute.artist(item.name)) {
                            // 列表里用小头像：横版的歌手照片塞进 44pt 圆会被裁得很难看，
                            // 这里统一用正方形的专辑封面；大幅照片留给详情页横幅
                            ArtistRowView(
                                artist: item.name,
                                songCount: item.songCount,
                                index: index,
                                coverPath: item.coverPath
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
            Group {
                if viewModel.isScanning {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(ColorPalette.primary)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17))
                        .foregroundColor(theme.textPrimary)
                }
            }
            .frame(width: 34, height: 34)
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
    /// 歌手头像：最早一张专辑的封面，没有才用首字渐变圆
    var coverPath: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(artist)
                    .font(.system(size: 16, weight: .medium))

                Text("\(songCount) 首歌曲")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
            // 不自己画 chevron —— 外层 NavigationLink 在 List 中会自带一个
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        let side: CGFloat = 44

        Group {
            if let path = coverPath,
               let cover = UIImage(contentsOfFile: path) {
                Image(uiImage: cover)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [hueColor.opacity(0.75), hueColor.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Text(String(artist.prefix(1)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
            }
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
    }

    /// 根据索引取色（统一走 ColorPalette.hues 的撞色组）
    private var hueColor: Color {
        ColorPalette.hues[index % ColorPalette.hues.count]
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

    /// 封面固定在「格子宽度的正方形」里
    ///
    /// ⚠️ 原来只写 `.frame(height: 150)`，而 `scaledToFill()` 为了填满会**超出**建议尺寸：
    /// 正方形封面得到 165×165，比例偏宽的封面会撑成 200×150 —— 直接顶出格子，
    /// 表现就是「有的专辑封面比别的大」。用 `Color.clear` 先占出正方形再叠加图片，
    /// 尺寸就与图片自身比例无关了。
    private var coverImage: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let path = coverPath,
                   let image = UIImage(contentsOfFile: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ColorPalette.gradientPrimary.opacity(0.3)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 24))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    LibraryView()
        .environmentObject(PlayerViewModel())
}
