//
//  ConfidenceIndicatorView.swift
//  Nuvyra - Portion Estimator
//
//  Düşük/Orta/Yüksek güvenilirlik göstergesi (üç çubuk + etiket).
//

import SwiftUI

/// Üç parçalı doluluk göstergesi.
public struct ConfidenceIndicatorView: View {

    // MARK: - Inputs

    /// Görüntülenecek güvenilirlik seviyesi.
    public let level: ConfidenceLevel

    // MARK: - Init

    /// SwiftUI içinde doğrudan oluşturulur.
    public init(level: ConfidenceLevel) {
        self.level = level
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: idx))
                        .frame(width: 6, height: barHeight(for: idx))
                }
            }
            Text(level.localizedLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55), in: Capsule())
    }

    // MARK: - Helpers

    private func barColor(for idx: Int) -> Color {
        let threshold = Double(idx + 1) / 3.0
        return level.fillRatio >= threshold - 0.001
            ? level.tintColor
            : .white.opacity(0.25)
    }

    private func barHeight(for idx: Int) -> CGFloat {
        switch idx {
        case 0:  return 8
        case 1:  return 12
        default: return 16
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        ConfidenceIndicatorView(level: .low)
        ConfidenceIndicatorView(level: .medium)
        ConfidenceIndicatorView(level: .high)
    }
    .padding()
    .background(.gray)
}
#endif
