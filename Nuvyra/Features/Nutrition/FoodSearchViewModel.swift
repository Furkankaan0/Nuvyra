import Combine
import Foundation

@MainActor
final class FoodSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [FoodSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let searchService: SQLiteFTSFoodSearchService
    private var searchTask: Task<Void, Never>?

    init(searchService: SQLiteFTSFoodSearchService = .shared) {
        self.searchService = searchService
    }

    deinit {
        searchTask?.cancel()
    }

    func scheduleSearch() {
        scheduleSearch(debounce: true)
    }

    func retrySearch() {
        scheduleSearch(debounce: false)
    }

    private func scheduleSearch(debounce: Bool) {
        searchTask?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !currentQuery.isEmpty else {
            results = []
            errorMessage = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(nanoseconds: 220_000_000)
            }
            guard !Task.isCancelled, let self else { return }

            do {
                let searchResults = try await searchService.search(currentQuery, limit: 24)
                guard !Task.isCancelled else { return }
                results = searchResults
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                errorMessage = "Besin veritabanı şu an aranamadı."
                isSearching = false
            }
        }
    }
}
