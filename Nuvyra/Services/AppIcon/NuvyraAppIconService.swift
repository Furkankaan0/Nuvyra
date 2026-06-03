import UIKit

/// The set of alternate app icons Nuvyra ships. Adding a new entry here
/// requires three things:
///   1. The `key` must match the `CFBundleAlternateIcons` dictionary key
///      added to `Nuvyra/Resources/Info.plist`.
///   2. A 60pt + 76pt 1x/2x/3x asset set must be added to the project's
///      icons folder (the placeholder catalogue in `Resources/AppIconFiles`).
///   3. The `previewSystemImage` is what the picker draws when the asset
///      isn't bundled yet — this lets us ship the UI scaffold first and
///      drop in the artwork later without breaking the screen.
enum NuvyraAppIcon: String, CaseIterable, Identifiable {
    /// Default Apple-icon-name token. iOS treats `nil` as the primary icon.
    case `default`
    case mint
    case sand
    case night

    /// `nil` for the primary icon — UIKit insists on `nil` and not the
    /// string "default".
    var alternateKey: String? {
        switch self {
        case .default: nil
        case .mint: "AppIcon-Mint"
        case .sand: "AppIcon-Sand"
        case .night: "AppIcon-Night"
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default: "Nuvyra"
        case .mint: "Mint"
        case .sand: "Soft Sand"
        case .night: "Gece"
        }
    }

    var subtitle: String {
        switch self {
        case .default: "Varsayılan"
        case .mint: "Sakin yeşil ton"
        case .sand: "Sıcak kum tonu"
        case .night: "Karanlık ekranlar için"
        }
    }

    /// Preview symbol used by the picker before / instead of the actual
    /// app icon asset. Lets the UI ship without raster artwork.
    var previewSystemImage: String {
        switch self {
        case .default: "leaf.fill"
        case .mint: "leaf.circle.fill"
        case .sand: "sun.haze.fill"
        case .night: "moon.stars.fill"
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
        UIApplication.shared.supportsAlternateIcons
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
