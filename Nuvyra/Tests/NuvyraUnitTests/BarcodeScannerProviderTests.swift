import XCTest
@testable import Nuvyra

final class BarcodeScannerProviderTests: XCTestCase {
    func testOpenFoodFactsResponseMapsProductAndMacrosPer100g() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Whole Grain Biscuit",
            "product_name_tr": "Tam Tahıllı Bisküvi",
            "brands": "Nuvyra Test, Second Brand",
            "image_front_url": "https://example.com/front.jpg",
            "nutriments": {
              "energy-kcal_100g": "421.4",
              "proteins_100g": 8.2,
              "carbohydrates_100g": 63.5,
              "fat_100g": 14.1,
              "fiber_100g": 5.7
            }
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenFoodFactsProvider.Response.self, from: json)

        let provider = OpenFoodFactsProvider(client: HTTPClient())
        let product = try XCTUnwrap(provider.makeProduct(from: response, requestedBarcode: "8690000000000"))

        XCTAssertEqual(product.name, "Tam Tahıllı Bisküvi")
        XCTAssertEqual(product.brand, "Nuvyra Test")
        XCTAssertEqual(product.barcode, "8690000000000")
        XCTAssertEqual(product.caloriesPer100g, 421.4, accuracy: 0.01)
        XCTAssertEqual(product.protein, 8.2, accuracy: 0.01)
        XCTAssertEqual(product.carbs, 63.5, accuracy: 0.01)
        XCTAssertEqual(product.fat, 14.1, accuracy: 0.01)
        XCTAssertEqual(product.fiber ?? 0, 5.7, accuracy: 0.01)
        XCTAssertEqual(product.imageURL?.absoluteString, "https://example.com/front.jpg")
        XCTAssertEqual(product.source, .openFoodFacts)
    }

    func testOpenFoodFactsResponseConvertsKilojoulesWhenKcalIsMissing() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Kefir",
            "nutriments": {
              "energy_100g": 418.4,
              "proteins_100g": 3,
              "carbohydrates_100g": 4,
              "fat_100g": 2
            }
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenFoodFactsProvider.Response.self, from: json)

        let provider = OpenFoodFactsProvider(client: HTTPClient())
        let product = try XCTUnwrap(provider.makeProduct(from: response, requestedBarcode: "1234567890123"))

        XCTAssertEqual(product.caloriesPer100g, 100, accuracy: 0.01)
        XCTAssertEqual(product.protein, 3, accuracy: 0.01)
        XCTAssertEqual(product.carbs, 4, accuracy: 0.01)
        XCTAssertEqual(product.fat, 2, accuracy: 0.01)
    }

    func testOpenFoodFactsStatusZeroIsNotMappedAsProduct() throws {
        let json = """
        {
          "status": 0,
          "product": {
            "product_name": "Missing Product",
            "nutriments": { "energy-kcal_100g": 100 }
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenFoodFactsProvider.Response.self, from: json)

        let provider = OpenFoodFactsProvider(client: HTTPClient())

        XCTAssertNil(provider.makeProduct(from: response, requestedBarcode: "0000000000000"))
    }

    func testOpenFoodFactsSearchResultIncludesMacrosAndSource() throws {
        let json = """
        {
          "products": [
            {
              "code": "8690000000000",
              "product_name": "Protein Bar",
              "brands": "Nuvyra",
              "nutriments": {
                "energy-kcal_100g": 390,
                "proteins_100g": 31.5,
                "carbohydrates_100g": 34.2,
                "fat_100g": 12.1
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(OpenFoodFactsProvider.SearchResponse.self, from: json)

        let provider = OpenFoodFactsProvider(client: HTTPClient())
        let product = try XCTUnwrap(response.products?.first)
        let result = try XCTUnwrap(provider.makeFoodSearchResult(from: product))

        XCTAssertEqual(result.name, "Protein Bar")
        XCTAssertEqual(result.brand, "Nuvyra")
        XCTAssertEqual(result.calories, 390)
        XCTAssertEqual(result.protein, 31.5, accuracy: 0.01)
        XCTAssertEqual(result.carbs, 34.2, accuracy: 0.01)
        XCTAssertEqual(result.fat, 12.1, accuracy: 0.01)
        XCTAssertEqual(result.source, .openFoodFacts)
        XCTAssertTrue(result.isVerified)
        XCTAssertEqual(result.externalID, "8690000000000")
    }
}
