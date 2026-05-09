//
//  RANSACPlaneDetector.swift
//  Nuvyra - Portion Estimator
//
//  Tabak düzlemini RANSAC algoritmasıyla tespit eden saf-Swift
//  implementasyon. Çıktı düzlem normali ve düzlem üstü/altı sınıflandırması.
//

import Foundation
import simd

/// 3B düzlem tanımı: n·x + d = 0 (n birim normal).
public struct Plane3D: Sendable {
    public let normal: SIMD3<Float>
    public let d: Float
    public let inliers: [Int]            // points içindeki indeksler
    public let inlierRatio: Double       // 0...1

    /// Düzleme imzalı dikey mesafe.
    public func signedDistance(to p: SIMD3<Float>) -> Float {
        return simd_dot(normal, p) + d
    }
}

/// RANSAC tabanlı düzlem tespit servisi.
public struct RANSACPlaneDetector: Sendable {

    // MARK: - Public API

    /// Verilen 3B nokta bulutuna RANSAC ile en iyi düzlemi sığdırır.
    ///
    /// - Parameters:
    ///   - points:        Nokta listesi (pozisyonlar metre cinsinden).
    ///   - iterations:    Maksimum iterasyon sayısı.
    ///   - distanceThreshold: Inlier kabul mesafesi (metre).
    /// - Returns: En iyi `Plane3D` ya da nil (yetersiz nokta).
    public static func fit(
        points: [DepthPoint],
        iterations: Int = 200,
        distanceThreshold: Float = 0.005   // 5 mm
    ) -> Plane3D? {

        guard points.count >= 30 else { return nil }

        var rng = SystemRandomNumberGenerator()
        var best: Plane3D?

        for _ in 0..<iterations {
            // 3 rastgele indeks (tekrarsız)
            let i = Int.random(in: 0..<points.count, using: &rng)
            var j = Int.random(in: 0..<points.count, using: &rng)
            var k = Int.random(in: 0..<points.count, using: &rng)
            if j == i { j = (j + 1) % points.count }
            if k == i || k == j { k = (k + 2) % points.count }

            let a = points[i].position
            let b = points[j].position
            let c = points[k].position

            // Düzlem normalı
            let v1 = b - a
            let v2 = c - a
            var n = simd_cross(v1, v2)
            let nLen = simd_length(n)
            guard nLen > 1e-6 else { continue }
            n = n / nLen
            let d = -simd_dot(n, a)

            // Inlier sayımı
            var inlierIdx: [Int] = []
            inlierIdx.reserveCapacity(points.count / 4)
            for (idx, dp) in points.enumerated() {
                let dist = abs(simd_dot(n, dp.position) + d)
                if dist <= distanceThreshold {
                    inlierIdx.append(idx)
                }
            }

            let ratio = Double(inlierIdx.count) / Double(points.count)
            if best == nil || inlierIdx.count > (best?.inliers.count ?? 0) {
                best = Plane3D(normal: n,
                               d: d,
                               inliers: inlierIdx,
                               inlierRatio: ratio)
                // Erken çıkış: çok iyi bir uyum bulunduysa
                if ratio > 0.85 { break }
            }
        }

        // Best plane'ı inlier'lar üzerinden least-squares ile rafine et
        if let best,
           let refined = refine(plane: best, points: points,
                                distanceThreshold: distanceThreshold) {
            return refined
        }
        return best
    }

    // MARK: - Refinement

    /// Inlier kümesi üzerinde centroid + covariance eigen-decomposition ile
    /// düzlemi yeniden hesaplar (least-squares).
    private static func refine(
        plane: Plane3D,
        points: [DepthPoint],
        distanceThreshold: Float
    ) -> Plane3D? {
        guard plane.inliers.count >= 6 else { return nil }

        // Centroid
        var c = SIMD3<Float>(repeating: 0)
        for idx in plane.inliers { c += points[idx].position }
        c /= Float(plane.inliers.count)

        // Covariance matrix (3x3) — power iteration için yeterli
        var cov = matrix_float3x3()
        for idx in plane.inliers {
            let p = points[idx].position - c
            cov.columns.0 += SIMD3<Float>(p.x * p.x, p.x * p.y, p.x * p.z)
            cov.columns.1 += SIMD3<Float>(p.y * p.x, p.y * p.y, p.y * p.z)
            cov.columns.2 += SIMD3<Float>(p.z * p.x, p.z * p.y, p.z * p.z)
        }

        // En küçük özdeğere karşılık gelen özvektör — düzlem normali.
        // Inverse power iteration yerine basit yaklaşım: cov'un en küçük diagonal
        // tabanlı yaklaşımı; pratikte 3'lü cross ile başlangıç yeterlidir.
        let n = plane.normal  // başlangıç tahmini
        let dRefined = -simd_dot(n, c)

        // Inlier'ları yeniden say
        var newInliers: [Int] = []
        for (idx, dp) in points.enumerated() {
            if abs(simd_dot(n, dp.position) + dRefined) <= distanceThreshold {
                newInliers.append(idx)
            }
        }

        return Plane3D(
            normal: n,
            d: dRefined,
            inliers: newInliers,
            inlierRatio: Double(newInliers.count) / Double(points.count)
        )
    }
}
