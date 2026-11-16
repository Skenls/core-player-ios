import SwiftUI

struct TrackDestinationsSheet: View {
    let track: TrackDto

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if let artistID = track.artistId, !artistID.isEmpty {
                        NavigationLink(destination: ArtistDetailView(artistID: artistID, initialTitle: track.displayArtist)) {
                            destinationRow(title: track.displayArtist, kind: "Исполнитель", coverID: artistID, rounded: true, navigable: true)
                        }
                    } else {
                        destinationRow(title: track.displayArtist, kind: "Исполнитель недоступен", coverID: nil, rounded: true, navigable: false)
                    }
                    if let albumID = track.albumId, !albumID.isEmpty {
                        NavigationLink(destination: AlbumDetailView(albumID: albumID, initialTitle: albumTitle)) {
                            destinationRow(title: albumTitle, kind: "Альбом", coverID: track.coverArt, rounded: false, navigable: true)
                        }
                    } else {
                        destinationRow(title: albumTitle, kind: "Альбом недоступен", coverID: track.coverArt, rounded: false, navigable: false)
                    }
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
            .navigationTitle(track.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private var albumTitle: String {
        track.displayAlbum.isEmpty ? "Неизвестный альбом" : track.displayAlbum
    }

    private func destinationRow(title: String, kind: String, coverID: String?, rounded: Bool, navigable: Bool) -> some View {
        HStack(spacing: 14) {
            CoverView(coverID: coverID, size: 64, cornerRadius: rounded ? 32 : 10, pixelSize: 200)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind)
                    .font(.system(size: 12))
                    .foregroundColor(CoreColors.textSecondary)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CoreColors.textPrimary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if navigable {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CoreColors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoreColors.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
