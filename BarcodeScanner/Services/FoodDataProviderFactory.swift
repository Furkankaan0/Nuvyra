import Foundation

enum FoodDataProviderFactory {
    static func barcodeProviders(client: HTTPClient = HTTPClient()) -> [any NutritionProvider] {
        var providers: [any NutritionProvider] = [
            OpenFoodFactsProvider(client: client)
        ]

        if let fatSecret = makeFatSecretProvider(client: client) {
            providers.append(fatSecret)
        }

        if let usdaAPIKey = FoodDataRuntimeConfig.usdaAPIKey {
            providers.append(USDAProvider(client: client, apiKey: usdaAPIKey))
        }

        return providers
    }

    static func remoteSearchProviders(client: HTTPClient = HTTPClient()) -> [any RemoteFoodSearchProvider] {
        var providers: [any RemoteFoodSearchProvider] = []

        if let fatSecret = makeFatSecretProvider(client: client) {
            providers.append(fatSecret)
        }

        providers.append(OpenFoodFactsProvider(client: client))
        if let usdaAPIKey = FoodDataRuntimeConfig.usdaAPIKey {
            providers.append(USDAProvider(client: client, apiKey: usdaAPIKey))
        }
        return providers
    }

    private static func makeFatSecretProvider(client: HTTPClient) -> FatSecretProvider? {
        guard let credentials = FoodDataRuntimeConfig.fatSecretCredentials else { return nil }
        return FatSecretProvider(
            client: client,
            credentials: credentials,
            region: FoodDataRuntimeConfig.fatSecretRegion,
            language: FoodDataRuntimeConfig.fatSecretLanguage
        )
    }
}

enum FoodDataRuntimeConfig {
    static var fatSecretCredentials: FatSecretProvider.Credentials? {
        guard
            let clientID = value(for: "FATSECRET_CLIENT_ID"),
            let clientSecret = value(for: "FATSECRET_CLIENT_SECRET")
        else {
            return nil
        }

        return FatSecretProvider.Credentials(
            clientID: clientID,
            clientSecret: clientSecret,
            scope: value(for: "FATSECRET_SCOPE") ?? "premier barcode localization"
        )
    }

    static var fatSecretRegion: String {
        value(for: "FATSECRET_REGION")
            ?? Locale.current.region?.identifier
            ?? "US"
    }

    static var fatSecretLanguage: String {
        value(for: "FATSECRET_LANGUAGE")
            ?? Locale.preferredLanguages.first?.split(separator: "-").first.map(String.init)
            ?? "en"
    }

    static var usdaAPIKey: String? {
        value(for: "USDA_API_KEY")
    }

    private static func value(for key: String) -> String? {
        let environmentValue = ProcessInfo.processInfo.environment[key]
        let bundleValue = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return [environmentValue, bundleValue]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { value in
                !value.isEmpty && !value.hasPrefix("$(")
            }
    }
}
