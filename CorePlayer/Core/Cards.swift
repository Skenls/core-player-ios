import SwiftUI

struct AlbumCard: View {
    let album: AlbumDto
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArtworkTile(coverID: album.coverArt)
            Text(album.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CoreColors.textPrimary)
                .lineLimit(1)
            Text(subtitle ?? (album.artist?.isEmpty == false ? album.artist! : "Альбом"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CoreColors.textSecondary)
                .lineLimit(1)
        }
    }
}

struct ArtistCard: View {
    let artist: ArtistDto
    var size: CGFloat = 84

    var body: some View {
        VStack(spacing: 8) {
            CoverView(
                coverID: artist.effectiveCover,
                size: size,
                cornerRadius: size / 2,
                pixelSize: 300
            )
            Text(artist.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CoreColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 96)
        }
        .frame(width: 100)
    }
}

struct ArtistRow: View {
    let artist: ArtistDto

    var body: some View {
        HStack(spacing: 12) {
            CoverView(
                coverID: artist.effectiveCover,
                size: 54,
                cornerRadius: 27,
                pixelSize: 300
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(artist.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(CoreColors.textPrimary)
                    .lineLimit(1)
                Text(Formatters.albumCount(artist.albumCount ?? 0))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CoreColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(CoreColors.textSecondary.opacity(0.6))
        }
        .padding(.vertical, 6)
    }
}

struct PlaylistCard: View {
    let playlist: PlaylistDto

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ArtworkTile(coverID: playlist.coverArt ?? playlist.id)
            Text(playlist.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CoreColors.textPrimary)
                .lineLimit(1)
            Text(Formatters.trackCount(playlist.songCount ?? 0))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(CoreColors.textSecondary)
        }
    }
}

struct RecentCard: View {
    let track: TrackDto
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                ArtworkTile(coverID: track.coverArt, corner: 10, pixelSize: 300)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CoreColors.textPrimary)
                        .lineLimit(2)
                    Text(track.displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CoreColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(CoreColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FavoriteBanner: View {
    let count: Int
    var coverArt: String? = nil
    let onPlay: () -> Void

    @Environment(\.api) private var api

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(sunsetGradient)

            if let coverArt, !coverArt.isEmpty {
                RemoteImage(url: api.coverURL(coverID: coverArt, size: 600))
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.4)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color(hex: 0x0B0F17).opacity(0.25),
                    Color(hex: 0x0B0F17).opacity(0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("Мои треки")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("Плейлист · \(Formatters.trackCount(count))")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0xD1D5DB))
                    .lineLimit(1)
            }
            .padding(.leading, 20)
            .padding(.bottom, 18)
            .padding(.trailing, 60)
            .zIndex(1)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "heart")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { onPlay() }
    }

    private var sunsetGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: 0x28153A),
                Color(hex: 0x4C2253),
                Color(hex: 0x673266),
                Color(hex: 0x293D5C),
                Color(hex: 0x101826)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
