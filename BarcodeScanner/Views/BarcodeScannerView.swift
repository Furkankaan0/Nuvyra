//
//  BarcodeScannerView.swift
//  Nuvyra - Barcode Scanner
//
//  Modülün ana giriş noktası. Kamera + retikül + bottom sheet'te
//  loading/product/manual akışı.
//

import SwiftUI

/// Modülün public root view'i.
public struct BarcodeScannerView: View {

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BarcodeScannerViewModel
    private let onAddProduct: (ScannedProduct) -> Void

    // MARK: - Init

    /// Default constructor — kendi VM'ini oluşturur.
    /// Production'da credential'ları enjekte etmek için diğer init'i tercih edin.
    public init(
        viewModel: BarcodeScannerViewModel,
        onAddProduct: @escaping (ScannedProduct) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onAddProduct = onAddProduct
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            ScannerCameraView(previewLayer: viewModel.scanner.previewLayer)
                .ignoresSafeArea()

            scanReticule

            VStack {
                topBar
                Spacer()
                hint
            }
        }
        .task { await viewModel.startScanning() }
        .onDisappear { viewModel.stopScanning() }
        .sheet(isPresented: $viewModel.isSheetPresented) {
            sheetContent
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(false)
                .onDisappear { viewModel.resumeAfterSheet() }
        }
    }

    // MARK: - Subviews

    private var scanReticule: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            .frame(width: 280, height: 180)
            .shadow(color: .black.opacity(0.3), radius: 8)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Barkod taramayı kapat")

            Image(systemName: "barcode.viewfinder")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Barkodu çerçeveye hizalayın")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.4))
    }

    private var hint: some View {
        Group {
            if case .error(let msg) = viewModel.screenState {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            } else {
                Text("EAN-13 / EAN-8 / UPC-A / UPC-E / QR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private var sheetContent: some View {
        switch viewModel.screenState {
        case .loading:
            ProductSkeletonCard()
                .padding(.top, 8)
        case .product(let p):
            ProductCardSheet(
                product: p,
                onAdd: { product in
                    onAddProduct(product)
                    viewModel.resumeAfterSheet()
                    dismiss()
                },
                onCancel: { viewModel.resumeAfterSheet() }
            )
        case .notFound(let barcode):
            ManualProductEntryView(barcode: barcode) { product in
                Task {
                    await viewModel.saveManualEntry(product)
                    onAddProduct(product)
                    dismiss()
                }
            }
        case .error(let message):
            NuvyraErrorStateView(
                title: String(localized: "barcode.product.error.title"),
                message: message,
                onRetry: {
                    viewModel.retryLastScan()
                },
                onDismiss: {
                    viewModel.resumeAfterSheet()
                }
            )
            .padding(.top, 8)
        case .scanning:
            // Sheet açıkken bu state'lere düşmesi beklenmez
            EmptyView()
        }
    }
}
