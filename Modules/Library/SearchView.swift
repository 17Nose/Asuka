import SwiftUI

/// 独立搜索页
///
/// **为什么单独做一页**
/// 之前搜索框是嵌在首页顶部的 `TextField`，点它只会弹出键盘 —— 因为
/// `.onTapGesture` 挂在 `TextField` 上**不会生效**（TextField 自己会吞掉点击去获取焦点），
/// 于是 `isSearching` 永远是 false，「取消」按钮根本不出现，
/// 用户就被卡在键盘界面里，只能靠回车退出。
///
/// 拆成独立页面后：进得来、退得出，还能放搜索历史。
struct SearchView: View {
    @EnvironmentObject var viewModel: PlayerViewModel
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Song] = []
    @State private var history: [String] = []
    @FocusState private var isFieldFocused: Bool

    private static let historyKey = "search_history"
    private static let maxHistory = 15

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                searchField

                if trimmedQuery.isEmpty {
                    historySection
                } else if results.isEmpty {
                    emptyResults
                } else {
                    resultsList
                }
            }
        }
        .onAppear {
            history = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
            isFieldFocused = true
        }
    }

    // MARK: - 搜索框 + 取消

    private var searchField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                TextField("搜索歌曲、歌手、专辑", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { commitSearch() }
                    .onChange(of: query) { _ in runSearch() }

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.surfaceColor)
            )

            // 明确的返回入口 —— 之前缺的就是它
            Button("取消") {
                HapticStyle.light.trigger()
                dismiss()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(ColorPalette.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - 搜索历史

    private var historySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary.opacity(0.3))
                        Text("搜索歌曲、歌手或专辑")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    HStack {
                        Text("搜索历史")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(theme.textPrimary)

                        Spacer()

                        Button {
                            HapticStyle.light.trigger()
                            clearHistory()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                    ForEach(history, id: \.self) { keyword in
                        historyRow(keyword)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func historyRow(_ keyword: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Text(keyword)
                .font(.system(size: 15))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                HapticStyle.light.trigger()
                removeHistory(keyword)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.55))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticStyle.selection.trigger()
            query = keyword
            runSearch()
        }
    }

    // MARK: - 无结果

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 38))
                .foregroundColor(.secondary.opacity(0.3))

            Text("没有找到「\(trimmedQuery)」")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 80)
    }

    // MARK: - 结果列表

    private var resultsList: some View {
        List {
            ForEach(results) { song in
                SongRowView(song: song, showAlbumArt: true)
                    .contentShape(Rectangle())
                    .onTapGesture { play(song) }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - 行为

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runSearch() {
        results = viewModel.performSearch(query)
    }

    private func play(_ song: Song) {
        HapticStyle.medium.trigger()
        commitSearch()
        viewModel.play(song: song, from: results)
        dismiss()
    }

    /// 把当前关键词记进历史：去重、置顶、限长
    private func commitSearch() {
        let keyword = trimmedQuery
        guard !keyword.isEmpty else { return }

        var updated = history.filter { $0 != keyword }
        updated.insert(keyword, at: 0)
        if updated.count > Self.maxHistory {
            updated = Array(updated.prefix(Self.maxHistory))
        }

        history = updated
        UserDefaults.standard.set(updated, forKey: Self.historyKey)
    }

    private func removeHistory(_ keyword: String) {
        history.removeAll { $0 == keyword }
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    private func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }
}

#Preview {
    SearchView()
        .environmentObject(PlayerViewModel())
}
