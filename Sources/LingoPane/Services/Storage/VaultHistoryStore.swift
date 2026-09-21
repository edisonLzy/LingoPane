import Foundation

struct VaultHistoryStore {
    static let payloadStart = "%%\nlingopane-payload-v1:start"
    static let payloadEnd = "lingopane-payload-v1:end\n%%"
    static let userStart = "<!-- lingopane-user-notes:start -->"
    static let userEnd = "<!-- lingopane-user-notes:end -->"

    private static let legacyPayloadStart = "<!-- lingopane-payload-v1:start -->"
    private static let legacyPayloadEnd = "<!-- lingopane-payload-v1:end -->"

    let rootURL: URL
    private let fileManager: FileManager
    private let movesDeletedItemsToTrash: Bool

    init(
        rootURL: URL,
        fileManager: FileManager = .default,
        movesDeletedItemsToTrash: Bool = true
    ) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
        self.movesDeletedItemsToTrash = movesDeletedItemsToTrash
    }

    var itemsURL: URL { rootURL.appendingPathComponent("Items", isDirectory: true) }
    var dailyURL: URL { rootURL.appendingPathComponent("Daily", isDirectory: true) }

    func load() -> [HistoryItem] {
        var items: [HistoryItem] = []
        for url in markdownURLs(in: itemsURL) {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  let decoded = decodePayload(in: text) else { continue }
            items.append(decoded.item)
            if decoded.usesLegacyMarkers {
                try? migrateLegacyPayload(in: text, decoded: decoded, at: url)
            }
        }
        return items.sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    @discardableResult
    func save(_ item: HistoryItem) throws -> URL {
        let existingURL = findItemURL(id: item.id)
        let destination = existingURL ?? generatedURL(for: item)
        let existingText = try? String(contentsOf: destination, encoding: .utf8)
        let userNotes = existingText.flatMap(extractUserNotes) ?? "\n## 我的笔记\n\n"
        let markdown = try render(item, userNotes: userNotes)

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(markdown.utf8).write(to: destination, options: .atomic)
        return destination
    }

    func appendEncounter(for item: HistoryItem, at date: Date = .now) throws {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"

        let day = dayFormatter.string(from: date)
        let url = dailyURL.appendingPathComponent(day + ".md")
        try fileManager.createDirectory(at: dailyURL, withIntermediateDirectories: true)

        let itemURL = findItemURL(id: item.id) ?? generatedURL(for: item)
        let noteName = itemURL.deletingPathExtension().lastPathComponent
        let source = singleLine(item.result.source).replacingOccurrences(of: "|", with: "\\|")
        let scene = item.lastScene.rawValue
        let entry = "- \(timeFormatter.string(from: date)) [[\(noteName)|\(source)]] · \(scene)\n"

        var text: String
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            text = existing
            if !text.hasSuffix("\n") { text += "\n" }
            text += entry
        } else {
            text = """
            ---
            schema: lingopane-daily-v1
            date: \(day)
            tags:
              - lingopane/daily
            ---

            # \(day)

            \(entry)
            """
        }
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    func delete(id: UUID) throws {
        guard let url = findItemURL(id: id) else { return }
        try discard(url)
    }

    func deleteAll() throws {
        for url in markdownURLs(in: itemsURL) where decodeItem(at: url) != nil {
            try discard(url)
        }
        for url in markdownURLs(in: dailyURL) {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.contains("schema: lingopane-daily-v1") else { continue }
            try discard(url)
        }
    }

    private func generatedURL(for item: HistoryItem) -> URL {
        let direction = item.result.language == .chinese ? "zh-en" : "en-zh"
        let category: String
        switch item.result.kind {
        case .chinese:
            category = "expressions"
        case .sentence:
            category = "sentences"
        case .word:
            let tokens = item.result.source.split(whereSeparator: \Character.isWhitespace)
            category = tokens.count > 1 ? "phrases" : "words"
        }
        let shortID = item.id.uuidString.prefix(8).lowercased()
        let filename = "\(slug(item.result.source))--\(shortID).md"
        return itemsURL
            .appendingPathComponent(direction, isDirectory: true)
            .appendingPathComponent(category, isDirectory: true)
            .appendingPathComponent(filename)
    }

    private func findItemURL(id: UUID) -> URL? {
        let suffix = "--\(id.uuidString.prefix(8).lowercased()).md"
        return markdownURLs(in: itemsURL).first { url in
            guard url.lastPathComponent.lowercased().hasSuffix(suffix) else { return false }
            return decodeItem(at: url)?.id == id
        }
    }

    private func markdownURLs(in directory: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "md" {
            urls.append(url)
        }
        return urls
    }

    private func decodeItem(at url: URL) -> HistoryItem? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return decodePayload(in: text)?.item
    }

    private func decodePayload(in text: String) -> DecodedPayload? {
        if let decoded = decodePayload(
            in: text,
            startMarker: Self.payloadStart,
            endMarker: Self.payloadEnd,
            usesLegacyMarkers: false
        ) {
            return decoded
        }
        return decodePayload(
            in: text,
            startMarker: Self.legacyPayloadStart,
            endMarker: Self.legacyPayloadEnd,
            usesLegacyMarkers: true
        )
    }

    private func decodePayload(
        in text: String,
        startMarker: String,
        endMarker: String,
        usesLegacyMarkers: Bool
    ) -> DecodedPayload? {
        guard let start = text.range(of: startMarker),
              let end = text.range(of: endMarker, range: start.upperBound..<text.endIndex) else {
            return nil
        }
        let encoded = String(text[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let item = try? decoder.decode(HistoryItem.self, from: data) else { return nil }
        return DecodedPayload(
            item: item,
            encoded: encoded,
            blockRange: start.lowerBound..<end.upperBound,
            usesLegacyMarkers: usesLegacyMarkers
        )
    }

    private func migrateLegacyPayload(
        in text: String,
        decoded: DecodedPayload,
        at url: URL
    ) throws {
        let replacement = "\(Self.payloadStart)\n\(decoded.encoded)\n\(Self.payloadEnd)"
        var migrated = text
        migrated.replaceSubrange(decoded.blockRange, with: replacement)
        try Data(migrated.utf8).write(to: url, options: .atomic)
    }

    private func render(_ item: HistoryItem, userNotes: String) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(item).base64EncodedString()
        let result = item.result
        let title = singleLine(result.source)
        let sourceLanguage = result.language == .chinese ? "zh" : "en"
        let targetLanguage = result.language == .chinese ? "en" : "zh"
        let scenes = item.scenes.map { "  - \(yamlString($0.rawValue))" }.joined(separator: "\n")
        let tags = ["lingopane/item", "lingopane/\(result.kind.rawValue)"]
            .map { "  - \($0)" }.joined(separator: "\n")

        var body = """
        ---
        schema: lingopane-item-v1
        id: \(yamlString(item.id.uuidString.lowercased()))
        source: \(yamlString(result.source))
        source_language: \(sourceLanguage)
        target_language: \(targetLanguage)
        kind: \(result.kind.rawValue)
        scenes:
        \(scenes)
        created_at: \(iso8601(item.createdAt))
        updated_at: \(iso8601(item.updatedAt))
        last_seen_at: \(iso8601(item.lastSeenAt))
        encounter_count: \(item.encounterCount)
        tags:
        \(tags)
        ---

        # \(title)

        ## 原文

        \(result.source)

        ## 译文

        \(result.primaryResult)
        """

        appendOptionalSection("音标", result.ipa, to: &body)
        appendOptionalSection("语境释义", result.contextMeaning, to: &body)
        appendPairsSection("词义", result.meanings.map { ($0.partOfSpeech, $0.meaning) }, to: &body)
        appendTriplesSection("替代表达", result.alternatives.map { ($0.label, $0.text, $0.note) }, to: &body)
        appendPairsSection("关键词映射", result.keywordMappings.map { ($0.source, $0.target) }, to: &body)
        appendListSection("表达说明", result.expressionNotes, to: &body)
        appendPairsSection("常见搭配", result.collocations.map { ($0.phrase, $0.meaning) }, to: &body)
        appendPairsSection("易混词", result.confusingWords?.map { ($0.phrase, $0.meaning) } ?? [], to: &body)
        appendListSection("词形", result.wordForms, to: &body)
        appendPairsSection("例句", result.examples.map { ($0.english, $0.chinese) }, to: &body)
        appendOptionalSection("句子主干", result.sentenceSkeleton, to: &body)
        appendTriplesSection("语法标注", result.annotations.map { ($0.role.title, $0.text, $0.explanation) }, to: &body)
        appendTriplesSection("从句", result.clauses.map { ($0.type, $0.text, $0.explanation) }, to: &body)
        appendListSection("重点语法", result.grammarPoints, to: &body)
        appendOptionalSection("翻译说明", result.translationNote, to: &body)

        body += "\n\n\(Self.userStart)\(userNotes)\n\(Self.userEnd)\n\n"
        body += "\(Self.payloadStart)\n\(payload)\n\(Self.payloadEnd)\n"
        return body
    }

    private func extractUserNotes(from text: String) -> String? {
        guard let start = text.range(of: Self.userStart),
              let end = text.range(of: Self.userEnd, range: start.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[start.upperBound..<end.lowerBound])
    }

    private func appendOptionalSection(_ title: String, _ value: String?, to body: inout String) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        body += "\n\n## \(title)\n\n\(value)"
    }

    private func appendListSection(_ title: String, _ values: [String], to body: inout String) {
        guard !values.isEmpty else { return }
        body += "\n\n## \(title)\n\n"
        body += values.map { "- \($0)" }.joined(separator: "\n")
    }

    private func appendPairsSection(_ title: String, _ values: [(String, String)], to body: inout String) {
        guard !values.isEmpty else { return }
        body += "\n\n## \(title)\n\n"
        body += values.map { "- **\($0.0)**：\($0.1)" }.joined(separator: "\n")
    }

    private func appendTriplesSection(_ title: String, _ values: [(String, String, String)], to body: inout String) {
        guard !values.isEmpty else { return }
        body += "\n\n## \(title)\n\n"
        body += values.map { "- **\($0.0)**：\($0.1) — \($0.2)" }.joined(separator: "\n")
    }

    private func yamlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func singleLine(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func slug(_ value: String) -> String {
        var result = ""
        var previousWasSeparator = false
        for character in singleLine(value).lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("-")
                previousWasSeparator = true
            }
            if result.count >= 48 { break }
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "translation" : result
    }

    private func discard(_ url: URL) throws {
        if movesDeletedItemsToTrash {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
        } else {
            try fileManager.removeItem(at: url)
        }
    }

    private struct DecodedPayload {
        let item: HistoryItem
        let encoded: String
        let blockRange: Range<String.Index>
        let usesLegacyMarkers: Bool
    }
}

enum HistoryStore {
    static let defaultVaultPath = "/Users/zhiyu/Desktop/个人/obsidian-vault/英语/lingo-pane"
    private static let pathKey = "vaultHistoryPath"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "saveHistory") == nil
            || UserDefaults.standard.bool(forKey: "saveHistory")
    }

    static var configuredPath: String {
        let saved = UserDefaults.standard.string(forKey: pathKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return saved?.isEmpty == false ? saved! : defaultVaultPath
    }

    static func setConfiguredPath(_ path: String) {
        UserDefaults.standard.set(path.trimmingCharacters(in: .whitespacesAndNewlines), forKey: pathKey)
    }

    static func load() -> [HistoryItem] {
        store.load()
    }

    static func save(_ item: HistoryItem, recordEncounter: Bool, at date: Date = .now) {
        do {
            try store.save(item)
            if recordEncounter { try store.appendEncounter(for: item, at: date) }
        } catch {
            Diagnostics.storageFailure("vault_history_write")
        }
    }

    static func delete(id: UUID) {
        do { try store.delete(id: id) }
        catch { Diagnostics.storageFailure("vault_history_delete") }
    }

    static func clear() {
        do { try store.deleteAll() }
        catch { Diagnostics.storageFailure("vault_history_clear") }
    }

    private static var store: VaultHistoryStore {
        let expanded = NSString(string: configuredPath).expandingTildeInPath
        return VaultHistoryStore(rootURL: URL(fileURLWithPath: expanded, isDirectory: true))
    }
}
