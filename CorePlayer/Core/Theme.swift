import SwiftUI

enum CoreColors {
    static let background = Color(hex: 0x0B0F17)
    static let surface = Color(hex: 0x131A26)
    static let surfaceVariant = Color(hex: 0x1A2232)
    static let bottomBar = Color(hex: 0x0D121D)
    static let divider = Color(hex: 0x1E2638)
    static let accent = Color(hex: 0xFF5722)
    static let accentLight = Color(hex: 0xFF7A00)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E95A5)

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

enum CoreGradients {
    static let accent = LinearGradient(
        colors: [CoreColors.accentLight, CoreColors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let favoriteBanner = LinearGradient(
        colors: [Color(hex: 0x2B1A12), Color(hex: 0x1A2232)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coverFade = LinearGradient(
        colors: [.clear, CoreColors.background.opacity(0.85), CoreColors.background],
        startPoint: .top,
        endPoint: .bottom
    )
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
