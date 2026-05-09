//
//  PortionEstimatorView.swift
//  Nuvyra - Portion Estimator
//
//  Modülün ana giriş noktası. AR canvası + bbox overlay + bilgi kartı +
//  fallback yönlendirmesi.
//

import SwiftUI

/// Porsiyon tahmin modülünün public root view'i.
public struct PortionEstimatorView: View {

    // MARK: - State

    @StateObject private var viewModel: PortionEstimatorViewModel

    // MARK: - Init

    /// Default constructor — modül kendi VM'ini oluşturur.
    public init() {
        _viewModel = StateObject(wrappedValue: PortionEstimatorViewModel())
    }

    /// Test ya da DI için custom VM ile constructor.
    public init(viewModel: PortionEstimatorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        Group {
            switch viewModel.state {
            case .manualFallback:
                ManualEntryView { grams, food in
                    viewModel.submitManualEntry(grams: grams, foodKey: food)
                }
            default:
                arBody
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: - AR Body

    private var arBody: some View {
        ZStack {
            // 1) AR Canvas (kamera + scene reconstruction)
            ARContainerView(sessionManager: viewModel.sessionManager)
                .ignoresSafeArea()

            // 2) Yemek bbox overlay
            BoundingBoxOverlay(normalizedBox: viewModel.lastBoundingBox)
                .ignoresSafeArea()

            // 3) Üst başlık
            VStack {
                topBar
                Spacer()
                bottomCard
            }
            .padding(.vertical, 12)
        }
        .background(.black)
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Image(systemName: "viewfinder.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.85))
            Text(stateText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            if case .ready = viewModel.state {
                Button {
                    viewModel.stop()
                    viewModel.start()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.5), in: Circle())
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var bottomCard: some View {
        VStack(spacing: 8) {
            if case let .failed(message) = viewModel.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
            }
            InfoCardView(estimate: viewModel.currentEstimate)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private var stateText: String {
        switch viewModel.state {
        case .idle:           return "Hazırlanıyor..."
        case .scanning:       return "Tabağı tara"
        case .detecting:      return "Yemek tespit ediliyor..."
        case .computing:      return "Hacim hesaplanıyor..."
        case .ready:          return "Ölçüm hazır"
        case .manualFallback: return "Manuel giriş"
        case .failed:         return "Hata"
        }
    }
}

#if DEBUG
#Preview {
    PortionEstimatorView()
}
#endif
