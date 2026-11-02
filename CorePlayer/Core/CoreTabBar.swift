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
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .browse: return "music.note.list"
        case .library: return "square.stack"
        }
    }

    var selectedIcon: String {
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
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let selected = selection == tab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: selected ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 20, weight: .regular))
                        Text(tab.title)
                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundColor(selected ? CoreColors.textPrimary : CoreColors.textSecondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 14)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .matchedGeometryEffect(id: "activeTabBubble", in: tabAnimation)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(CoreColors.bottomBar)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { Rectangle().fill(Color.white).frame(height: 0.5).opacity(0.08) }
    }
}
