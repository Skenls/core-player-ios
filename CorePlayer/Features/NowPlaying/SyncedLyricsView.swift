import SwiftUI

// Android SyncedLyricsView port: karaoke lines, active line bold white at full
// opacity with slight scale, inactive lines dimmed AND blurred; tap a line to seek;
// auto-scroll to the active line unless the user is scrolling manually (returns
// after 2.5s of idle).

struct SyncedLyricsView: View {
    let lines: [LyricLine]
    let position: Double
    let onSeek: (Double) -> Void
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var onRetry: (() -> Void)? = nil

    @State private var isAutoFocusActive = true
    @State private var focusJob: DispatchWorkItem?
    @State private var lastScrolled = Date.distantPast

    private var activeIndex: Int? {
        LRCParser.currentIndex(lines, at: position)
    }

    var body: some View {
        if isLoading {
            loading
        } else if lines.isEmpty {
            empty
        } else {
            scrollBody
        }
    }
    // MARK: - States

    private var loading: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(CoreColors.textSecondary.opacity(0.5))
            Text(errorMessage ?? "Текст песни недоступен")
                .font(.system(size: 16))
                .foregroundColor(CoreColors.textSecondary)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Повторить")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Scroll body

    private var scrollBody: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 40)
                    ForEach(lines) { line in
                        lyricRow(line)
                            .id(line.id)
                    }
                    Color.clear.frame(height: 160)
                }
                .padding(.horizontal, 20)
                .padding(.top, 70)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        userStartedScrolling()
                    }
                    .onEnded { _ in
                        scheduleFocusRestore()
                    }
            )
            .onChange(of: activeIndex) { value in
                guard isAutoFocusActive, let index = value else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(lines[index].id, anchor: .center)
                }
            }
            .onAppear {
                if let index = activeIndex {
                    proxy.scrollTo(lines[index].id, anchor: .center)
                }
            }
        }
    }

    private func userStartedScrolling() {
        let now = Date()
        guard now.timeIntervalSince(lastScrolled) > 0.25 else { return }
        lastScrolled = now
        isAutoFocusActive = false
        focusJob?.cancel()
    }

    private func scheduleFocusRestore() {
        focusJob?.cancel()
        let job = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.4)) {
                isAutoFocusActive = true
            }
        }
        focusJob = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: job)
    }

    // MARK: - Line

    private func lyricRow(_ line: LyricLine) -> some View {
        let active = line.id == activeIndexValue
        let alpha: Double = active ? 1 : (isAutoFocusActive ? 0.32 : 0.72)
        let blur: CGFloat = isAutoFocusActive && !active ? 2.5 : 0

        Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: active ? 23 : 19, weight: active ? .bold : .medium))
            .lineSpacing(active ? 9 : 7)
            .foregroundColor(Color.white.opacity(alpha))
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaleEffect(active ? 1.05 : 1, anchor: UnitPoint(x: 0, y: 0.5))
            .blur(radius: blur)
            .animation(.spring(), value: active)
            .animation(.easeInOut(duration: 0.25), value: isAutoFocusActive)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                onSeek(line.time)
                focusJob?.cancel()
                withAnimation(.easeInOut(duration: 0.25)) { isAutoFocusActive = true }
            }
    }

    private var activeIndexValue: Int? {
        LRCParser.currentIndex(lines, at: position)
    }
}
