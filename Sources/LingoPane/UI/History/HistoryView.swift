import SwiftUI

public struct HistoryView: View {
    @ObservedObject var state: AppState
    @State private var query = ""
    @State private var language: Language?

    public init(state: AppState) {
        self.state = state
    }

    private var filtered: [HistoryItem] {
        state.history.filter { item in
            let matchesQuery = query.isEmpty
                || item.result.source.localizedCaseInsensitiveContains(query)
                || item.result.primaryResult.localizedCaseInsensitiveContains(query)
            let matchesLanguage = language == nil || item.result.language == language
            return matchesQuery && matchesLanguage
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
                        }
                        Spacer()
                        Text(item.createdAt, style: .relative)
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
        .frame(width: 650, height: 470)
    }
}
