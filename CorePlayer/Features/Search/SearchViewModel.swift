import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: SearchResponse = .empty
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var task: Task<Void, Never>?

    func update(query: String, api: APIClient) {
        self.query = query
        task?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { results = .empty; isLoading = false; errorMessage = nil; return }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.perform(trimmed, api: api)
        }
    }
    private func perform(_ query: String, api: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.search(query: query)
            guard !Task.isCancelled else { return }
            results = response
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            results = .empty
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func clear() {
        task?.cancel()
        query = ""
        results = .empty
        errorMessage = nil
        isLoading = false
    }
}
