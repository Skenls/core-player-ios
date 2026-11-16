import SwiftUI
import UIKit

private let synapseViolet = Color(red: 197 / 255, green: 166 / 255, blue: 1)

struct SynapseSection: View {
    var isVisible: Bool
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var synapse: SynapseStore
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var showFilters = false
    @State private var showTracks = false
    @State private var onScreen = false
    @State private var appeared = false
    @State private var busyFavorites = Set<String>()
    @State private var favoriteError: String?

    private var tracks: [TrackDto] { synapse.mix?.tracks ?? [] }
    private var active: Bool { synapse.owns(player.currentTrack?.synapse?.session_id) }
    private var shownMixActive: Bool {
        active && player.currentTrack?.synapse?.session_id == synapse.mix?.mix_id
    }
    private var playing: Bool { active && player.isPlaying && !player.isLoading }
    private var heroHeight: CGFloat { min(640, max(440, UIScreen.main.bounds.height * 0.70)) }

    var body: some View {
        VStack(spacing: 8) {
            hero
            if let notice = synapse.notice { message(notice, color: synapseViolet) }
            if let hint = synapse.mix?.hint { message(hint, color: CoreColors.textSecondary) }
            Divider().background(Color.white.opacity(0.1)).padding(.vertical, 16)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .sheet(isPresented: $showFilters) { filtersSheet }
        .sheet(isPresented: $showTracks) { tracksSheet }
    }

    private var hero: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(synapseViolet).frame(width: 6, height: 6)
                Text("МУЗЫКА НА ВАШЕЙ ВОЛНЕ")
                    .font(.system(size: 10)).tracking(2).foregroundColor(synapseViolet)
                Spacer(minLength: 0)
                Button { synapse.refresh(switchTrack: true) } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 48)
                }
                .foregroundColor(synapseViolet)
                .disabled(synapse.loading || synapse.resetting)
                .accessibilityLabel("Обновить подборку")
            }
            SynapseVisualizer(
                playing: playing,
                visible: isVisible && appeared && onScreen && scenePhase == .active && !showFilters && !showTracks,
                burst: synapse.burstAnimation, white: synapse.whiteParticles,
                bpm: synapseTempo(bpm: player.currentTrack?.bpm, genre: player.currentTrack?.genre)
            )
            .frame(height: min(280, heroHeight * 0.42))
            .background(GeometryReader { geometry in
                Color.clear.preference(key: SynapseFramePreference.self, value: geometry.frame(in: .global))
            })
            .onPreferenceChange(SynapseFramePreference.self) { frame in
                onScreen = frame.intersects(UIScreen.main.bounds)
            }
            Text("Synapse").font(.system(size: 38, weight: .light)).tracking(-1).foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 13)).foregroundColor(CoreColors.textSecondary)
                .multilineTextAlignment(.center).padding(.top, 10).padding(.horizontal, 12)
            Button(action: toggleWave) {
                HStack(spacing: 8) {
                    if synapse.loading { ProgressView().tint(Color.black) }
                    else { Image(systemName: shownMixActive && player.isPlaying ? "pause.fill" : "play.fill") }
                    Text(shownMixActive && player.isPlaying ? "Пауза" : "Включить волну")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(red: 27 / 255, green: 16 / 255, blue: 45 / 255))
                .frame(minWidth: 190, minHeight: 52).padding(.horizontal, 12)
                .background(synapseViolet).clipShape(Capsule())
            }
            .disabled(synapse.resetting || (tracks.isEmpty && !shownMixActive))
            .opacity(synapse.resetting || (tracks.isEmpty && !shownMixActive) ? 0.5 : 1)
            .padding(.top, 24)
            HStack(spacing: 10) {
                auxiliaryButton("Настроить", icon: "line.3.horizontal") { showFilters = true }
                auxiliaryButton("Подборка", icon: "music.note.list") { showTracks = true }
            }.padding(.top, 12)
            if synapse.error != nil || synapse.mix?.status == "unavailable" {
                Button("Повторить") { synapse.refresh() }
                    .foregroundColor(synapseViolet).disabled(synapse.loading || synapse.resetting).padding(.top, 12)
            }
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20).padding(.top, 16)
        .frame(minHeight: heroHeight)
        .background(LinearGradient(colors: [Color(red: 23 / 255, green: 16 / 255, blue: 38 / 255), Color(red: 14 / 255, green: 13 / 255, blue: 24 / 255), .clear], startPoint: .top, endPoint: .bottom))
    }

    private var subtitle: String {
        if synapse.resetting { return "Начинаем с чистого листа…" }
        if let error = synapse.error { return error }
        if synapse.filters.familiarity.isEmpty { return "Выберите, какую музыку хотите услышать" }
        if synapse.loading { return "Настраиваем вашу волну…" }
        if synapse.mix?.status == "syncing" { return "Знакомимся с вашей медиатекой…" }
        if synapse.mix?.status == "unavailable" && tracks.isEmpty { return "Каталог пока недоступен. Попробуйте ещё раз." }
        if tracks.isEmpty { return "Для этих фильтров пока нет треков" }
        return playing ? "Ваша музыка. Новые связи." : "Знакомое звучание и неожиданные открытия"
    }

    private func toggleWave() {
        if shownMixActive { player.togglePlayPause() }
        else if let first = tracks.first { player.play(track: first, in: tracks, source: "Synapse") }
    }

    private func auxiliaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .medium))
                .foregroundColor(.black).padding(.horizontal, 14).frame(minHeight: 48)
                .background(Color.white).clipShape(Capsule())
        }.buttonStyle(.plain)
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 12)).foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 4)
    }

    private var filtersSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterChoices([("familiar", "Знакомое"), ("unfamiliar", "Незнакомое"), ("favorites", "Избранное")], mood: false)
                    filterChoices([("sad", "Грустное"), ("productive", "Продуктивное"), ("upbeat", "Бодрое")], mood: true)
                }.padding(20)
            }
            .background(CoreColors.background.ignoresSafeArea())
            .navigationTitle("Настроить волну").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { showFilters = false } } }
        }.navigationViewStyle(.stack).preferredColorScheme(.dark).tint(synapseViolet)
    }

    private func filterChoices(_ options: [(String, String)], mood: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.0) { id, title in
                let selected = mood ? synapse.filters.mood == id : synapse.filters.familiarity.contains(id)
                Button {
                    var filters = synapse.filters
                    if mood { filters.mood = selected ? nil : id }
                    else if selected { filters.familiarity.removeAll { $0 == id } }
                    else { filters.familiarity.append(id) }
                    synapse.setFilters(filters)
                } label: {
                    Text(title).font(.system(size: 12)).foregroundColor(selected ? synapseViolet : CoreColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(selected ? Color(red: 48 / 255, green: 32 / 255, blue: 67 / 255) : CoreColors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.disabled(synapse.resetting).accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var tracksSheet: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let favoriteError { message(favoriteError, color: synapseViolet) }
                    if tracks.isEmpty {
                        Text(synapse.loading ? "Подбираем музыку…" : "Подборка пуста")
                            .foregroundColor(CoreColors.textSecondary).padding(24)
                    } else {
                        HStack {
                            Text("Ваша подборка").font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Text(Formatters.trackCount(tracks.count)).font(.system(size: 12)).foregroundColor(CoreColors.textSecondary)
                        }.padding(.vertical, 18)
                        ForEach(tracks.prefix(20)) { track in mixRow(track) }
                    }
                }.padding(.horizontal, 20)
            }
            .background(CoreColors.background.ignoresSafeArea())
            .navigationTitle("Подборка").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Закрыть") { showTracks = false } } }
        }.navigationViewStyle(.stack).preferredColorScheme(.dark).tint(synapseViolet)
    }

    private func mixRow(_ track: TrackDto) -> some View {
        let current = player.currentTrack?.id == track.id && player.currentTrack?.synapse?.session_id == track.synapse?.session_id
        return HStack(spacing: 8) {
            Button {
                if current { player.togglePlayPause() }
                else { player.play(track: track, in: tracks, source: "Synapse") }
            } label: {
                HStack(spacing: 12) {
                    CoverView(coverID: track.coverArt ?? track.albumId.map { "al-" + $0 }, size: 46, cornerRadius: 10, pixelSize: 200)
                        .overlay {
                            if current {
                                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.55))
                                Image(systemName: player.isPlaying ? "waveform" : "play.fill").foregroundColor(synapseViolet)
                            }
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title).font(.system(size: 14)).foregroundColor(current ? synapseViolet : .white)
                        Text(track.displayArtist).font(.system(size: 12)).foregroundColor(CoreColors.textSecondary)
                        Text(track.synapse?.reason ?? "Для вас").font(.system(size: 10)).foregroundColor(synapseViolet.opacity(0.7))
                    }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Formatters.duration(track.durationSeconds)).font(.system(size: 11)).foregroundColor(CoreColors.textSecondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(synapse.resetting)
            Button {
                busyFavorites.insert(track.id)
                Task {
                    let success = await favorites.toggle(track: track)
                    if !success { favoriteError = "Не удалось изменить избранное. Попробуйте ещё раз." }
                    busyFavorites.remove(track.id)
                }
            } label: {
                Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                    .foregroundColor(favorites.isFavorite(track) ? synapseViolet : CoreColors.textSecondary)
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain).disabled(synapse.resetting || busyFavorites.contains(track.id))
                .accessibilityLabel(favorites.isFavorite(track) ? "Удалить из избранного" : "В избранное")
        }.padding(.vertical, 6)
    }
}

private struct SynapseFramePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
