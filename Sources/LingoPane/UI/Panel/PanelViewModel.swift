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
    @Published public var isPinned = false
    @Published public var isExpanded = false
    @Published public var pinnedAnnotationID: UUID?
    @Published public var selectedAlternativeID: UUID?

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
        phase = .loading
        isExpanded = false
        pinnedAnnotationID = nil
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

    public func handleEscape() {
        if pinnedAnnotationID != nil {
            pinnedAnnotationID = nil
        } else if isExpanded {
            isExpanded = false
        } else if !isPinned {
            closeAction?()
        }
    }
}
