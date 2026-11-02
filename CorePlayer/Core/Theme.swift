import SwiftUI

enum CoreColors {
    static let background = Color(hex: 0x0B0F17)
    static let surface = Color(hex: 0x131A26)
    static let surfaceVariant = Color(hex: 0x1A2232)
    static let bottomBar = Color(hex: 0x080C14)
    static let divider = Color(hex: 0x1E2638)
    static let accent = Color.white
    static let favorite = Color(hex: 0xEF4444)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E95A5)
    static let pillStart = Color(hex: 0x161C26)
    static let pillMiddle = Color(hex: 0x162334)
    static let pillEnd = Color(hex: 0x12344E)

    static let amoledBackground = Color.black
    static let amoledSurface = Color(hex: 0x101010)
    static let amoledVariant = Color(hex: 0x222222)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    func cardStyle(
        cornerRadius: CGFloat = 16,
        fill: Color = CoreColors.surface,
        border: Color = CoreColors.divider
    ) -> some View {
        self
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 0.7)
            )
    }

    func screenPadding() -> some View {
        self.padding(.horizontal, 16)
    }
}
