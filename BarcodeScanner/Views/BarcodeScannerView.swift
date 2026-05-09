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

    @StateObject private var viewModel: BarcodeScannerViewModel

    // MARK: - Init

    /// Default constructor — kendi VM'ini oluşturur.
    /// Production'da credential'ları enjekte etmek için diğer init'i tercih edin.
    public init(viewModel: BarcodeScannerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                onAdd: { _ in viewModel.resumeAfterSheet() },
                onCancel: { viewModel.resumeAfterSheet() }
            )
        case .notFound(let barcode):
            ManualProductEntryView(barcode: barcode) { product in
                Task {
                    await viewModel.saveManualEntry(product)
                }
            }
        case .scanning, .error:
            // Sheet açıkken bu state'lere düşmesi beklenmez
            EmptyView()
        }
    }
}
