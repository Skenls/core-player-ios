import SwiftUI

struct SearchResultsView: View {
    let results: SearchResponse
    let onPlayTrack: (TrackDto, [TrackDto]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !results.tracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Треки")
                    ForEach(results.tracks) { track in
                        TrackRow(track: track) {
                            onPlayTrack(track, results.tracks)
                        }
                    }
                }
            }

            if !results.albums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Альбомы")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(results.albums) { album in
                                NavigationLink(
                                    destination: AlbumDetailView(albumID: album.id, initialTitle: album.name)
                                ) {
                                    AlbumCard(album: album)
                                        .frame(width: 150)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !results.artists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Исполнители")
                    ForEach(results.artists) { artist in
                        NavigationLink(
                            destination: ArtistDetailView(artistID: artist.id, initialTitle: artist.name)
                        ) {
                            HStack(spacing: 12) {
                                CoverView(coverID: artist.effectiveCover, size: 52, cornerRadius: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                    Text(Formatters.albumCount(artist.albumCount))
                                        .font(.system(size: 12)).foregroundColor(CoreColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(CoreColors.textSecondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
