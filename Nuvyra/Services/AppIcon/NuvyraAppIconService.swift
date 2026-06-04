import UIKit

/// The set of app icons Nuvyra currently ships.
///
/// Add alternate cases only after their matching `CFBundleAlternateIcons`
/// entries and raster icon files are bundled, otherwise App Store Connect
/// rejects the upload with invalid image path errors.
enum NuvyraAppIcon: String, CaseIterable, Identifiable {
    /// Default Apple-icon-name token. iOS treats `nil` as the primary icon.
    case `default`

    /// `nil` for the primary icon; UIKit insists on `nil` and not the
    /// string "default".
    var alternateKey: String? {
        switch self {
        case .default: nil
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: "Nuvyra"
        }
    }

    var subtitle: String {
        switch self {
        case .default: "Varsayilan"
        }
    }

    var previewSystemImage: String {
        switch self {
        case .default: "leaf.fill"
        }
    }
}

/// Thin actor-isolated wrapper around `UIApplication.setAlternateIconName`.
/// Centralised here so the call site doesn't have to remember the iOS
/// quirks (must run on the main actor; `nil` for primary; `supportsAlternateIcons`
/// can be false on older builds).
@MainActor
final class NuvyraAppIconService {
    static let shared = NuvyraAppIconService()

    var current: NuvyraAppIcon {
        let key = UIApplication.shared.alternateIconName
        return NuvyraAppIcon.allCases.first { $0.alternateKey == key } ?? .default
    }

    var supportsAlternates: Bool {
        UIApplication.shared.supportsAlternateIcons &&
            NuvyraAppIcon.allCases.contains { $0.alternateKey != nil }
    }

    /// Sets the alternate icon. Swallows `setAlternateIconName`'s error
    /// callback because the system already surfaces a sheet to the user
    /// on success/failure; bubbling a separate error would be noise.
    func apply(_ icon: NuvyraAppIcon) async {
        guard supportsAlternates else { return }
        guard icon.alternateKey != UIApplication.shared.alternateIconName else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateKey)
        } catch {
            // UIApplication shows its own system alert on failure; we
            // deliberately do not surface a separate Nuvyra toast so
            // the user sees one flow, not two.
        }
    }
}
