//
//  InfoCardView.swift
//  Nuvyra - Portion Estimator
//
//  "Tahmini: 185g ± 28g | 267 kcal" şeklinde bilgi kartı + güvenilirlik
//  göstergesi.
//

import SwiftUI

/// Anlık tahmin kartı.
public struct InfoCardView: View {

    // MARK: - Inputs

    /// Görüntülenecek tahmin (nil ise placeholder gösterir).
    public let estimate: PortionEstimate?

    // MARK: - Init

    public init(estimate: PortionEstimate?) {
        self.estimate = estimate
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(foodTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let estimate {
                    ConfidenceIndicatorView(level: estimate.confidence)
                }
            }
            Text(summaryText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var foodTitle: String {
        guard let label = estimate?.foodLabel, !label.isEmpty, label != "default" else {
            return "Yemek taranıyor..."
        }
        return label.capitalized
    }

    private var summaryText: String {
        estimate?.displaySummary ?? "Tahmini: -- g | -- kcal"
    }
}
