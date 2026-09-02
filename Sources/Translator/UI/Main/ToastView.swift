import SwiftUI

/// 轻量 Liquid Glass 气泡反馈 Toast
public struct ToastView: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.green)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(Color(red: 16/255, green: 20/255, blue: 30/255).opacity(0.85))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
    }
}
