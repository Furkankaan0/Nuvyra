import Foundation
import XCTest
@testable import Nuvyra

final class GeminiFoodLogServiceTests: XCTestCase {
    func testRequestBodyUsesJSONMimeTypeAndFoodLogSchema() throws {
        let service = GeminiFoodLogService(
            apiKey: "test-api-key",
            session: MockGeminiHTTPSession(data: Data())
        )

        let request = try service.makeGenerateContentRequest(for: "Kahvaltıda 1 elma yedim")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let generationConfig = try XCTUnwrap(json["generationConfig"] as? [String: Any])

        XCTAssertEqual(generationConfig["responseMimeType"] as? String, "application/json")

        let schema = try XCTUnwrap(generationConfig["responseJsonSchema"] as? [String: Any])
        XCTAssertEqual(schema["type"] as? String, "object")
        XCTAssertEqual(schema["required"] as? [String], ["FoodLog"])

        let properties = try XCTUnwrap(schema["properties"] as? [String: Any])
        let foodLog = try XCTUnwrap(properties["FoodLog"] as? [String: Any])
        XCTAssertEqual(foodLog["type"] as? String, "array")

        let itemSchema = try XCTUnwrap(foodLog["items"] as? [String: Any])
        XCTAssertEqual(itemSchema["required"] as? [String], ["name", "quantity", "calories"])

        let itemProperties = try XCTUnwrap(itemSchema["properties"] as? [String: Any])
        XCTAssertEqual((itemProperties["name"] as? [String: Any])?["type"] as? String, "string")
        XCTAssertEqual((itemProperties["quantity"] as? [String: Any])?["type"] as? String, "string")
        XCTAssertEqual((itemProperties["calories"] as? [String: Any])?["type"] as? String, "integer")
    }

    func testLogFoodDecodesStructuredGeminiResponse() async throws {
        let geminiResponse = #"""
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  {
                    "text": "{\"FoodLog\":[{\"name\":\"Elma\",\"quantity\":\"1 adet\",\"calories\":95}]}"
                  }
                ]
              }
            }
          ]
        }
        """#
        let service = GeminiFoodLogService(
            apiKey: "test-api-key",
            session: MockGeminiHTTPSession(data: Data(geminiResponse.utf8))
        )

        let logs = try await service.logFood(from: "1 elma yedim")

        XCTAssertEqual(logs, [
            FoodLog(name: "Elma", quantity: "1 adet", calories: 95)
        ])
    }
}

private struct MockGeminiHTTPSession: GeminiHTTPSession {
    let data: Data
    var statusCode = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://generativelanguage.googleapis.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
