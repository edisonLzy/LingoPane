import Foundation

/// 类似于 MacPaw/OpenAI 的配置类
public struct OpenAIConfiguration: Sendable {
    public var token: String
    public var host: String
    public var basePath: String
    public var scheme: String
    public var timeoutInterval: TimeInterval

    public init(
        token: String = "",
        host: String = "api.minimax.cn",
        basePath: String = "/v1",
        scheme: String = "https",
        timeoutInterval: TimeInterval = 60.0
    ) {
        self.token = token
        self.host = host
        self.basePath = basePath
        self.scheme = scheme
        self.timeoutInterval = timeoutInterval
    }

    /// 构造完整的 API URL
    public func url(for path: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        let trimmedBasePath = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + (trimmedBasePath.isEmpty ? trimmedPath : "\(trimmedBasePath)/\(trimmedPath)")
        return components.url
    }
}
