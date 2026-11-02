import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, search, browse, library
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Главная"
        case .search: return "Поиск"
        case .browse: return "Все треки"
        case .library: return "Медиатека"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .browse: return "music.note.list"
        case .library: return "square.stack.fill"
        }
    }
}

struct CoreTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.system(size: 19, weight: .semibold))
                        Text(tab.title).font(.system(size: 9, weight: .medium)).lineLimit(1)
                    }
                    .foregroundColor(selection == tab ? CoreColors.accent : CoreColors.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(CoreColors.bottomBar)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(CoreColors.divider), alignment: .top)
    }
}
