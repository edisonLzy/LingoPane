import SwiftUI

/// 句子成分类型（对齐 Apple HIG 语法色彩标准）
public enum SyntaxRole: String, Codable, CaseIterable, Sendable {
    case subject = "subject"
    case predicate = "predicate"
    case object = "object"
    case adverbial = "adverbial"
    case clause = "clause"
    case other = "other"

    public var title: String {
        switch self {
        case .subject: return "主语 (Subject)"
        case .predicate: return "谓语 (Predicate)"
        case .object: return "宾语/表语 (Object/Predicative)"
        case .adverbial: return "状语 (Adverbial)"
        case .clause: return "从句 (Clause)"
        case .other: return "其他"
        }
    }

    public var shortName: String {
        switch self {
        case .subject: return "主语"
        case .predicate: return "谓语"
        case .object: return "宾语/表语"
        case .adverbial: return "状语"
        case .clause: return "从句"
        case .other: return "其他"
        }
    }

    public var color: Color {
        switch self {
        case .subject:
            return Color(red: 0.16, green: 0.59, blue: 1.00) // #2997FF (系统蓝)
        case .predicate:
            return Color(red: 1.00, green: 0.62, blue: 0.04) // #FF9F0A (系统橙)
        case .object:
            return Color(red: 0.19, green: 0.82, blue: 0.35) // #30D158 (系统绿)
        case .adverbial:
            return Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93 (系统灰)
        case .clause:
            return Color(red: 0.75, green: 0.35, blue: 0.95) // #BF5AF2 (系统紫)
        case .other:
            return Color.clear
        }
    }

    public var underlineHeight: CGFloat {
        switch self {
        case .adverbial: return 2.0
        case .other: return 0.0
        default: return 2.5
        }
    }
}

/// 标注的句子语法片段
public struct SyntaxSpan: Codable, Identifiable, Sendable {
    public var id: String { "\(text)_\(role.rawValue)_\(UUID().uuidString)" }
    public let text: String
    public let role: SyntaxRole
    public let label: String? // 详细注解，如 "程度状语 (Degree Adverbial)" 或 "定语从句 (Relative Clause)"

    public init(text: String, role: SyntaxRole, label: String? = nil) {
        self.text = text
        self.role = role
        self.label = label
    }

    public var displayLabel: String {
        label ?? role.title
    }
}
