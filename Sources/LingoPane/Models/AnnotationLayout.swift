import Foundation

/// Resolves visibility and native UTF-16 ranges without changing any source text.
struct AnnotationLayout {
    let source: String
    let annotations: [GrammarAnnotation]

    init(source: String, annotations: [GrammarAnnotation]) {
        self.source = source
        var seen = Set<String>()
        self.annotations = annotations.filter {
            $0.isValid(in: source) && seen.insert("\($0.start):\($0.end):\($0.role.rawValue)").inserted
        }.sorted {
            $0.start == $1.start ? $0.end > $1.end : $0.start < $1.start
        }
    }

    func depth(of annotation: GrammarAnnotation) -> Int {
        let parents = annotations.filter {
            $0.role == .clause && $0.start <= annotation.start && $0.end >= annotation.end
                && ($0.start < annotation.start || $0.end > annotation.end)
        }.count
        return parents + (annotation.role == .clause ? 1 : 0)
    }

    func visible(includeNested: Bool) -> [GrammarAnnotation] {
        annotations.filter { includeNested || depth(of: $0) <= 1 }
    }

    var hasNested: Bool { annotations.contains { depth(of: $0) > 1 } }

    func nativeRange(of annotation: GrammarAnnotation) -> NSRange? {
        guard annotation.isValid(in: source) else { return nil }
        let lower = source.index(source.startIndex, offsetBy: annotation.start)
        let upper = source.index(source.startIndex, offsetBy: annotation.end)
        return NSRange(lower..<upper, in: source)
    }

    /// At an overlap, interacting with the most specific component wins.
    func annotation(atUTF16 offset: Int, includeNested: Bool) -> GrammarAnnotation? {
        visible(includeNested: includeNested).filter {
            guard let range = nativeRange(of: $0) else { return false }
            return NSLocationInRange(offset, range)
        }.min {
            let left = $0.end - $0.start
            let right = $1.end - $1.start
            if left == right { return $0.role != .clause && $1.role == .clause }
            return left < right
        }
    }
}
