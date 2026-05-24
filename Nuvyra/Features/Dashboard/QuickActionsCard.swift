import SwiftUI

enum DashboardQuickAction: String, CaseIterable, Identifiable {
    case addMeal
    case scanBarcode
    case voiceLog
    case addWater
    case removeWater
    case startWalking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addMeal: "Yemek ekle"
        case .scanBarcode: "Barkod tara"
        case .voiceLog: "Sesle ekle"
        case .addWater: "Su ekle"
        case .removeWater: "Su azalt"
        case .startWalking: "Yürüyüş başlat"
        }
    }

    var systemImage: String {
        switch self {
        case .addMeal: "fork.knife"
        case .scanBarcode: "barcode.viewfinder"
        case .voiceLog: "mic.fill"
        case .addWater: "drop.fill"
        case .removeWater: "drop"
        case .startWalking: "figure.walk"
        }
    }

    var tint: Color {
        switch self {
        case .addMeal: NuvyraColors.accent
        case .scanBarcode: NuvyraColors.mutedCoral
        case .voiceLog: NuvyraColors.softSand
        case .addWater: Color(red: 0.30, green: 0.66, blue: 0.95)
        case .removeWater: Color(red: 0.45, green: 0.70, blue: 0.80)
        case .startWalking: NuvyraColors.paleLime
        }
    }
}

struct QuickActionsCard: View {
    var onAction: (DashboardQuickAction) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: NuvyraSpacing.sm),
        GridItem(.flexible(), spacing: NuvyraSpacing.sm),
        GridItem(.flexible(), spacing: NuvyraSpacing.sm)
    ]

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Hızlı işlemler", subtitle: "Tek dokunuşla kaydet")
                LazyVGrid(columns: columns, spacing: NuvyraSpacing.sm) {
                    ForEach(DashboardQuickAction.allCases) { action in
                        QuickActionButton(action: action) { onAction(action) }
                    }
                }
            }
        }
    }
}

private struct QuickActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var pressed = false

    var action: DashboardQuickAction
    var onTap: () -> Void

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55)) {
                pressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) {
                    pressed = false
                }
                onTap()
            }
        } label: {
            VStack(spacing: NuvyraSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(action.tint.opacity(scheme == .dark ? 0.22 : 0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: action.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(action.tint)
                }
                Text(action.title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, NuvyraSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(action.tint.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

#if DEBUG
#Preview("Quick actions") {
    ZStack {
        NuvyraBackground()
        QuickActionsCard { _ in }.padding()
    }
}
#endif
