import AppKit
import Foundation

@MainActor
public final class AppState: ObservableObject {
    public static let shared: AppState = {
        let preview = CommandLine.arguments.contains(where: { $0.hasPrefix("--preview") })
        return AppState(
            service: preview ? MockTranslationService() : ConfiguredTranslationService(),
            persistsHistory: !preview
        )
    }()

    @Published public var query = ""
    @Published public private(set) var history: [HistoryItem]
    @Published public var isWorking = false
    @Published public var lastError: PanelFailure?

    public let classifier = LocalClassifier()
    private let persistsHistory: Bool
    private let service: any TranslationService
    private var requestIDs: [UUID: UUID] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init(service: any TranslationService, persistsHistory: Bool = true) {
        self.persistsHistory = persistsHistory
        self.service = service
        self.history = persistsHistory ? HistoryStore.load() : []
    }

    public func translate(
        _ rawText: String,
        near anchor: NSPoint? = nil,
        classificationOverride: Classification? = nil,
        scene: ExpressionScene = .general,
        refresh: Bool = false,
        target: PanelViewModel? = nil
    ) {
        let started = Date()
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lastError = .noSelection
            StatusBarController.shared.showPopover()
            return
        }

        query = text
        let classification = classificationOverride ?? classifier.classify(text)
        let model = target ?? FloatingPanelCoordinator.shared.presentLoading(
            source: text,
            classification: classification,
            near: anchor ?? NSEvent.mouseLocation
        )

        Diagnostics.duration("query_to_panel", since: started)
        if target != nil { model.start(source: text, classification: classification) }
        model.scene = scene
        cancelTranslation(for: model.id)
        model.cancelAction = { [weak self, weak model] in
            guard let model else { return }
            model.deepTask?.cancel()
            self?.cancelTranslation(for: model.id)
        }
        guard text.count <= 500 else {
            let failure = PanelFailure.overlong(limit: 500)
            lastError = failure
            model.fail(failure)
            return
        }

        isWorking = true
        lastError = nil

        model.retryAction = { [weak self, weak model] in
            guard let self, let model else { return }
            self.tasks[model.id]?.cancel()
            self.translate(text, near: model.windowAnchor, classificationOverride: classification, scene: model.scene, refresh: true, target: model)
        }

        model.sceneAction = { [weak self, weak model] scene in
            guard let self, let model else { return }
            self.translate(text, near: model.windowAnchor, classificationOverride: classification, scene: scene, target: model)
        }
        model.deepAction = { [weak self, weak model] in
            guard let self, let model else { return }
            self.loadDeep(model)
        }
        let requestID = UUID()
        requestIDs[model.id] = requestID
        tasks[model.id] = Task { [weak self, weak model, service] in
            defer {
                if let self, let model, self.requestIDs[model.id] == requestID {
                    self.tasks[model.id] = nil
                    self.requestIDs[model.id] = nil
                    self.isWorking = !self.tasks.isEmpty
                }
            }
            do {
                let result = try await service.analyze(text, classification: classification, scene: scene, deep: false, refresh: refresh)
                guard !Task.isCancelled, let self, let model, self.requestIDs[model.id] == requestID else { return }
                model.succeed(result)
                self.record(result)
                if model.isExpanded { self.loadDeep(model) }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self, let model, self.requestIDs[model.id] == requestID else { return }
                let failure = (error as? PanelFailure) ?? .message(error.localizedDescription)
                model.fail(failure)
                self.lastError = failure
            }
        }
    }

    private func loadDeep(_ model: PanelViewModel) {
        guard !model.deepLoading, !model.deepReady, let base = model.result else { return }
        model.deepLoading = true
        model.deepFailure = nil
        let scene = model.scene
        let classification = model.classification
        model.deepTask = Task { [weak self, weak model, service] in
            do {
                let deep = try await service.analyze(base.source, classification: classification, scene: scene, deep: true, refresh: false)
                guard !Task.isCancelled, let model else { return }
                let merged = TranslationResult(
                    source: base.source, language: base.language, kind: base.kind, primaryResult: base.primaryResult,
                    ipa: deep.ipa ?? base.ipa, meanings: deep.meanings.isEmpty ? base.meanings : deep.meanings,
                    contextMeaning: deep.contextMeaning ?? base.contextMeaning, alternatives: deep.alternatives,
                    keywordMappings: deep.keywordMappings, expressionNotes: deep.expressionNotes,
                    collocations: deep.collocations, wordForms: deep.wordForms, examples: deep.examples,
                    sentenceSkeleton: deep.sentenceSkeleton ?? base.sentenceSkeleton,
                    annotations: deep.annotations, clauses: deep.clauses, grammarPoints: deep.grammarPoints,
                    translationNote: deep.translationNote, confusingWords: deep.confusingWords)
                model.phase = .ready(merged)
                model.deepReady = true
                model.deepLoading = false
                self?.record(merged)
            } catch {
                guard !Task.isCancelled, let model else { return }
                model.deepLoading = false
                model.deepFailure = error.localizedDescription
            }
        }
    }

    public func cancelTranslation(for id: UUID) {
        tasks.removeValue(forKey: id)?.cancel()
        requestIDs[id] = nil
        isWorking = !tasks.isEmpty
    }

    public func triggerSelectionTranslation() {
        if !SelectionProvider.shared.isAccessibilityGranted {
            lastError = .accessibilityPermission
            SelectionProvider.shared.requestAccessibilityPermission()
            StatusBarController.shared.showPopover()
            return
        }

        if let selected = SelectionProvider.shared.selectedText() {
            translate(selected, near: SelectionProvider.shared.selectionAnchor)
        } else {
            lastError = .noSelection
            StatusBarController.shared.showPopover()
        }
    }

    public func reopen(_ item: HistoryItem) {
        translate(item.result.source)
    }

    public func deleteHistory(id: UUID) {
        history.removeAll { $0.id == id }
        if persistsHistory { HistoryStore.save(history) }
    }

    public func pruneHistory() {
        history = HistoryStore.prune(history)
        if persistsHistory { HistoryStore.save(history) }
    }

    public func clearHistory() {
        history.removeAll()
        if persistsHistory { HistoryStore.save(history) }
    }

    public func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func record(_ result: TranslationResult) {
        guard HistoryStore.isEnabled else { return }
        history = HistoryStore.prune(history)
        history.removeAll { $0.result.source == result.source }
        history.insert(HistoryItem(result: result), at: 0)
        history = Array(history.prefix(100))
        if persistsHistory { HistoryStore.save(history) }
    }
}

enum HistoryStore {
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: "saveHistory") == nil || UserDefaults.standard.bool(forKey: "saveHistory") }
    private static let key = "LingoPane.translationHistory.v1"
    private static var store: SnapshotStore<[HistoryItem]> {
        SnapshotStore(url: URL.applicationSupportDirectory.appendingPathComponent("LingoPane/history-v2.json"))
    }

    static func load() -> [HistoryItem] {
        if let saved = store.load() {
            let items = prune(saved)
            save(items)
            return items
        }
        guard let data = UserDefaults.standard.data(forKey: key),
              let legacy = try? JSONDecoder().decode([HistoryItem].self, from: data) else { return [] }
        let items = prune(legacy)
        do {
            try store.save(items)
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            // Keep the legacy copy until migration has succeeded.
        }
        return items
    }

    static func prune(_ items: [HistoryItem], now: Date = .now, days: Int? = nil) -> [HistoryItem] {
        let retention = days ?? (UserDefaults.standard.object(forKey: "historyRetention") == nil ? 90 : UserDefaults.standard.integer(forKey: "historyRetention"))
        return Array(items.filter { retention <= 0 || now.timeIntervalSince($0.createdAt) < Double(retention) * 86400 }.prefix(100))
    }

    static func save(_ items: [HistoryItem]) {
        do { try store.save(items) }
        catch { Diagnostics.storageFailure("history_write") }
    }
}
