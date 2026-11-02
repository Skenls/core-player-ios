import SwiftUI

struct SyncedLyricsView: View {
    let lines: [LyricLine]
    let position: Double
    let onSeek: (Double) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(size: current == line.id ? 18 : 15,
                                          weight: current == line.id ? .bold : .regular))
                            .foregroundColor(current == line.id ? .white : CoreColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                            .onTapGesture { onSeek(line.time) }
                    }
                }
                .padding(.vertical, 20)
            }
            .onAppear {
                if let current { proxy.scrollTo(current, anchor: .center) }
            }
            .onChange(of: current) { value in
                guard let value else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private var current: Int? {
        LRCParser.currentIndex(lines, at: position)
    }
}
