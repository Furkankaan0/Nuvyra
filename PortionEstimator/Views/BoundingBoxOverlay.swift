//
//  BoundingBoxOverlay.swift
//  Nuvyra - Portion Estimator
//
//  Vision normalize bbox'ı ekran koordinatlarına çevirip yarı saydam
//  yeşil bir dikdörtgen olarak çizer.
//

import SwiftUI

/// Tespit edilen yemek alanını gösteren yarı saydam yeşil overlay.
public struct BoundingBoxOverlay: View {

    // MARK: - Inputs

    /// Vision normalize bbox (0...1, alt-sol orijin) — nil iken görünmez.
    public let normalizedBox: CGRect?

    // MARK: - Init

    public init(normalizedBox: CGRect?) {
        self.normalizedBox = normalizedBox
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            if let bbox = normalizedBox {
                let rect = Self.convert(bbox: bbox, in: geo.size)
                ZStack {
                    Rectangle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: rect.width, height: rect.height)
                    Rectangle()
                        .stroke(Color.green.opacity(0.85), lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                }
                .position(x: rect.midX, y: rect.midY)
                .animation(.easeOut(duration: 0.18), value: bbox)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    /// Vision bbox'ı (alt-sol orijinli, normalize) view koordinatına (üst-sol)
    /// dönüştürür.
    public static func convert(bbox: CGRect, in size: CGSize) -> CGRect {
        let x = bbox.minX * size.width
        let w = bbox.width * size.width
        let h = bbox.height * size.height
        let y = (1.0 - bbox.maxY) * size.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
