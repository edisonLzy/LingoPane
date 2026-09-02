import Foundation

/// 严格按照 PRD 10.5 规范执行的服务端/客户端双向数据校验器
public struct GrammarValidator: Sendable {
    public init() {}

    /// 校验并净化 AnalysisResult
    public func validateAndSanitize(
        result: AnalysisResult,
        sourceText: String
    ) -> AnalysisResult {
        // 1. 如果没有句法结构信息，直接安全返回
        guard let sentenceData = result.sentenceAnalysis else {
            return result
        }

        let utf16 = sourceText.utf16
        let textLength = utf16.count

        // 2. 校验所有的 GrammarChunks
        var validChunks: [GrammarChunk] = []
        var hasChunkError = false

        for chunk in sentenceData.chunks {
            // 检查边界
            guard chunk.start >= 0, chunk.end > chunk.start, chunk.end <= textLength else {
                hasChunkError = true
                continue
            }

            // 严格对齐 UTF-16 文本切片
            let startIdx = utf16.index(utf16.startIndex, offsetBy: chunk.start)
            let endIdx = utf16.index(utf16.startIndex, offsetBy: chunk.end)
            if let subStr = String(utf16[startIdx..<endIdx]) {
                if subStr == chunk.text {
                    validChunks.append(chunk)
                } else {
                    hasChunkError = true
                }
            } else {
                hasChunkError = true
            }
        }

        // 3. 校验 Clauses
        var validClauses: [Clause] = []
        if let clauses = sentenceData.clauses {
            for clause in clauses {
                guard clause.start >= 0, clause.end > clause.start, clause.end <= textLength else {
                    continue
                }
                let startIdx = utf16.index(utf16.startIndex, offsetBy: clause.start)
                let endIdx = utf16.index(utf16.startIndex, offsetBy: clause.end)
                if let subStr = String(utf16[startIdx..<endIdx]), subStr == clause.text {
                    validClauses.append(clause)
                }
            }
        }

        // 4. 校验 GrammarPoints
        var validPoints: [GrammarPoint] = []
        if let points = sentenceData.grammarPoints {
            for point in points {
                guard point.start >= 0, point.end > point.start, point.end <= textLength else {
                    continue
                }
                validPoints.append(point)
            }
        }

        // 5. 句子主干校验（必须非空）
        let skeleton = sentenceData.skeleton.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? sourceText
            : sentenceData.skeleton

        var warnings = result.warnings ?? []
        if hasChunkError {
            warnings.append("部分语法切片与原文索引未能完全吻合，已进行安全净化过滤。")
        }

        let sanitizedSentence = SentenceAnalysisData(
            skeleton: skeleton,
            chunks: validChunks,
            clauses: validClauses.isEmpty ? nil : validClauses,
            grammarPoints: validPoints.isEmpty ? nil : validPoints,
            expressionNotes: sentenceData.expressionNotes
        )

        return AnalysisResult(
            schemaVersion: result.schemaVersion,
            source: result.source,
            translation: result.translation,
            pronunciation: result.pronunciation,
            wordAnalysis: result.wordAnalysis,
            sentenceAnalysis: sanitizedSentence,
            warnings: warnings.isEmpty ? nil : warnings
        )
    }
}
