//
//  DepthProcessor.swift
//  Nuvyra - Portion Estimator
//
//  ARFrame'in sceneDepth/smoothedSceneDepth verisini alıp, bounding box
//  içindeki derinlik piksellerini 3B nokta bulutuna (kamera uzayı, metre)
//  çevirir ve Z-score outlier filtresi uygular.
//

import Foundation
import ARKit
import simd
import CoreVideo

/// Tek bir 3B noktanın temsili (kamera referans çerçevesinde, metre).
public struct DepthPoint: Sendable {
    public let position: SIMD3<Float>   // (x, y, z) — metre
    public let pixelX: Int
    public let pixelY: Int
}

/// Derinlik haritasından bounding box içi nokta bulutu üreten servis.
public struct DepthProcessor: Sendable {

    // MARK: - Public API

    /// Verilen ARFrame ve normalize bounding box için filtrelenmiş 3B nokta bulutu üretir.
    ///
    /// - Parameters:
    ///   - frame:        Anlık ARFrame.
    ///   - boundingBox:  Vision koordinatlarında bbox (0...1, alt-sol orijin).
    ///   - useSmoothed:  smoothedSceneDepth tercih edilsin mi (varsa).
    /// - Returns: (points, validityRatio) tuple'ı.
    ///   - points:         Outlier filtrelenmiş 3B nokta listesi.
    ///   - validityRatio:  Bbox içindeki geçerli derinlik pikseli oranı (0...1).
    public static func extractPoints(
        frame: ARFrame,
        boundingBox: CGRect,
        useSmoothed: Bool = true
    ) -> (points: [DepthPoint], validityRatio: Double) {

        // Derinlik kaynağını seç
        let depthData: ARDepthData? = {
            if useSmoothed, let s = frame.smoothedSceneDepth { return s }
            return frame.sceneDepth
        }()
        guard let depthData else {
            return ([], 0.0)
        }

        let depthMap = depthData.depthMap
        let width  = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddr = CVPixelBufferGetBaseAddress(depthMap) else {
            return ([], 0.0)
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // Confidence map (varsa)
        var confidencePtr: UnsafeMutablePointer<UInt8>?
        var confidenceRowBytes = 0
        if let conf = depthData.confidenceMap {
            CVPixelBufferLockBaseAddress(conf, .readOnly)
            confidencePtr = CVPixelBufferGetBaseAddress(conf)?
                .assumingMemoryBound(to: UInt8.self)
            confidenceRowBytes = CVPixelBufferGetBytesPerRow(conf)
        }
        defer {
            if let conf = depthData.confidenceMap {
                CVPixelBufferUnlockBaseAddress(conf, .readOnly)
            }
        }

        // Bbox'ı depth-map koordinatlarına çevir.
        // Vision bbox: alt-sol orijin (y yukarı). Depth pixel: üst-sol orijin.
        let xMin = max(0, Int(boundingBox.minX * CGFloat(width)))
        let xMax = min(width - 1, Int(boundingBox.maxX * CGFloat(width)))
        let yMinFlipped = max(0, Int((1.0 - boundingBox.maxY) * CGFloat(height)))
        let yMaxFlipped = min(height - 1, Int((1.0 - boundingBox.minY) * CGFloat(height)))

        guard xMax > xMin, yMaxFlipped > yMinFlipped else {
            return ([], 0.0)
        }

        // Kamera intrinsics + image resolution farklı olabilir; orantıla.
        let intrinsics = frame.camera.intrinsics
        let camRes = frame.camera.imageResolution
        let scaleX = Float(width)  / Float(camRes.width)
        let scaleY = Float(height) / Float(camRes.height)
        let fx = intrinsics[0, 0] * scaleX
        let fy = intrinsics[1, 1] * scaleY
        let cx = intrinsics[2, 0] * scaleX
        let cy = intrinsics[2, 1] * scaleY

        var points: [DepthPoint] = []
        points.reserveCapacity((xMax - xMin) * (yMaxFlipped - yMinFlipped))

        var totalPixels = 0
        var validPixels = 0

        for y in yMinFlipped...yMaxFlipped {
            let rowPtr = baseAddr
                .advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)

            for x in xMin...xMax {
                totalPixels += 1
                let z = rowPtr[x]

                // 0, NaN, çok yakın/uzak değerleri ele
                guard z.isFinite, z > 0.10, z < 5.0 else { continue }

                // Confidence yüksek değilse ele (varsa)
                if let confPtr = confidencePtr {
                    let confVal = confPtr[y * confidenceRowBytes + x]
                    if confVal < UInt8(ARConfidenceLevel.medium.rawValue) {
                        continue
                    }
                }

                validPixels += 1

                // Pinhole modelle 3B konuma çevir (kamera uzayı)
                let xCam = (Float(x) - cx) * z / fx
                let yCam = (Float(y) - cy) * z / fy
                let position = SIMD3<Float>(xCam, yCam, z)

                points.append(DepthPoint(position: position, pixelX: x, pixelY: y))
            }
        }

        let validity = totalPixels > 0
            ? Double(validPixels) / Double(totalPixels)
            : 0.0

        // Z-score outlier filtresi
        let filtered = removeOutliers(points: points, threshold: 2.0)
        return (filtered, validity)
    }

    // MARK: - Outlier Removal

    /// Z bileşenine göre Z-score > threshold olan noktaları eler.
    /// - Parameters:
    ///   - points:    Ham nokta listesi.
    ///   - threshold: Z-score eşik değeri (varsayılan 2.0).
    /// - Returns: Outlier'sız nokta listesi.
    public static func removeOutliers(
        points: [DepthPoint],
        threshold: Float
    ) -> [DepthPoint] {
        guard points.count > 8 else { return points }

        let zs = points.map { $0.position.z }
        let mean = zs.reduce(0, +) / Float(zs.count)
        let variance = zs.reduce(Float(0)) { $0 + ($1 - mean) * ($1 - mean) }
            / Float(zs.count)
        let std = sqrt(variance)
        guard std > 1e-5 else { return points }

        return points.filter { abs($0.position.z - mean) / std <= threshold }
    }
}
