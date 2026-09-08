import AppKit
import Foundation

@MainActor
public final class PanelViewModel: ObservableObject, Identifiable {
    public enum Phase {
        case loading
        case ready(TranslationResult)
        case failed(PanelFailure)
    }

    public let id = UUID()
    @Published public var source: String
    @Published public var classification: Classification
    @Published public var phase: Phase = .loading
    @Published public var scene: ExpressionScene = .general
    @Published public var deepLoading = false
    @Published public var deepFailure: String?
    @Published public var deepReady = false
    @Published public var notice: String?
    @Published public var isCollapsed = false
    public var deepTask: Task<Void, Never>?
    public var resizeAction: ((CGFloat) -> Void)?
    public var deepAction: (() -> Void)?
    public var sceneAction: ((ExpressionScene) -> Void)?
    @Published public var isPinned = false
    @Published public var isExpanded = false
    @Published public var showNestedStructures = false
    @Published public private(set) var hoveredAnnotationID: UUID?
    @Published public private(set) var focusedAnnotationID: UUID?
    @Published private var dismissedAnnotationID: UUID?
    private var hoverTask: Task<Void, Never>?
    @Published public var pinnedAnnotationID: UUID?
    @Published public var selectedAlternativeID: UUID?

    public var cancelAction: (() -> Void)?
    public var closeAction: (() -> Void)?
    public var pinAction: (() -> Void)?
    public var retryAction: (() -> Void)?
    public var switchKindAction: ((ContentKind) -> Void)?
    public var windowAnchor = NSPoint.zero

    public init(source: String, classification: Classification) {
        self.source = source
        self.classification = classification
    }

    public var result: TranslationResult? {
        if case .ready(let result) = phase { return result }
        return nil
    }

    public func start(source: String, classification: Classification) {
        self.source = source
        self.classification = classification
        deepTask?.cancel()
        deepTask = nil
        deepLoading = false
        deepFailure = nil
        deepReady = false
        notice = nil
        isCollapsed = false
        phase = .loading
        retryAction = nil
        isExpanded = false
        resetAnnotations()
        showNestedStructures = false
        selectedAlternativeID = nil
    }

    public func succeed(_ result: TranslationResult) {
        source = result.source
        classification = Classification(language: result.language, kind: result.kind)
        phase = .ready(result)
        if result.kind == .sentence, UserDefaults.standard.bool(forKey: "expandGrammarByDefault") {
            isExpanded = true
        }
    }

    public func fail(_ failure: PanelFailure) {
        phase = .failed(failure)
    }

    public var activeAnnotationID: UUID? {
        let active = pinnedAnnotationID ?? focusedAnnotationID ?? hoveredAnnotationID
        return active == dismissedAnnotationID ? nil : active
    }

    public func focusAnnotation(_ id: UUID?) {
        if focusedAnnotationID != id { dismissedAnnotationID = nil }
        focusedAnnotationID = id
    }

    public func hoverAnnotation(_ id: UUID?) {
        hoverTask?.cancel()
        if id == nil {
            // Resizing the floating panel can briefly invalidate AppKit tracking
            // areas. Keep the card alive through that synthetic mouse-exit so it
            // does not repeatedly disappear and reappear under a stationary cursor.
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(140))
                guard !Task.isCancelled else { return }
                self?.hoveredAnnotationID = nil
                self?.dismissedAnnotationID = nil
            }
            return
        }
        guard hoveredAnnotationID != id else { return }
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            self?.hoveredAnnotationID = id
        }
    }

    public func toggleAnnotation(_ id: UUID) {
        if pinnedAnnotationID == id {
            dismissAnnotation()
        } else {
            dismissedAnnotationID = nil
            pinnedAnnotationID = id
        }
    }

    public func resetAnnotations() {
        hoverTask?.cancel()
        pinnedAnnotationID = nil
        hoveredAnnotationID = nil
        focusedAnnotationID = nil
        dismissedAnnotationID = nil
    }

    private func dismissAnnotation() {
        hoverTask?.cancel()
        dismissedAnnotationID = activeAnnotationID
        pinnedAnnotationID = nil
        hoveredAnnotationID = nil
    }

    public func handleEscape() {
        if activeAnnotationID != nil {
            dismissAnnotation()
        } else if isExpanded {
            isExpanded = false
            resetAnnotations()
        } else if !isPinned {
            closeAction?()
        }
    }
}
