import SwiftUI

public struct QuickInputView: View {
    @ObservedObject var state: AppState
    @FocusState private var inputFocused: Bool

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速翻译").font(.system(size: 13, weight: .semibold))
                    Text("自动识别中文、英文单词或句子")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
            }
            .padding(14)

            VStack(spacing: 10) {
                TextEditor(text: $state.query)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 84)
                    .background(Color.primary.opacity(0.055))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 0.7)
                    }
                    .focused($inputFocused)
                    .onKeyPress(keys: [.return], phases: .down) { key in
                        if key.modifiers.contains(.shift) { return .ignored }
                        guard !state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .handled }
                        submit()
                        return .handled
                    }
                    .accessibilityLabel("输入需要翻译的内容")

                HStack {
                    Text("最多 500 字符")
                        .font(.system(size: 10))
                        .foregroundStyle(state.query.count > 500 ? .red : .secondary)
                    Spacer()
                    Button("翻译", systemImage: "arrow.right") { submit() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut(.return, modifiers: [])
                        .disabled(state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 13)

            if let error = state.lastError {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: error == .accessibilityPermission ? "hand.raised.fill" : "info.circle.fill")
                    Text(error.errorDescription ?? "请手动输入内容")
                        .font(.system(size: 11))
                    Spacer()
                    if error == .accessibilityPermission {
                        Button("授权") { SelectionProvider.shared.openAccessibilitySettings() }
                            .controlSize(.mini)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if !state.history.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近使用")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    ForEach(state.history.prefix(3)) { item in
                        Button {
                            state.reopen(item)
                            StatusBarController.shared.closePopover()
                        } label: {
                            HStack {
                                Image(systemName: item.result.language == .chinese ? "character" : "textformat")
                                    .foregroundStyle(.secondary)
                                Text(item.result.source)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .padding(14)
            }

            Divider()
            HStack {
                Button("设置…", systemImage: "gearshape") {
                    SettingsWindowCoordinator.shared.show(state: state)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("⌥ Space  划词翻译")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(width: 360)
        .background(.regularMaterial)
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            inputFocused = true
        }
        .onExitCommand { StatusBarController.shared.closePopover() }
    }

    private func submit() {
        let text = state.query
        state.translate(text)
        StatusBarController.shared.closePopover()
    }
}
