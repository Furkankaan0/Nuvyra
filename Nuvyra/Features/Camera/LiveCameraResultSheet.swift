import SwiftUI

/// Canlı kamerada bir tahmin seçildiğinde açılan slide-up bottom sheet.
/// `BarcodeScanner.ProductCardSheet` ile aynı görsel dile sahiptir — kullanıcı
/// için iki akış arasında bir bağlam farkı olmamalı.
///
/// State makinesi:
/// - `.loading(label)` → shimmer + label başlığı
/// - `.loaded(label, estimate)` → kcal/protein/karb/şeker grid + Ekle CTA
/// - `.failed(label, message)` → hata mesajı + Tekrar Dene
struct LiveCameraResultSheet: View {
    let state: CameraViewModel.DetectionPickState
    let onAdd: (EstimatedMealResult) -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            grabber
            content
            actionBar
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: -4)
    }

    // MARK: - Subviews

    private var grabber: some View {
        Capsule()
            .fill(.gray.opacity(0.3))
            .frame(width: 38, height: 4)
            .padding(.top, 10)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading(let label):
            loadingContent(label: label)
        case .loaded(_, let estimate):
            loadedContent(estimate: estimate)
        case .failed(let label, let message):
            failedContent(label: label, message: message)
        }
    }

    private func loadingContent(label: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.headline)
                        .lineLimit(2)
                    Text("Besin değerleri hazırlanıyor…")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                ProgressView()
            }
            Divider()
            shimmerGrid
        }
        .padding(20)
    }

    private func loadedContent(estimate: EstimatedMealResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(estimate.name)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(estimate.portion) • %\(Int((estimate.confidence * 100).rounded())) güven")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    estimatedBadge
                }
                Spacer(minLength: 0)
            }

            Divider()

            Text("100 g için besin değerleri")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            macroGrid(estimate: estimate)

            if let fiber = estimate.fiber {
                detailRow(title: "Lif", value: fiber, unit: "g")
            }
        }
        .padding(20)
    }

    private func failedContent(label: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                Text(label)
                    .font(.headline)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var estimatedBadge: some View {
        Text("Tahmini değer")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    private var shimmerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.tertiarySystemBackground), lineWidth: 1)
                    )
            }
        }
    }

    private func macroGrid(estimate: EstimatedMealResult) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            macroCell(title: "Kalori", value: Double(estimate.calories), unit: "kcal", color: .orange)
            macroCell(title: "Protein", value: estimate.protein, unit: "g", color: .red)
            macroCell(title: "Karbonhidrat", value: estimate.carbs, unit: "g", color: .blue)
            macroCell(title: "Şeker", value: estimate.sugar ?? 0, unit: "g", color: .pink)
        }
    }

    private func macroCell(title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
    }

    private func detailRow(title: String, value: Double, unit: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionBar: some View {
        switch state {
        case .loading:
            HStack(spacing: 12) {
                Button(role: .cancel, action: onCancel) {
                    Text("Vazgeç").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        case .loaded(_, let estimate):
            HStack(spacing: 12) {
                Button(role: .cancel, action: onCancel) {
                    Text("Vazgeç").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    onAdd(estimate)
                } label: {
                    Label("Ekle", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("\(estimate.name) öğüne ekle")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        case .failed:
            HStack(spacing: 12) {
                Button(role: .cancel, action: onCancel) {
                    Text("Vazgeç").frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button(action: onRetry) {
                    Label("Tekrar dene", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
