import SwiftUI

// MARK: - Remote artwork

struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            CoreColors.surfaceVariant
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed || url == nil {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(CoreColors.textSecondary.opacity(0.7))
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: CoreColors.textSecondary))
                    .scaleEffect(0.7)
            }
        }
        .clipped()
        .task(id: url?.absoluteString) {
            image = nil
            failed = false
            guard let url = url else {
                failed = true
                return
            }
            if let cached = ImageCache.shared.memoryImage(for: url) {
                image = cached
                return
            }
            let loaded = await ImageCache.shared.image(for: url)
            if Task.isCancelled { return }
            image = loaded
            failed = loaded == nil
        }
    }
}

struct CoverView: View {
    let coverID: String?
    let size: CGFloat
    var cornerRadius: CGFloat = 10
    var pixelSize: Int? = nil

    @Environment(\.api) private var api

    var body: some View {
        RemoteImage(
            url: api.coverURL(coverID: coverID, size: pixelSize ?? Int(max(300, size * 2)))
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

struct ArtworkTile: View {
    let coverID: String?
    var corner: CGFloat = 12
    var pixelSize: Int = 600

    @Environment(\.api) private var api

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RemoteImage(url: api.coverURL(coverID: coverID, size: pixelSize))
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            )
    }
}

// MARK: - Layout helpers

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(CoreColors.textPrimary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CoreColors.textSecondary)
                }
            }
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CoreColors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct IconButton: View {
    let systemName: String
    var size: CGFloat = 38
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accent ? Color.black : CoreColors.textPrimary)
                .frame(width: size, height: size)
                .background(accent ? AnyShapeStyle(Color.white) : AnyShapeStyle(CoreColors.surfaceVariant))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - States

struct LoadingView: View {
    var text: String = "Загрузка..."

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(CoreColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

struct ErrorStateView: View {
    var title: String = "Не удалось загрузить"
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(CoreColors.textSecondary)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(CoreColors.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(CoreColors.textSecondary)
                .multilineTextAlignment(.center)
            if let retry = retry {
                Button(action: retry) {
                    Text("Повторить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(CoreColors.textSecondary.opacity(0.6))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(CoreColors.textPrimary)
                .multilineTextAlignment(.center)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(CoreColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

struct BlurredCoverPlaceholder: View {
    var body: some View { EmptyView() }
}
