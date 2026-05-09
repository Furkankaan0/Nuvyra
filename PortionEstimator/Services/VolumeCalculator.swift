//
//  VolumeCalculator.swift
//  Nuvyra - Portion Estimator
//
//  Tabak düzlemi referans alınarak, düzlem üstündeki noktaların yüksekliklerini
//  yüzey integrali (Riemann toplamı) ile hacme (cm³) dönüştürür.
//

import Foundation
import simd

/// Hacim hesabı sonucu.
public struct VolumeResult: Sendable {
    /// Hacim (cm³).
    public let volumeCm3: Double
    /// Hesapta kullanılan, düzlem üstündeki nokta sayısı.
    public let abovePlaneCount: Int
    /// Ortalama yükseklik (m) — debug ve kalite için.
    public let averageHeightMeters: Double
}

/// Tabak yüzeyi referansıyla yemek hacmini hesaplayan servis.
public struct VolumeCalculator: Sendable {

    // MARK: - Public API

    /// Verilen plane üstündeki noktaların integraliyle hacmi hesaplar.
    ///
    /// Yaklaşım:
    /// 1. Bbox'ın depth-pixel alanını NxM hücreye böl.
    /// 2. Her hücredeki noktaların ortalama yüksekliğini al.
    /// 3. Hücre alanı (m²) × ortalama yükseklik (m) = hücre hacmi (m³).
    /// 4. Toplamı m³ → cm³ dönüşümü ile döndür.
    ///
    /// - Parameters:
    ///   - points:       Filtrelenmiş 3B nokta bulutu.
    ///   - plane:        RANSAC ile bulunan tabak düzlemi.
    ///   - cameraImageRes: Kamera frame çözünürlüğü (intrinsics ile uyumlu).
    ///   - intrinsics:   Kamera intrinsic matrisi.
    ///   - boundingBox:  Vision normalize bbox (alan tahmini için).
    /// - Returns: Hacim sonucu.
    public static func calculate(
        points: [DepthPoint],
        plane: Plane3D,
        averageDepthZ: Float,
        intrinsics: simd_float3x3,
        boundingBoxAreaPx: Double,
        gridResolution: Int = 32
    ) -> VolumeResult {

        guard !points.isEmpty else {
            return VolumeResult(volumeCm3: 0, abovePlaneCount: 0, averageHeightMeters: 0)
        }

        // 1) Düzlemin "yukarı" yönü, kamera +Z ile aynı taraftaysa normal'i çevir
        // (yani gözleme dönük). Yemek noktalarının çoğunluğu pozitif tarafta olmalı.
        let testSide = points.reduce(0) { acc, dp in
            acc + (plane.signedDistance(to: dp.position) > 0 ? 1 : -1)
        }
        let n = (testSide < 0) ? -plane.normal : plane.normal
        let d = (testSide < 0) ? -plane.d : plane.d

        // 2) Düzlem üstü (yemek) noktalarını seç ve yüksekliklerini bul
        var heights: [Float] = []
        heights.reserveCapacity(points.count)
        for p in points {
            let h = simd_dot(n, p.position) + d
            // Tabak düzleminden en az 3 mm yukarıda olanları say
            if h > 0.003 {
                heights.append(h)
            }
        }

        guard !heights.isEmpty else {
            return VolumeResult(volumeCm3: 0, abovePlaneCount: 0, averageHeightMeters: 0)
        }

        let avgHeight = heights.reduce(0, +) / Float(heights.count)

        // 3) Bbox alanını metre² cinsinden tahmin et
        // Pinhole modelinde piksel başına metrik alan ≈ z² / (fx * fy)
        let fx = intrinsics[0, 0]
        let fy = intrinsics[1, 1]
        let metersPerPixelArea = (averageDepthZ * averageDepthZ) / (fx * fy)
        let bboxAreaM2 = Float(boundingBoxAreaPx) * metersPerPixelArea

        // 4) Yüzey integrali — düzlem üstü dolu oran:
        // Toplam bbox alanı * (heights.count / totalPoints) yaklaşımıyla
        // dolu alan tahmini, sonra ortalama yükseklikle çarpıyoruz.
        let coverageRatio = Float(heights.count) / Float(points.count)
        let foodAreaM2 = bboxAreaM2 * coverageRatio
        let volumeM3 = Double(foodAreaM2 * avgHeight)

        // m³ → cm³
        let volumeCm3 = volumeM3 * 1_000_000.0

        return VolumeResult(
            volumeCm3: max(0, volumeCm3),
            abovePlaneCount: heights.count,
            averageHeightMeters: Double(avgHeight)
        )
    }
}
