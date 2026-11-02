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
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x3A1C12),
                            Color(hex: 0x1C2433)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "heart.fill")
                .font(.system(size: 118, weight: .bold))
                .foregroundColor(CoreColors.accent.opacity(0.10))
                .offset(x: 220, y: 18)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Избранное")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(Formatters.trackCount(count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CoreColors.textSecondary)
                }
                Spacer()
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(CoreGradients.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Button(action: onShuffle) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 96)
    }
}
