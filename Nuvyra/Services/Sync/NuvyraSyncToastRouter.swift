import Foundation
import SwiftUI
import UIKit

/// Single place that knows how to turn a `NuvyraSyncError` into a
/// toast. Every CloudKit caller (`AddBodyMeasurementSheet`, workout
/// sync, meal sync, …) routes its `try await push(...)`
/// failure path through this helper so the user-facing copy + the
/// "open Settings" action stays consistent across the app.
///
/// The helper deliberately swallows `.iCloudUnavailable` and
/// `.noActiveAccount` — the user can't act on either at the moment
/// (the entitlement isn't carried by the current signing profile, and
/// the device's iCloud account state lives in system Settings).
/// `.quotaExceeded` becomes a tap-to-act toast that opens iCloud
/// Settings; `.networkFailure` and `.unexpected` surface as plain
/// error toasts so the user knows the local save still succeeded.
@MainActor
enum NuvyraSyncToastRouter {

    /// Route any error from a CloudKit push / fetch through the centre.
    /// Pass `centre: nil` to no-op silently — handy for background sync
    /// paths where surfacing UI would be intrusive.
    static func handle(
        _ error: Error,
        centre: NuvyraToastCenter?
    ) {
        guard let centre else { return }

        // Unknown error types funnel through `.unexpected` so the user
        // still gets a humane message rather than a stack trace.
        let mapped: NuvyraSyncError = (error as? NuvyraSyncError) ?? .unexpected

        switch mapped {
        case .iCloudUnavailable, .noActiveAccount:
            // Silent — there is no productive action the user can take
            // from inside Nuvyra. Surfacing a toast here would feel
            // like nagging.
            return

        case .quotaExceeded:
            centre.error(
                mapped.localizedDescription,
                action: NuvyraToast.Action(title: "Ayarlar") {
                    openSystemSettings()
                }
            )

        case .networkFailure:
            centre.error(mapped.localizedDescription)

        case .unexpected:
            centre.error(mapped.localizedDescription)
        }
    }

    /// Light wrapper around the standard "open this app's Settings"
    /// deeplink. iOS routes that URL to the system Settings panel for
    /// our bundle — from there the user can hop into the iCloud row.
    /// Fails gracefully if the URL ever stops being canOpen-able.
    private static func openSystemSettings() {
        guard
            let url = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(url)
        else { return }
        UIApplication.shared.open(url)
    }
}
