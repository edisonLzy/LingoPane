import SwiftUI

public struct HistoryView: View {
    @ObservedObject var state: AppState
    @State private var query = ""
    @State private var language: Language?
    @State private var kind: ContentKind?

    public init(state: AppState) {
        self.state = state
    }

    private var filtered: [HistoryItem] {
        state.history.filter { item in
            let matchesQuery = query.isEmpty
                || item.searchableText.localizedCaseInsensitiveContains(query)
            let matchesLanguage = language == nil || item.result.language == language
            let matchesKind = kind == nil || item.result.kind == kind
            return matchesQuery && matchesLanguage && matchesKind
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("搜索原文或译文", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("方向", selection: $language) {
                    Text("全部方向").tag(Language?.none)
                    Text("EN → ZH").tag(Language?.some(.english))
                    Text("ZH → EN").tag(Language?.some(.chinese))
                }
                .labelsHidden()
                .frame(width: 120)
                Picker("类型", selection: $kind) {
                    Text("全部类型").tag(ContentKind?.none)
                    Text("中文表达").tag(ContentKind?.some(.chinese))
                    Text("单词/短语").tag(ContentKind?.some(.word))
                    Text("英文句子").tag(ContentKind?.some(.sentence))
                }
                .labelsHidden()
                .frame(width: 120)
                Button {
                    state.reloadHistory()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("从 Vault 重新载入")
            }
            .padding(14)

            Divider()

            if filtered.isEmpty {
                ContentUnavailableView(
                    "暂无历史",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(query.isEmpty ? "完成一次翻译后会显示在这里。" : "没有匹配的记录。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.result.language == .english ? "textformat" : "character")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.result.source).lineLimit(1).fontWeight(.medium)
                            Text(item.result.primaryResult).lineLimit(1).foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                Text(item.result.kind.shortTitle)
                                Text(item.lastScene.rawValue)
                                if item.encounterCount > 1 { Text("遇见 \(item.encounterCount) 次") }
                            }
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(item.lastSeenAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button {
                            state.reopen(item)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderless)
                        .help("重新打开")
                        Button(role: .destructive) {
                            state.deleteHistory(id: item.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("删除记录")
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .onAppear { state.reloadHistory() }
        .frame(width: 650, height: 470)
    }
}
