//
//  BarcodeScannerViewModel.swift
//  Nuvyra - Barcode Scanner
//
//  Tarama motoru + besin API servisi arasında orkestrasyon yapan
//  @MainActor ObservableObject.
//

import Foundation
import SwiftUI

/// Tarayıcı pipeline durumu.
public enum ScannerScreenState: Equatable, Sendable {
    case scanning
    case loading(barcode: String)
    case product(ScannedProduct)
    case notFound(barcode: String)
    case error(String)
}

@MainActor
public final class BarcodeScannerViewModel: ObservableObject {

    // MARK: - Published

    @Published public private(set) var screenState: ScannerScreenState = .scanning
    @Published public var isSheetPresented: Bool = false

    // MARK: - Dependencies

    public let scanner: BarcodeScannerService
    public let api: NutritionAPIService
    private var lastScannedBarcode: String?

    // MARK: - Init

    /// Yeni bir VM oluşturur.
    public init(scanner: BarcodeScannerService, api: NutritionAPIService) {
        self.scanner = scanner
        self.api = api
        self.scanner.delegate = self
    }

    // MARK: - Lifecycle

    /// Kamerayı hazırlar ve oturumu başlatır.
    public func startScanning() async {
        do {
            try await scanner.prepare()
            scanner.start()
            screenState = .scanning
        } catch {
            screenState = .error(error.localizedDescription)
        }
    }

    /// Oturumu durdurur (View kaybolduğunda).
    public func stopScanning() {
        scanner.stop()
    }

    /// Bottom sheet kapandığında kamerayı tekrar açar.
    public func resumeAfterSheet() {
        isSheetPresented = false
        screenState = .scanning
        scanner.resume()
    }

    public func retryLastScan() {
        guard let lastScannedBarcode else {
            resumeAfterSheet()
            return
        }
        processBarcode(lastScannedBarcode)
    }

    /// Manuel girişten kaydet.
    public func saveManualEntry(_ product: ScannedProduct) async {
        await api.saveManual(product)
        screenState = .product(product)
        isSheetPresented = true
    }

    // MARK: - Pipeline

    /// Bir barkod yakalandığında çağrılır: shimmer → API → bottom sheet.
    private func processBarcode(_ barcode: String) {
        lastScannedBarcode = barcode
        screenState = .loading(barcode: barcode)
        isSheetPresented = true

        Task { [api] in
            do {
                let product = try await api.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.screenState = .product(product)
                }
            } catch NutritionAPIError.notFoundInAnyProvider {
                await MainActor.run {
                    self.screenState = .notFound(barcode: barcode)
                }
            } catch NutritionAPIError.offlineAndNotCached {
                await MainActor.run {
                    self.screenState = .error("İnternet yok ve barkod önbellekte yok.")
                }
            } catch {
                await MainActor.run {
                    self.screenState = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - BarcodeScannerDelegate

extension BarcodeScannerViewModel: BarcodeScannerDelegate {

    public func scanner(_ scanner: BarcodeScannerService, didScan barcode: String) {
        processBarcode(barcode)
    }

    public func scanner(_ scanner: BarcodeScannerService, didFailWith error: Error) {
        screenState = .error(error.localizedDescription)
    }
}
