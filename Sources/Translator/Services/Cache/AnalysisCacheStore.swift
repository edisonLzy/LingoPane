import Foundation
import CryptoKit

/// 本地持久化极速缓存库（遵循 PRD 第 15 节规范）
public actor AnalysisCacheStore {
    public static let shared = AnalysisCacheStore()

    private var memoryCache: [String: AnalysisResult] = [:]
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("com.zhiyu.translator/cache", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// 生成 PRD 15 节标准规范的缓存 Key
    public func makeKey(
        text: String,
        sourceLang: Language,
        targetLang: Language,
        contentType: ContentType,
        level: String, // "fast" or "deep"
        model: String
    ) -> String {
        let raw = "\(text)|\(sourceLang.rawValue)|\(targetLang.rawValue)|\(contentType.rawValue)|\(level)|\(model)|v1.0"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 读取缓存（优先内存缓存，其次本地磁盘）
    public func get(key: String) -> AnalysisResult? {
        if let memHit = memoryCache[key] {
            return memHit
        }

        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        if let result = try? decoder.decode(AnalysisResult.self, from: data) {
            memoryCache[key] = result
            return result
        }

        return nil
    }

    /// 保存缓存（内存 + 磁盘持久化）
    public func set(key: String, result: AnalysisResult) {
        memoryCache[key] = result

        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(result) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// 清理所有缓存
    public func clearAll() {
        memoryCache.removeAll()
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
