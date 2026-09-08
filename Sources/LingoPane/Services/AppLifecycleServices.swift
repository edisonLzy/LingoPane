import AppKit
import ServiceManagement
import OSLog

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var message: String?

    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            enabled = SMAppService.mainApp.status == .enabled
            message = SMAppService.mainApp.status == .requiresApproval ? "请在系统设置的登录项中允许 LingoPane。" : nil
        } catch {
            enabled = SMAppService.mainApp.status == .enabled
            message = "登录项设置失败：" + error.localizedDescription
        }
    }
}

struct ReleaseInfo: Decodable, Sendable {
    let tag_name: String
    let html_url: URL
}

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var checking = false
    @Published private(set) var message: String?
    @Published private(set) var releaseURL: URL?

    func check() async {
        guard !checking else { return }
        checking = true
        releaseURL = nil
        defer { checking = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/edisonLzy/LingoPane/releases/latest")!)
            request.timeoutInterval = 15
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 404 { message = "目前尚无公开发布版本"; return }
            guard status == 200 else { throw PanelFailure.message("更新服务暂不可用") }
            let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
            let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
            if latest.compare(version, options: .numeric) == .orderedDescending,
               release.html_url.scheme == "https", release.html_url.host == "github.com" {
                message = "发现新版本 " + release.tag_name
                releaseURL = release.html_url
            } else {
                message = "当前已是最新版本（" + version + "）"
            }
        } catch { message = "检查更新失败，请稍后重试" }
    }
}

enum Diagnostics {
    private static let logger = Logger(subsystem: "com.lingopane.app", category: "performance")
    static func storageFailure(_ event: String) {
        logger.error("\(event, privacy: .public) failed; previous snapshot preserved")
    }

    static func duration(_ event: String, since start: Date) {
        let milliseconds = Date().timeIntervalSince(start) * 1000
        logger.info("\(event, privacy: .public) duration_ms=\(milliseconds, privacy: .public)")
    }
}
