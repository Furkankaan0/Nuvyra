import Combine
import Foundation

/// Phase 6 — `FoodRepository` üzerinden çalışan tek giriş noktalı search VM.
/// Eskiden doğrudan `SQLiteFTSFoodSearchService` + `RemoteFoodSearchService`
/// ile çalışıyordu; artık repository orkestrasyonu (local → remote, dedup,
/// write-through) tek noktadan geçiyor ve sonuçlar rich `FoodItem`.
@MainActor
final class FoodSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [FoodItem] = []
    @Published private(set) var recents: [FoodItem] = []
    @Published private(set) var favorites: [FoodItem] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    private let repository: FoodRepository
    private var searchTask: Task<Void, Never>?

    init(repository: FoodRepository = DefaultFoodRepository()) {
        self.repository = repository
    }

    deinit {
        searchTask?.cancel()
    }

    /// View açıldığında çağrılır — son kullanılanlar ve favoriler async yüklenir.
    /// Boş query durumunda kullanıcıya hızlı erişim sunar.
    func loadInitial() async {
        async let recentsTask = repository.recentItems(limit: 12)
        async let favoritesTask = repository.favoriteItems(limit: 12)
        recents = await recentsTask
        favorites = await favoritesTask
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
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            guard !Task.isCancelled, let self else { return }

            let items = await repository.searchItems(query: currentQuery, limit: 30)
            guard !Task.isCancelled else { return }

            // Empty result için errorMessage SET ETMİYORUZ — view zaten boş
            // sonuç durumunu ayrı bir Text ile gösteriyor. errorMessage'ı bu
            // VM'de yalnızca repository sistemik hata fırlatırsa kullanırdık;
            // şu an `searchItems` non-throwing, dolayısıyla mevcut alan
            // ileri faz "sunucu hatası" kullanım senaryosu için duruyor.
            results = items
            errorMessage = nil
            isSearching = false
        }
    }
}
