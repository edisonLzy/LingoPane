import AppKit
import SwiftUI
import Charts

/// The shared library window presents saved translations, learning context, and preferences.
public struct HistoryView: View {
    @ObservedObject var state: AppState
    @ObservedObject var navigation: LibraryNavigation
    @State private var query = ""
    @State private var showingSearch = false
    @State private var hoveredItem: UUID?
    @State private var kind: ContentKind?
    @State private var language: Language?
    @State private var selection: UUID?
    @State private var pendingDeletion: HistoryItem?

    // Layout toggles
    @State private var showLearningColumn = true
    @State private var hoveredTopButton: String?

    // Column widths for interactive resizable dividers
    @State private var column1Width: CGFloat = 330
    @State private var column3Width: CGFloat = 320

    private let ink = Color(red: 0.22, green: 0.21, blue: 0.19)
    private let accent = Color(red: 0.38, green: 0.46, blue: 0.34)

    public init(state: AppState, navigation: LibraryNavigation = LibraryNavigation()) {
        self.state = state
        self.navigation = navigation
    }

    private var filtered: [HistoryItem] {
        state.history.filter {
            (query.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(query))
                && (kind == nil || $0.result.kind == kind)
                && (language == nil || $0.result.language == language)
        }.sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    private var selected: HistoryItem? {
        if let selection, let item = filtered.first(where: { $0.id == selection }) {
            return item
        }
        return filtered.first
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Top Window Bar: strictly aligned with traffic lights
                windowTopBar

                // Content View
                if navigation.page == .settings {
                    SettingsView(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainColumnsView
                }
            }

            // Floating action button (+) in bottom right corner (only in history mode)
            if navigation.page != .settings {
                floatingActionButton
            }
        }
        .ignoresSafeArea(.all)
        .foregroundStyle(ink)
        .background(FrostedGlassBackground())
        .preferredColorScheme(.light)
        .frame(minWidth: 980, minHeight: 620)
        .onAppear {
            state.reloadHistory()
            if selection == nil {
                selection = filtered.first?.id
            }
        }
        .alert("删除这条翻译记录？", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("取消", role: .cancel) { pendingDeletion = nil }
            Button("删除", role: .destructive) {
                if let item = pendingDeletion { state.deleteHistory(id: item.id) }
                pendingDeletion = nil
            }
        } message: {
            Text("对应的 Vault 知识项将被删除。")
        }
    }

    // MARK: - Window Top Bar (Parallel with macOS traffic lights)

    private var windowTopBar: some View {
        HStack(spacing: 0) {
            if navigation.page == .settings {
                // In settings: Back button clears traffic lights (~74pt)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        navigation.page = .history
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("返回翻译历史")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(ink.opacity(hoveredTopButton == "back" ? 0.08 : 0.04), in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 78)
                .onHover { hovering in hoveredTopButton = hovering ? "back" : nil }

                Spacer()

                Text("偏好设置")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(ink)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        navigation.page = .history
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(ink.opacity(hoveredTopButton == "close" ? 0.08 : 0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .onHover { hovering in hoveredTopButton = hovering ? "close" : nil }
            } else {
                // In library: Traffic lights clearance on left
                Spacer()

                // Action buttons on top-right, perfectly inline with traffic lights
                HStack(spacing: 8) {
                    // Button 1: Toggle right learning column (direct layout toggle, no weird menu)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            showLearningColumn.toggle()
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(ink.opacity(showLearningColumn ? 0.85 : 0.35))
                            .frame(width: 24, height: 24)
                            .background(
                                hoveredTopButton == "layout" ? ink.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(showLearningColumn ? "收起右侧学习栏" : "展开右侧学习栏")
                    .onHover { hovering in hoveredTopButton = hovering ? "layout" : nil }

                    // Button 2: Direct Settings toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            navigation.page = .settings
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(ink.opacity(0.70))
                            .frame(width: 24, height: 24)
                            .background(
                                hoveredTopButton == "settings" ? ink.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("偏好设置")
                    .onHover { hovering in hoveredTopButton = hovering ? "settings" : nil }
                }
                .padding(.trailing, 16)
            }
        }
        .frame(height: 28)
    }

    // MARK: - Main Columns View

    private var mainColumnsView: some View {
        HStack(spacing: 0) {
            // Column 1: History list
            historyColumn
                .frame(width: column1Width)

            // Hairline interactive draggable divider
            ResizableDivider { delta in
                column1Width = min(max(260, column1Width + delta), 460)
            }

            // Column 2: Detail view (expands to fill remaining space)
            detailColumn
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

            // Column 3: Learning & Memory Curve (collapsible via top-right button)
            if showLearningColumn {
                ResizableDivider { delta in
                    column3Width = min(max(240, column3Width - delta), 440)
                }

                learningColumn
                    .frame(width: column3Width)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Column 1: History List

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: 翻译历史 / 全部 + count + capsule / circle filter icons
            HStack(spacing: 6) {
                Text("翻译历史")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(filtered.count)")
                    .font(.system(size: 13.5))
                    .foregroundStyle(ink.opacity(0.45))

                Spacer(minLength: 4)

                // Capsule: 全部
                Button {
                    kind = nil
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10))
                        Text("全部")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(kind == nil ? ink.opacity(0.08) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("查看全部")

                // Ring: 单词 (Blue)
                filterRing(color: Color(red: 0.18, green: 0.52, blue: 0.96), value: .word, title: "单词")

                // Ring: 句子 (Purple)
                filterRing(color: Color(red: 0.62, green: 0.38, blue: 0.92), value: .sentence, title: "句子")

                // Ring: 中文 (Yellow)
                filterRing(color: Color(red: 0.95, green: 0.70, blue: 0.20), value: .chinese, title: "中文")

                // Plus / search button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showingSearch.toggle()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ink.opacity(showingSearch ? 0.9 : 0.45))
                        .frame(width: 18, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(showingSearch ? "收起搜索" : "展开搜索")
            }
            .frame(height: 28)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)

            // Search bar (collapsible, hidden by default)
            if showingSearch || !query.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ink.opacity(0.4))
                    TextField("搜索原文或译文…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ink.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Compact single-line item list with dotted rules
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        Button {
                            selection = item.id
                        } label: {
                            HStack(spacing: 9) {
                                // Leading translucent square icon
                                RoundedRectangle(cornerRadius: 3.5)
                                    .fill(ink.opacity(selection == item.id ? 0.18 : 0.08))
                                    .frame(width: 14, height: 14)

                                // Title text
                                Text(item.result.source)
                                    .font(.system(size: 13.5, weight: .regular))
                                    .foregroundStyle(ink)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Trailing note/doc icon if notes or examples exist
                                if !item.result.examples.isEmpty || !item.result.expressionNotes.isEmpty || item.result.contextMeaning != nil {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(ink.opacity(0.35))
                                }

                                // Status / Ring indicator
                                if Calendar.current.isDateInToday(item.lastSeenAt) && item.lastSeenAt.timeIntervalSince(item.createdAt) > 60 {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color(red: 0.90, green: 0.35, blue: 0.35))
                                } else {
                                    Circle()
                                        .strokeBorder(tint(item.result.kind), lineWidth: 1.6)
                                        .frame(width: 9.5, height: 9.5)
                                }
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 38)
                            .background(
                                selection == item.id
                                    ? ink.opacity(0.065)
                                    : (hoveredItem == item.id ? ink.opacity(0.03) : Color.clear),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(item.result.primaryResult)
                        .onHover { inside in
                            hoveredItem = inside ? item.id : nil
                        }

                        // Delicate dotted rule separator aligned with text
                        LibraryDottedRule()
                            .stroke(ink.opacity(0.20), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [1.5, 4.5]))
                            .frame(height: 1)
                            .padding(.leading, 31)
                            .padding(.trailing, 8)
                    }
                }
                .padding(.horizontal, 10)

                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        CuteEmptyBoxView()
                        Text(query.isEmpty && kind == nil ? "还没有翻译记录" : "没有匹配的记录")
                            .font(.system(size: 12.5))
                            .foregroundStyle(ink.opacity(0.4))
                    }
                    .padding(.top, 90)
                }
            }
        }
    }

    private func filterRing(color: Color, value: ContentKind, title: String) -> some View {
        Button {
            kind = (kind == value ? nil : value)
        } label: {
            Circle()
                .strokeBorder(color, lineWidth: kind == value ? 2.2 : 1.6)
                .background(kind == value ? color.opacity(0.15) : Color.clear, in: Circle())
                .frame(width: 13, height: 13)
                .frame(width: 19, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("筛选\(title)")
    }

    // MARK: - Column 2: Detail View

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: matches horizontal baseline of Column 1
            HStack {
                Text("词句详情")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let item = selected {
                    Text(item.result.kind.shortTitle)
                        .font(.caption)
                        .foregroundStyle(tint(item.result.kind))
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 6)

            ScrollView {
                if let item = selected {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.result.source)
                                .font(.system(size: 24, weight: .medium, design: .serif))
                                .textSelection(.enabled)

                            if let ipa = item.result.ipa {
                                Text(ipa)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Text(item.result.primaryResult)
                                .font(.system(size: 16))
                                .lineSpacing(6)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Button {
                                state.copy(item.result.primaryResult)
                            } label: {
                                Label("复制译文", systemImage: "doc.on.doc")
                            }

                            Button {
                                state.reopen(item)
                            } label: {
                                Label("打开翻译", systemImage: "arrow.up.forward.app")
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .tint(accent)

                        Divider().opacity(0.4)

                        if let context = item.result.contextMeaning {
                            note("语境释义", context)
                        }
                        if let skeleton = item.result.sentenceSkeleton {
                            note("句子主干", skeleton)
                        }
                        ForEach(Array(item.result.examples.enumerated()), id: \.offset) { _, example in
                            note("例句", example.english + "\n" + example.chinese)
                        }
                        if !item.result.expressionNotes.isEmpty {
                            note("表达笔记", item.result.expressionNotes.joined(separator: "\n"))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("学习足迹").font(.subheadline.weight(.medium))
                            Text("初次遇见  ·  \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            Text("最近遇见  ·  \(item.lastSeenAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("使用场景  ·  \(item.lastScene.rawValue)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button("删除记录", role: .destructive) {
                            pendingDeletion = item
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                } else {
                    // Empty state illustration matching target UI
                    VStack(spacing: 14) {
                        CuteEmptyBoxView()
                        Text("选择一条翻译，在这里慢慢读。")
                            .font(.system(size: 13))
                            .foregroundStyle(ink.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 140)
                }
            }
        }
    }

    // MARK: - Column 3: Learning & Memory Curve

    private var learningColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: matches horizontal baseline of Column 1 & 2
            HStack {
                Text("今日学习")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("学习概览")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 28)
            .padding(.horizontal, 18)
            .padding(.top, 4)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 28) {
                        metric("今日遇见过", value: state.history.filter { Calendar.current.isDateInToday($0.lastSeenAt) }.count)
                        metric("累计词句", value: state.history.count)
                    }

                    Divider().opacity(0.4)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("记忆曲线")
                            .font(.system(size: 14.5, weight: .medium))
                        Text("时间会冲淡记忆，重逢让它更清晰。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Chart {
                            ForEach(0...28, id: \.self) { step in
                                LineMark(x: .value("天", Double(step) / 4), y: .value("参考记忆", 100 * exp(-Double(step) / 8)))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(accent)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXScale(domain: 0...7)
                        .chartXAxis {
                            AxisMarks(values: [0, 1, 3, 7]) { value in
                                AxisValueLabel {
                                    if let day = value.as(Int.self) {
                                        Text("\(day)天")
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: [0, 50, 100])
                        }
                        .frame(height: 140)
                        .accessibilityLabel("参考记忆曲线")

                        Text("示意模型 · 非个人记忆测量\n尚无复习测验数据，不计算掌握率。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    Divider().opacity(0.4)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("值得再看")
                                .font(.system(size: 14.5, weight: .medium))
                            Spacer()
                            Image(systemName: "leaf")
                                .font(.system(size: 12))
                                .foregroundStyle(accent)
                        }
                        Text("从最久未遇见的词句开始。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(state.history.sorted { $0.lastSeenAt < $1.lastSeenAt }.prefix(3))) { item in
                            Button {
                                query = ""
                                kind = nil
                                language = nil
                                selection = item.id
                                navigation.page = .history
                            } label: {
                                HStack {
                                    Text(item.result.source)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        if state.history.isEmpty {
                            VStack(spacing: 8) {
                                CuteEmptyBoxView()
                                Text("记录翻译后，会在这里推荐回顾。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Floating Action Button (+)

    private var floatingActionButton: some View {
        Button {
            StatusBarController.shared.showPopover()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ink.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .padding(22)
        .help("快捷输入翻译")
    }

    // MARK: - Helper Views & Functions

    private func tint(_ kind: ContentKind) -> Color {
        switch kind {
        case .word: return Color(red: 0.18, green: 0.52, blue: 0.96)
        case .sentence: return Color(red: 0.62, green: 0.38, blue: 0.92)
        case .chinese: return Color(red: 0.95, green: 0.70, blue: 0.20)
        }
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(.system(size: 30, weight: .light, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13.5))
                .lineSpacing(5)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Frosted Glass Translucent Background

public struct FrostedGlassBackground: View {
    public init() {}

    public var body: some View {
        VisualEffectRepresentable()
            .overlay(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.95, blue: 0.91).opacity(0.68),
                        Color(red: 0.94, green: 0.91, blue: 0.86).opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea()
    }
}

public struct VisualEffectRepresentable: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .underWindowBackground
        nsView.blendingMode = .behindWindow
        nsView.state = .active
    }
}

// MARK: - Resizable Divider with Hover & Drag

public struct ResizableDivider: View {
    let onDelta: (CGFloat) -> Void
    @State private var isHovering = false
    @State private var lastDragLocation: CGFloat = 0

    public init(onDelta: @escaping (CGFloat) -> Void) {
        self.onDelta = onDelta
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovering ? Color(red: 0.22, green: 0.21, blue: 0.19).opacity(0.28) : Color(red: 0.22, green: 0.21, blue: 0.19).opacity(0.08))
                .frame(width: 1)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    let delta = gesture.translation.width - lastDragLocation
                    lastDragLocation = gesture.translation.width
                    onDelta(delta)
                }
                .onEnded { _ in
                    lastDragLocation = 0
                }
        )
    }
}

// MARK: - Cute Minimal Empty State Illustration

public struct CuteEmptyBoxView: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var path = Path()
            // Lower tray with rounded bottom corners
            let boxY = h * 0.44
            let boxHeight = h * 0.38
            let boxWidth = w * 0.72
            let boxX = (w - boxWidth) / 2
            let r: CGFloat = 8

            // Tray body
            path.move(to: CGPoint(x: boxX, y: boxY))
            path.addLine(to: CGPoint(x: boxX + boxWidth, y: boxY))
            path.addLine(to: CGPoint(x: boxX + boxWidth, y: boxY + boxHeight - r))
            path.addQuadCurve(to: CGPoint(x: boxX + boxWidth - r, y: boxY + boxHeight), control: CGPoint(x: boxX + boxWidth, y: boxY + boxHeight))
            path.addLine(to: CGPoint(x: boxX + r, y: boxY + boxHeight))
            path.addQuadCurve(to: CGPoint(x: boxX, y: boxY + boxHeight - r), control: CGPoint(x: boxX, y: boxY + boxHeight))
            path.closeSubpath()

            // Upper rounded lid with angled sides
            let lidWidth = w * 0.54
            let lidX = (w - lidWidth) / 2
            let lidTopY = h * 0.30
            path.move(to: CGPoint(x: boxX + 5, y: boxY))
            path.addLine(to: CGPoint(x: lidX, y: lidTopY + 4))
            path.addQuadCurve(to: CGPoint(x: lidX + 4, y: lidTopY), control: CGPoint(x: lidX, y: lidTopY))
            path.addLine(to: CGPoint(x: lidX + lidWidth - 4, y: lidTopY))
            path.addQuadCurve(to: CGPoint(x: lidX + lidWidth, y: lidTopY + 4), control: CGPoint(x: lidX, y: lidTopY))
            path.addLine(to: CGPoint(x: boxX + boxWidth - 5, y: boxY))

            // Center latch / cut
            let latchW = w * 0.22
            let latchH = h * 0.08
            let latchX = (w - latchW) / 2
            let latchY = boxY - latchH / 2
            path.addRoundedRect(in: CGRect(x: latchX, y: latchY, width: latchW, height: latchH), cornerSize: CGSize(width: 3, height: 3))

            // Sparkle / little antennas on top
            path.move(to: CGPoint(x: w * 0.62, y: lidTopY - 2))
            path.addLine(to: CGPoint(x: w * 0.68, y: lidTopY - 10))

            path.move(to: CGPoint(x: w * 0.54, y: lidTopY - 3))
            path.addLine(to: CGPoint(x: w * 0.54, y: lidTopY - 11))

            context.stroke(path, with: .color(Color(red: 0.22, green: 0.21, blue: 0.19).opacity(0.20)), lineWidth: 1.5)
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Navigation & Dotted Rule

public enum LibraryPage: String, CaseIterable {
    case history = "翻译历史"
    case learning = "记忆与学习"
    case settings = "设置"

    var symbol: String {
        switch self {
        case .history: return "square.grid.2x2"
        case .learning: return "chart.xyaxis.line"
        case .settings: return "slider.horizontal.3"
        }
    }
}

@MainActor
public final class LibraryNavigation: ObservableObject {
    @Published var page: LibraryPage = .history
    public init() {}
}

private struct LibraryDottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
