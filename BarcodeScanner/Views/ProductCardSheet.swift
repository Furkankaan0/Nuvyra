//
//  ProductCardSheet.swift
//  Nuvyra - Barcode Scanner
//
//  Tarama sonrası slide-up bottom sheet — ürün kartı, makro detayları,
//  "Ekle" CTA, kaynak rozeti.
//

import SwiftUI

/// Bottom sheet ürün kartı.
public struct ProductCardSheet: View {

    // MARK: - Inputs

    public let product: ScannedProduct
    public let onAdd: (ScannedProduct) -> Void
    public let onCancel: () -> Void

    public init(
        product: ScannedProduct,
        onAdd: @escaping (ScannedProduct) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.product = product
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            grabber
            content
            actionBar
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Subviews

    private var grabber: some View {
        Capsule()
            .fill(.gray.opacity(0.3))
            .frame(width: 38, height: 4)
            .padding(.top, 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: product.imageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.secondarySystemBackground))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .lineLimit(2)
                    if let brand = product.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    sourceBadge
                }
                Spacer(minLength: 0)
            }

            Divider()

            macroGrid
        }
        .padding(20)
    }

    private var sourceBadge: some View {
        Text(product.source.displayLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    private var macroGrid: some View {
        HStack(spacing: 10) {
            macroCell(title: "Kalori",  value: product.caloriesPer100g, unit: "kcal", color: .orange)
            macroCell(title: "Protein", value: product.protein,         unit: "g",    color: .red)
            macroCell(title: "Yağ",     value: product.fat,             unit: "g",    color: .yellow)
            macroCell(title: "Karb.",   value: product.carbs,           unit: "g",    color: .blue)
        }
    }

    private func macroCell(title: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded())) \(unit)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(role: .cancel, action: onCancel) {
                Text("Vazgeç")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)

            Button {
                onAdd(product)
            } label: {
                Label("Ekle", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}
