//
//  RetryPolicy.swift
//  Nuvyra - Barcode Scanner
//
//  Exponential backoff retry policy: 1s → 2s → 4s, max 3 deneme.
//

import Foundation

/// Retry stratejisi.
public struct RetryPolicy: Sendable {

    // MARK: - Properties

    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let multiplier: Double
    public let retryableStatuses: Set<Int>

    // MARK: - Init

    /// - Parameters:
    ///   - maxAttempts: Toplam deneme sayısı (3 → ilk + 2 retry).
    ///   - baseDelay:   İlk gecikme (saniye).
    ///   - multiplier:  Backoff çarpanı (2.0 → 1, 2, 4).
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        multiplier: Double = 2.0,
        retryableStatuses: Set<Int> = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.retryableStatuses = retryableStatuses
    }

    /// Sık kullanılan default policy.
    public static let `default` = RetryPolicy()

    // MARK: - Public API

    /// Belirtilen deneme indeksi için bekleme süresi (saniye).
    /// attempt = 0 → baseDelay, attempt = 1 → baseDelay × multiplier, ...
    public func delay(for attempt: Int) -> TimeInterval {
        baseDelay * pow(multiplier, Double(attempt))
    }

    /// Verilen hata için yeniden denemeli miyiz?
    public func shouldRetry(error: HTTPClientError, attempt: Int) -> Bool {
        guard attempt < maxAttempts - 1 else { return false }
        switch error {
        case .timeout, .offline, .transport:
            return true
        case .http(let status, _):
            return retryableStatuses.contains(status)
        case .decoding, .invalidURL, .notFound:
            return false
        }
    }
}
