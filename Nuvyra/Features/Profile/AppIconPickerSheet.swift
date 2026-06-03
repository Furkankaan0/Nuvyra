import SwiftUI

/// Bottom sheet that lets the user pick from Nuvyra's alternate app icons.
/// Each row is a `NuvyraGlassCard` with a glass medallion previewing the
/// icon (falls back to an SF Symbol when the raster asset isn't bundled
/// yet, so we can ship the UI before the artwork lands).
///
/// Selection is committed asynchronously through `NuvyraAppIconService`,
/// which calls UIKit's `setAlternateIconName`. iOS will pop its own
/// alert ("You have changed the icon for…") — we don't dismiss the
/// sheet until that completes, so the user sees one transition, not
/// two.
struct AppIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var selected: NuvyraAppIcon = .default
    @State private var isApplying: Bool = false

    var body: some View {
        ZStack {
            NuvyraBackground(.animated)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    ForEach(NuvyraAppIcon.allCases) { icon in
                        Button {
                            select(icon)
                        } label: {
                            row(for: icon)
                        }
                        .buttonStyle(.nuvyraPressTilt)
                        .disabled(isApplying)
                    }
                    if !NuvyraAppIconService.shared.supportsAlternates {
                        unsupportedNotice
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { selected = NuvyraAppIconService.shared.current }
        .navigationTitle("Uygulama ikonu")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Uygulama ikonu")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("Ana ekrandaki Nuvyra simgesini istediğin tona göre değiştir.")
                .font(NuvyraTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    private func row(for icon: NuvyraAppIcon) -> some View {
        NuvyraGlassCard(icon == selected ? .prominent : .regular) {
            HStack(spacing: NuvyraSpacing.md) {
                medallion(for: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(icon.title)
                        .font(.headline.weight(.bold))
                    Text(icon.subtitle)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: icon == selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(icon == selected ? NuvyraColors.accent : NuvyraColors.mutedGray.opacity(0.5))
                    .symbolEffect(.bounce, value: selected)
            }
        }
    }

    /// Squared medallion that previews each icon. Uses an SF Symbol stand-in
    /// while the raster asset is still pending — when the asset lands the
    /// `UIImage(named:)` lookup will succeed and the symbol disappears.
    @ViewBuilder
    private func medallion(for icon: NuvyraAppIcon) -> some View {
        let shape = RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
        ZStack {
            if let key = icon.alternateKey, let image = UIImage(named: key) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let image = UIImage(named: "AppIcon60x60") {
                // Primary icon has a bundled asset name we can render
                // verbatim — gives the `.default` row a real glyph.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Final fallback — SF Symbol placeholder. This is the
                // path active *before* alternate icon rasters land.
                Image(systemName: icon.previewSystemImage)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
            }
        }
        .frame(width: 56, height: 56)
        .background(NuvyraColors.accent.opacity(scheme == .dark ? 0.18 : 0.10))
        .clipShape(shape)
        .overlay(shape.stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6))
        .nuvyraShadow(.ambient, scheme: scheme)
    }

    private var unsupportedNotice: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(NuvyraColors.softSand)
                Text("Bu cihaz alternate icon değişimini desteklemiyor.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func select(_ icon: NuvyraAppIcon) {
        guard icon != selected, !isApplying else { return }
        selected = icon
        isApplying = true
        Task {
            await NuvyraAppIconService.shared.apply(icon)
            isApplying = false
        }
    }
}

#if DEBUG
#Preview {
    AppIconPickerSheet()
}
#endif
