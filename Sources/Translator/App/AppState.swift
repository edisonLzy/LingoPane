import SwiftUI
import AppKit

/// 全局应用状态（集成 PRD 完整生命周期：快捷键划词、本地分类、两级分析、SQLite 缓存与悬浮浮窗）
@Observable
@MainActor
public final class AppState {
    public static let shared = AppState()

    public var inputText: String = ""
    public var currentResult: AnalysisStatus = .idle
    public var currentPRDResult: AnalysisResult? = nil
    public var toastMessage: String? = nil
    public var showSettings: Bool = false
    public var isAccessibilityGranted: Bool = true

    public var currentResultID: String {
        switch currentResult {
        case .idle: return "idle"
        case .loading(let q): return "loading_\(q)"
        case .success: return "success_\(currentPRDResult?.source.text.prefix(15) ?? "")"
        case .error(let e): return "error_\(e)"
        }
    }

    private var activeTask: Task<Void, Never>? = nil

    public let settings: SettingsManager
    private let classifier = LocalClassifier()
    private let cacheStore = AnalysisCacheStore.shared
    private var openAIClient: OpenAIClient
    private var miniMaxService: MiniMaxTranslationService
    private let mockService = MockTranslationService()

    public init(settings: SettingsManager = .shared) {
        self.settings = settings
        self.isAccessibilityGranted = SelectionProvider.shared.isAccessibilityGranted

        let config = OpenAIConfiguration(
            token: settings.apiKey,
            host: settings.host,
            basePath: settings.basePath
        )
        let client = OpenAIClient(configuration: config)
        self.openAIClient = client
        self.miniMaxService = MiniMaxTranslationService(client: client, model: settings.model)
    }

    public func reloadService() {
        let config = OpenAIConfiguration(
            token: settings.apiKey,
            host: settings.host,
            basePath: settings.basePath
        )
        self.openAIClient = OpenAIClient(configuration: config)
        self.miniMaxService = MiniMaxTranslationService(client: openAIClient, model: settings.model)
    }

    // MARK: - 全局快捷键划词触发入口 (⌥ Space)
    public func triggerSelectionTranslation() {
        isAccessibilityGranted = SelectionProvider.shared.isAccessibilityGranted

        Task {
            let selectedText = await SelectionProvider.shared.getSelectedText()
            if let text = selectedText, !text.isEmpty {
                self.inputText = text
                self.processInput(text, isFromSelection: true)
            } else {
                // 未获取到选中文本，直接展示空白输入浮窗
                self.inputText = ""
                self.currentResult = .idle
                self.currentPRDResult = nil
                FloatingPanelController.shared.showNearMouse(with: self)
            }
        }
    }

    // MARK: - 核心分析调度 (Fast Analyze + 本地缓存)
    public func processInput(_ text: String, isFromSelection: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            currentResult = .idle
            currentPRDResult = nil
            return
        }

        activeTask?.cancel()
        currentResult = .loading(trimmed)

        if isFromSelection {
            FloatingPanelController.shared.showNearMouse(with: self)
        }

        activeTask = Task {
            // 1. 0ms 本地分类与长度校验 (PRD 8 & 13.5 节)
            let classification = classifier.classify(trimmed)

            // 2. 本地缓存命中检查 (PRD 15 节，目标 <100ms 秒出)
            let targetLang: Language = (classification.language == .en) ? .zh : .en
            let cacheKey = await cacheStore.makeKey(
                text: trimmed,
                sourceLang: classification.language,
                targetLang: targetLang,
                contentType: classification.contentType,
                level: "fast",
                model: settings.model
            )

            if let cached = await cacheStore.get(key: cacheKey) {
                if !Task.isCancelled {
                    self.currentPRDResult = cached
                    self.currentResult = .success
                }
                return
            }

            // 3. Fast Analyze 大模型或离线高质量 Mock 请求
            do {
                let result: AnalysisResult
                if settings.hasValidAPIKey {
                    result = try await miniMaxService.fastAnalyze(text: trimmed, classification: classification)
                } else {
                    result = try await mockService.fastAnalyze(text: trimmed, classification: classification)
                }

                // 写入本地缓存
                await cacheStore.set(key: cacheKey, result: result)

                if !Task.isCancelled {
                    self.currentPRDResult = result
                    self.currentResult = .success
                }
            } catch {
                if !Task.isCancelled {
                    self.currentResult = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - 按需深入分析 (Deep Analyze)
    public func performDeepAnalyze() {
        guard let existing = currentPRDResult else { return }
        let text = existing.source.text

        Task {
            let targetLang: Language = (existing.source.language == .en) ? .zh : .en
            let deepCacheKey = await cacheStore.makeKey(
                text: text,
                sourceLang: existing.source.language,
                targetLang: targetLang,
                contentType: existing.source.contentType,
                level: "deep",
                model: settings.model
            )

            if let cachedDeep = await cacheStore.get(key: deepCacheKey) {
                self.currentPRDResult = cachedDeep
                return
            }

            do {
                let deepResult: AnalysisResult
                if settings.hasValidAPIKey {
                    deepResult = try await miniMaxService.deepAnalyze(text: text, existingResult: existing)
                } else {
                    deepResult = try await mockService.deepAnalyze(text: text, existingResult: existing)
                }

                await cacheStore.set(key: deepCacheKey, result: deepResult)
                self.currentPRDResult = deepResult
            } catch {
                print("Deep analysis error: \(error.localizedDescription)")
            }
        }
    }

    public func loadPreset(_ text: String) {
        self.inputText = text
        processInput(text)
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }

    public func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast("已复制到剪贴板")
        #endif
    }
}

public enum AnalysisStatus: Sendable {
    case idle
    case loading(String)
    case success
    case error(String)
}
