//
//  HTTPClient.swift
//  Nuvyra - Barcode Scanner
//
//  URLSession üzerine, exponential backoff retry + JSON decode + URLCache
//  entegrasyonu sağlayan ince istemci katmanı.
//

import Foundation

/// HTTP hata türleri.
public enum HTTPClientError: LocalizedError, Sendable {
    case invalidURL
    case transport(Error)
    case http(status: Int, body: Data?)
    case decoding(Error)
    case notFound
    case timeout
    case offline

    public var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Geçersiz URL."
        case .transport(let err):   return "Bağlantı hatası: \(err.localizedDescription)"
        case .http(let s, _):       return "Sunucu hatası (\(s))."
        case .decoding(let err):    return "Yanıt çözümlenemedi: \(err.localizedDescription)"
        case .notFound:             return "Ürün bulunamadı."
        case .timeout:              return "İstek zaman aşımına uğradı."
        case .offline:              return "İnternet bağlantısı yok."
        }
    }
}

/// HTTP isteği için hafif yapı (URLRequest'in opinionated wrapper'ı).
public struct HTTPRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 12
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// URLSession + retry + JSON decoding üzerine bina edilmiş istemci.
public actor HTTPClient {

    // MARK: - Properties

    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder

    // MARK: - Init

    /// Yeni bir istemci oluşturur. URLCache 24 saatlik TTL ile yapılandırılır.
    public init(
        retryPolicy: RetryPolicy = .default,
        cacheCapacityMB: Int = 32
    ) {
        let config = URLSessionConfiguration.default
        let memCap = cacheCapacityMB * 1024 * 1024
        let diskCap = cacheCapacityMB * 4 * 1024 * 1024
        let cache = URLCache(
            memoryCapacity: memCap,
            diskCapacity: diskCap,
            diskPath: "nuvyra_http_cache"
        )
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 12
        config.waitsForConnectivity = false

        self.session = URLSession(configuration: config)
        self.retryPolicy = retryPolicy

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
    }

    // MARK: - Public API

    /// Bir HTTP isteğini retry ile gönderir ve yanıtı `T`'ye decode eder.
    /// 404 alındığında `HTTPClientError.notFound` fırlatır (retry edilmez).
    public func send<T: Decodable & Sendable>(
        _ request: HTTPRequest,
        as type: T.Type
    ) async throws -> T {
        let data = try await sendData(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decoding(error)
        }
    }

    /// Ham `Data` döndürür (retry uygulanır).
    public func sendData(_ request: HTTPRequest) async throws -> Data {
        var lastError: HTTPClientError?

        for attempt in 0..<retryPolicy.maxAttempts {
            do {
                return try await performOnce(request)
            } catch HTTPClientError.notFound {
                throw HTTPClientError.notFound
            } catch let error as HTTPClientError {
                lastError = error
                if !retryPolicy.shouldRetry(error: error, attempt: attempt) {
                    throw error
                }
                let delay = retryPolicy.delay(for: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                lastError = .transport(error)
                let delay = retryPolicy.delay(for: attempt)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? .timeout
    }

    // MARK: - Internals

    /// Tek bir denemeyi gerçekleştirir, status code yorumlar.
    private func performOnce(_ request: HTTPRequest) async throws -> Data {
        var urlRequest = URLRequest(
            url: request.url,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: request.timeout
        )
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (k, v) in request.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        // 24 saatlik cache hint
        urlRequest.setValue("max-age=86400", forHTTPHeaderField: "Cache-Control")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlErr as URLError {
            switch urlErr.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw HTTPClientError.offline
            case .timedOut:
                throw HTTPClientError.timeout
            default:
                throw HTTPClientError.transport(urlErr)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.transport(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 404:
            throw HTTPClientError.notFound
        default:
            throw HTTPClientError.http(status: http.statusCode, body: data)
        }
    }
}
