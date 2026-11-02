import SwiftUI

struct SearchView: View {
    @Environment(\.api) private var api
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var searchHistory: SearchHistoryStore
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Поиск").font(.system(size: 30, weight: .bold))
            searchField
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background((settings.amoled ? Color.black : CoreColors.background).ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(CoreColors.textSecondary)
            TextField("Что включим?", text: Binding(
                get: { vm.query },
                set: { vm.update(query: $0, api: api) }
            ))
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .submitLabel(.search)
            .onSubmit { searchHistory.add(vm.query) }
            if !vm.query.isEmpty {
                Button { vm.clear() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(CoreColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(CoreColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var content: some View {
        if vm.query.isEmpty {
            history
        } else if vm.isLoading {
            ProgressView("Ищем...").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            ErrorStateView(title: "Ошибка поиска", message: error) { vm.update(query: vm.query, api: api) }
        } else if vm.results.isEmpty {
            EmptyStateView(icon: "magnifyingglass", title: "Ничего не найдено", subtitle: "Попробуйте другой запрос")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                SearchResultsView(results: vm.results) { track, queue in
                    player.play(track: track, in: queue, source: "Поиск")
                }
                .padding(.bottom, 120)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            if searchHistory.queries.isEmpty {
                EmptyStateView(icon: "clock", title: "История пуста", subtitle: "Здесь появятся ваши запросы")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("История поиска").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button("Очистить") { searchHistory.clear() }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CoreColors.textPrimary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(searchHistory.queries, id: \.self) { query in
                        Button { vm.update(query: query, api: api) } label: {
                            Text(query).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(CoreColors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
        }
    }
}
