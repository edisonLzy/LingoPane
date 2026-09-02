import SwiftUI

/// 全局持久化设置管理器（采用 Swift 5.9+ / 6 @Observable 宏）
@Observable
public final class SettingsManager: @unchecked Sendable {
    public static let shared = SettingsManager()

    private let userDefaults = UserDefaults.standard

    // Keys
    private let apiKeyKey = "translator.api_key"
    private let hostKey = "translator.host"
    private let basePathKey = "translator.base_path"
    private let modelKey = "translator.model"
    private let appearanceKey = "translator.appearance"

    public var apiKey: String {
        didSet {
            userDefaults.set(apiKey, forKey: apiKeyKey)
        }
    }

    public var host: String {
        didSet {
            userDefaults.set(host, forKey: hostKey)
        }
    }

    public var basePath: String {
        didSet {
            userDefaults.set(basePath, forKey: basePathKey)
        }
    }

    public var model: String {
        didSet {
            userDefaults.set(model, forKey: modelKey)
        }
    }

    public var isLightMode: Bool {
        didSet {
            userDefaults.set(isLightMode, forKey: appearanceKey)
        }
    }

    public init() {
        // 优先读取环境变量 MINIMAX_API_KEY，其次读取本地持久化缓存
        let envKey = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] ?? ""
        let savedKey = userDefaults.string(forKey: apiKeyKey) ?? ""
        self.apiKey = !savedKey.isEmpty ? savedKey : envKey

        self.host = userDefaults.string(forKey: hostKey) ?? "api.minimax.cn"
        self.basePath = userDefaults.string(forKey: basePathKey) ?? "/v1"
        self.model = userDefaults.string(forKey: modelKey) ?? "MiniMax-M3"
        self.isLightMode = userDefaults.bool(forKey: appearanceKey)
    }

    public var hasValidAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
