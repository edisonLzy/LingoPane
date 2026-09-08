import AppKit
import Foundation

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var query = ""
    @Published public private(set) var history: [HistoryItem]
    @Published public var isWorking = false
    @Published public var lastError: PanelFailure?

    public let classifier = LocalClassifier()
    private let service: any TranslationService
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init(service: any TranslationService = MockTranslationService()) {
        self.service = service
        self.history = HistoryStore.load()
    }

    public func translate(
        _ rawText: String,
        near anchor: NSPoint? = nil,
        classificationOverride: Classification? = nil
    ) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lastError = .noSelection
            StatusBarController.shared.showPopover()
            return
        }

        query = text
        let classification = classificationOverride ?? classifier.classify(text)
        let model = FloatingPanelCoordinator.shared.presentLoading(
            source: text,
            classification: classification,
            near: anchor ?? NSEvent.mouseLocation
        )

        guard text.count <= 500 else {
            let failure = PanelFailure.overlong(limit: 500)
            lastError = failure
            model.fail(failure)
            return
        }

        tasks[model.id]?.cancel()
        isWorking = true
        lastError = nil

        model.retryAction = { [weak self, weak model] in
            guard let self, let model else { return }
            self.tasks[model.id]?.cancel()
            self.translate(text, near: model.windowAnchor, classificationOverride: classification)
        }

        tasks[model.id] = Task { [weak self, weak model, service] in
            do {
                let result = try await service.analyze(text, classification: classification)
                guard !Task.isCancelled, let self, let model else { return }
                model.succeed(result)
                self.record(result)
                self.isWorking = false
                self.tasks[model.id] = nil
            } catch is CancellationError {
                return
            } catch {
                guard let self, let model else { return }
                let failure = (error as? PanelFailure) ?? .message(error.localizedDescription)
                model.fail(failure)
                self.lastError = failure
                self.isWorking = false
                self.tasks[model.id] = nil
            }
        }
    }

    public func triggerSelectionTranslation() {
        if !SelectionProvider.shared.isAccessibilityGranted {
            lastError = .accessibilityPermission
            SelectionProvider.shared.requestAccessibilityPermission()
            StatusBarController.shared.showPopover()
            return
        }

        if let selected = SelectionProvider.shared.selectedText() {
            translate(selected)
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
        HistoryStore.save(history)
    }

    public func clearHistory() {
        history.removeAll()
        HistoryStore.save(history)
    }

    public func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func record(_ result: TranslationResult) {
        history.removeAll { $0.result.source == result.source }
        history.insert(HistoryItem(result: result), at: 0)
        history = Array(history.prefix(100))
        HistoryStore.save(history)
    }
}

private enum HistoryStore {
    private static let key = "LingoPane.translationHistory.v1"

    static func load() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([HistoryItem].self, from: data)) ?? []
    }

    static func save(_ items: [HistoryItem]) {
        guard UserDefaults.standard.bool(forKey: "saveHistory") || UserDefaults.standard.object(forKey: "saveHistory") == nil,
              let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
