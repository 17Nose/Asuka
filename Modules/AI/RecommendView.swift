import SwiftUI

/// AI 推荐主页面
struct RecommendView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject var engine = SmartPlaylistEngine.shared
    @State private var selectedMode: RecommendationMode = .dailyMix
    @State private var showAPISettings = false
    @State private var animateCards = false

    var body: some View {
        // 不再自带 NavigationStack —— 它已经被 LibraryView 的导航栈包住，
        // 再嵌一层会导致 navigationDestination 失效
        ScrollView {
            VStack(spacing: 20) {
                // 时段问候头部（含设置入口）
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // 推荐模式选择器
                modePicker
                    .padding(.horizontal, 20)

                // 推荐内容
                switch selectedMode {
                case .dailyMix:
                    dailyMixSection
                case .moodRadio:
                    moodRadioSection
                case .discoverSimilar:
                    discoverSimilarSection
                }

                // AI 设置卡片
                apiSettingsCard
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            .padding(.bottom, 100)
        }
        .background(Color(hex: "F8F9FA").ignoresSafeArea())
        .sheet(isPresented: $showAPISettings) {
            APISettingsView()
        }
        .onAppear {
            engine.checkDailyRefresh()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                animateCards = true
            }
        }
    }

    // MARK: - 时段问候头部

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.system(size: 28, weight: .bold))

                    Text(engine.getTimeBasedMood())
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                Spacer()

                // AI 状态指示器
                if engine.isGenerating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("AI 思考中")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorPalette.primary.opacity(0.08))
                    .cornerRadius(12)
                }
            }

            if let error = engine.generationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...9: return "早上好 ☀️"
        case 10...12: return "上午好 🌤"
        case 13...17: return "下午好 🌈"
        case 18...21: return "晚上好 🌙"
        default: return "夜深了 ✨"
        }
    }

    // MARK: - 推荐模式选择器

    private var modePicker: some View {
        HStack(spacing: 10) {
            ForEach(RecommendationMode.allCases, id: \.self) { mode in
                Button(action: {
                    HapticStyle.selection.trigger()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                    triggerMode(mode)
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20))
                            .foregroundColor(selectedMode == mode ? .white : ColorPalette.primary)
                            .frame(width: 48, height: 48)
                            .background(
                                selectedMode == mode
                                    ? ColorPalette.primary
                                    : ColorPalette.primary.opacity(0.1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text(mode.title)
                            .font(.system(size: 13, weight: selectedMode == mode ? .semibold : .regular))
                            .foregroundColor(selectedMode == mode ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 每日推荐

    private var dailyMixSection: some View {
        VStack(spacing: 16) {
            if let recommendation = engine.dailyRecommendation {
                // 歌单头部
                playlistHeader(
                    name: recommendation.playlistName,
                    description: recommendation.description,
                    mood: recommendation.mood,
                    trackCount: recommendation.tracks.count
                )

                // 歌曲列表
                trackListView(tracks: recommendation.tracks)
            } else if engine.isGenerating {
                loadingState
            } else {
                emptyState(mode: .dailyMix)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 心情电台

    private var moodRadioSection: some View {
        VStack(spacing: 16) {
            if let recommendation = engine.moodRecommendation {
                playlistHeader(
                    name: recommendation.playlistName,
                    description: recommendation.description,
                    mood: recommendation.mood,
                    trackCount: recommendation.tracks.count
                )
                trackListView(tracks: recommendation.tracks)
            } else if engine.isGenerating {
                loadingState
            } else {
                emptyState(mode: .moodRadio)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 发现相似

    private var discoverSimilarSection: some View {
        VStack(spacing: 16) {
            if let song = viewModel.currentSong {
                // 当前歌曲信息卡
                currentSongCard(song)

                if !engine.similarTracks.isEmpty {
                    Text("相似推荐")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    trackListView(
                        tracks: engine.similarTracks,
                        showScore: true
                    )
                } else if engine.isGenerating {
                    loadingState
                } else {
                    emptyState(mode: .discoverSimilar)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("请先播放一首歌曲")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("AI 将基于正在播放的歌曲发现相似好音乐")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
        .padding(.horizontal, 20)
    }

    /// 当前播放歌曲信息卡片
    private func currentSongCard(_ song: Song) -> some View {
        GlassmorphicCard(cornerRadius: 16, padding: 16) {
            HStack(spacing: 14) {
                Group {
                    if let image = song.coverImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ColorPalette.gradientPrimary)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.6))
                            )
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("基于当前歌曲")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(song.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(song.displayArtist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    Task { await engine.discoverSimilar(to: song) }
                }) {
                    Text("发现相似")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ColorPalette.primary)
                        .cornerRadius(16)
                }
                .disabled(engine.isGenerating)
            }
        }
    }

    // MARK: - 共享组件

    /// 推荐歌单头部
    private func playlistHeader(
        name: String,
        description: String,
        mood: String?,
        trackCount: Int
    ) -> some View {
        VStack(spacing: 12) {
            // 歌单封面占位
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorPalette.primary,
                                ColorPalette.secondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.7))
                    Text(name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    if let mood = mood {
                        HStack(spacing: 6) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))
                            Text(mood)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ColorPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorPalette.primary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Spacer()

                Text("\(trackCount) 首")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    /// 歌曲列表
    private func trackListView(
        tracks: [RecommendedTrack],
        showScore: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, rank: index + 1, showScore: showScore)
                    .opacity(animateCards ? 1 : 0)
                    .offset(y: animateCards ? 0 : 10)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.06),
                        value: animateCards
                    )
                    .onTapGesture {
                        if let song = track.matchedLocalSong {
                            let playQueue = tracks.compactMap { $0.matchedLocalSong }
                            HapticStyle.medium.trigger()
                            viewModel.play(song: song, from: playQueue)
                        }
                    }

                if index < tracks.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 状态视图

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            ProgressView()
                .scaleEffect(1.3)
                .tint(ColorPalette.primary)

            VStack(spacing: 8) {
                Text("AI 正在为您生成推荐...")
                    .font(.system(size: 16, weight: .medium))
                Text("分析播放历史 + 匹配音乐风格")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private func emptyState(mode: RecommendationMode) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 30)
            Image(systemName: mode.icon)
                .font(.system(size: 44))
                .foregroundColor(ColorPalette.primary.opacity(0.4))

            Text("\(mode.title) 尚未生成")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text(mode.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Button(action: { triggerMode(mode) }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("立即生成推荐")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ColorPalette.primary)
                .cornerRadius(20)
            }

            Spacer().frame(height: 30)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - API 设置卡片

    private var apiSettingsCard: some View {
        GlassmorphicCard(cornerRadius: 16, padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 引擎")
                        .font(.system(size: 14, weight: .medium))
                    Text("当前: \(AIService.shared.selectedProvider.rawValue)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("配置") {
                    showAPISettings = true
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ColorPalette.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(ColorPalette.primary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 辅助方法

    private func triggerMode(_ mode: RecommendationMode) {
        switch mode {
        case .dailyMix:
            Task { await engine.generateDailyMix() }
        case .moodRadio:
            Task { await engine.generateMoodRadio() }
        case .discoverSimilar:
            if let song = viewModel.currentSong {
                Task { await engine.discoverSimilar(to: song) }
            }
        }
    }
}

// MARK: - 单条推荐歌曲行

struct TrackRow: View {
    let track: RecommendedTrack
    let rank: Int
    var showScore: Bool = false

    /// 是否匹配到本地曲库
    private var isLocal: Bool { track.matchedLocalSong != nil }

    var body: some View {
        HStack(spacing: 12) {
            rankLabel
            coverPlaceholder
            infoSection
            Spacer()
            trailingSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var matchColor: Color {
        if track.score >= 0.8 { return Color(hex: "00B894") }
        if track.score >= 0.5 { return Color(hex: "FDCB6E") }
        return .secondary
    }

    // MARK: - 子视图

    private var rankLabel: some View {
        Text(String(rank))
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(rank <= 3 ? ColorPalette.primary : Color.secondary)
            .frame(width: 24)
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isLocal
                  ? AnyShapeStyle(ColorPalette.gradientPrimary.opacity(0.2))
                  : AnyShapeStyle(Color.secondary.opacity(0.1)))
            .frame(width: 40, height: 40)
            .overlay(coverIcon)
    }

    private var coverIcon: some View {
        Image(systemName: isLocal ? "music.note" : "globe")
            .font(.system(size: 14))
            .foregroundColor(isLocal ? ColorPalette.primary : Color.secondary.opacity(0.5))
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let album = track.album, !album.isEmpty {
                    Text("· \(album)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var trailingSection: some View {
        if showScore {
            Text(String(format: "%.0f%%", track.score * 100))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(matchColor)
        }

        if isLocal {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "00B894"))
        }
    }
}

// MARK: - API 设置页面

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: AIService.APIProvider = AIService.shared.selectedProvider
    @State private var claudeKey: String = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    @State private var openAIKey: String = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 提供商") {
                    Picker("选择引擎", selection: $selectedProvider) {
                        ForEach(AIService.APIProvider.allCases, id: \.rawValue) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) { newValue in
                        AIService.shared.selectedProvider = newValue
                        UserDefaults.standard.set(newValue.rawValue, forKey: "ai_provider")
                    }
                }

                if selectedProvider == .claude {
                    Section("Claude API 配置") {
                        SecureField("API Key (sk-ant-...)", text: $claudeKey)
                            .textContentType(.password)
                            .onChange(of: claudeKey) { key in
                                UserDefaults.standard.set(key, forKey: "claude_api_key")
                            }

                        Text("推荐使用 Claude Sonnet 模型，音乐理解力强")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if selectedProvider == .openAI {
                    Section("OpenAI API 配置") {
                        SecureField("API Key (sk-...)", text: $openAIKey)
                            .textContentType(.password)
                            .onChange(of: openAIKey) { key in
                                UserDefaults.standard.set(key, forKey: "openai_api_key")
                            }

                        Text("使用 GPT-4o 模型，温度 0.8 保证推荐多样性")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if selectedProvider == .none {
                    Section("离线模式") {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("将基于您的播放历史、歌曲流派和标签进行本地推荐，无需网络连接")
                                .font(.system(size: 14))
                        }
                    }
                }

                Section("推荐说明") {
                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(icon: "calendar.badge.clock", text: "每日推荐：每天早上自动更新")
                        infoRow(icon: "theatermasks", text: "心情电台：根据时段智能匹配")
                        infoRow(icon: "sparkle.magnifyingglass", text: "发现相似：基于当前歌曲推荐")
                        infoRow(icon: "wifi.slash", text: "无网络时自动切换离线模式")
                    }
                }
            }
            .navigationTitle("AI 推荐设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        HapticStyle.success.trigger()
                        dismiss()
                    }
                }
            }
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(ColorPalette.primary)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    RecommendView()
        .environmentObject(PlayerViewModel())
}
