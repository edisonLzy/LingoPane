import Foundation

public struct LocalClassifier: Sendable {
    public init() {}

    public func classify(_ text: String) -> Classification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars
        let chineseCount = scalars.filter { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }.count

        if chineseCount > max(0, scalars.count / 5) {
            return Classification(language: .chinese, kind: .chinese)
        }

        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace })
        let sentencePunctuation = CharacterSet(charactersIn: ".!?;。！？；")
        let hasSentencePunctuation = trimmed.unicodeScalars.contains { sentencePunctuation.contains($0) }
        let kind: ContentKind = tokens.count <= 5 && !hasSentencePunctuation ? .word : .sentence
        return Classification(language: .english, kind: kind)
    }
}
