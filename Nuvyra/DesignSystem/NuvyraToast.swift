import SwiftUI

/// Glass-tinted notification toast. Three pieces:
///
/// - **`NuvyraToast`** is the value type. A toast is identifiable so
///   the centre can replace an in-flight one when a new event lands
///   on the same key (e.g. fresh water save toast on top of the old).
/// - **`NuvyraToastCenter`** is the ObservableObject that hosts the
///   active toast and handles queueing + auto-dismiss. Lives on the
///   environment via `@EnvironmentObject`.
/// - **`.nuvyraToastOverlay()`** is the View modifier the app root
///   applies once; it picks up the centre from the environment and
///   draws the toast above all content.
///
/// Why a centre instead of per-screen `actionFeedback` strings? Three
/// reasons:
///   1. The dashboard, nutrition and water screens all flash their own
///      home-grown overlay today. Different shape, different timing,
///      different swipe behaviour.
///   2. Replacing them with one centre + one renderer means there is
///      a single place to apply Liquid Glass + reduce-motion + haptic
///      polish.
///   3. Errors raised by services (NuvyraSyncError, AICoachError) can
///      be surfaced through the same channel without each screen
///      knowing how to render them.

// MARK: - Model

struct NuvyraToast: Identifiable {
    enum Kind: Equatable {
        case success
        case warning
        case error
        case info

        var tint: Color {
            switch self {
            case .success: NuvyraColors.accent
            case .warning: Color(red: 0.88, green: 0.62, blue: 0.18)
            case .error: NuvyraColors.mutedCoral
            case .info: NuvyraColors.softSand
            }
        }

        var systemImage: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.circle.fill"
            case .error: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }

        var hapticName: String {
            switch self {
            case .success: "success"
            case .warning: "warning"
            case .error: "warning"
            case .info: "selection"
            }
        }
    }

    /// Optional "tap-to-act" affordance. When set, the toast surface
    /// becomes tappable, draws a trailing chevron + label, and runs
    /// `handler` when the user accepts. We auto-dismiss the toast
    /// after the action fires so the celebration / surface clears.
    struct Action {
        /// Short verb shown on the trailing chip — defaults to "Aç".
        var title: String = "Aç"
        var handler: () -> Void
    }

    let id: UUID
    let kind: Kind
    let title: String
    /// Optional second line. Single-line toasts read faster; the
    /// second line is reserved for context the title can't carry.
    let detail: String?
    /// Total display time. Defaults to 2.4 s — long enough to read a
    /// short Turkish sentence, short enough to feel non-intrusive.
    let duration: TimeInterval
    /// Optional tap action — see `Action`. Toasts that carry one
    /// stay visible a beat longer so the user has time to react.
    let action: Action?

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        detail: String? = nil,
        duration: TimeInterval = 2.4,
        action: Action? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.duration = action != nil ? max(duration, 4.0) : duration
        self.action = action
    }
}

// MARK: - Centre

@MainActor
final class NuvyraToastCenter: ObservableObject {
    @Published private(set) var current: NuvyraToast?

    private var dismissTask: Task<Void, Never>?
    /// Anti-spam memory: the last (kind, title) we surfaced and when.
    /// Identical events fired inside `dedupeWindow` are suppressed so
    /// repeat refresh actions don't shower the user with toasts.
    private var lastShown: (key: String, at: Date)?
    private let dedupeWindow: TimeInterval = 5.0

    /// Pushes a toast onto the bar. If one is already visible it is
    /// replaced — the user only ever sees the latest event from the
    /// app, never a backlog. Identical (kind + title) repeats inside
    /// the dedupe window are dropped silently.
    func show(_ toast: NuvyraToast) {
        let key = dedupeKey(for: toast)
        if let lastShown,
           lastShown.key == key,
           Date().timeIntervalSince(lastShown.at) < dedupeWindow {
            return
        }
        lastShown = (key, Date())
        dismissTask?.cancel()
        current = toast
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            guard let self else { return }
            if self.current?.id == toast.id {
                self.current = nil
            }
        }
    }

    /// Same kind + same title forms one event for dedupe purposes. Two
    /// successive errors with different copies still both surface.
    private func dedupeKey(for toast: NuvyraToast) -> String {
        switch toast.kind {
        case .success: return "success:\(toast.title)"
        case .warning: return "warning:\(toast.title)"
        case .error: return "error:\(toast.title)"
        case .info: return "info:\(toast.title)"
        }
    }

    /// Convenience for the success-text-only path that most screens
    /// were already using ad-hoc.
    func success(_ message: String, action: NuvyraToast.Action? = nil) {
        show(NuvyraToast(kind: .success, title: message, action: action))
    }

    func warning(_ message: String, detail: String? = nil, action: NuvyraToast.Action? = nil) {
        show(NuvyraToast(kind: .warning, title: message, detail: detail, duration: 3.0, action: action))
    }

    func error(_ message: String, detail: String? = nil, action: NuvyraToast.Action? = nil) {
        show(NuvyraToast(kind: .error, title: message, detail: detail, duration: 3.2, action: action))
    }

    func info(_ message: String, action: NuvyraToast.Action? = nil) {
        show(NuvyraToast(kind: .info, title: message, action: action))
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - Renderer

extension View {
    /// Mount this once at the app root so every screen shares the same
    /// renderer. The centre is read from the environment object so
    /// any nested view can call `center.success(...)`.
    func nuvyraToastOverlay() -> some View {
        modifier(NuvyraToastOverlayModifier())
    }
}

private struct NuvyraToastOverlayModifier: ViewModifier {
    @EnvironmentObject private var center: NuvyraToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = center.current {
                    NuvyraToastView(toast: toast) { center.dismiss() }
                        .padding(.horizontal, NuvyraSpacing.lg)
                        .padding(.top, NuvyraSpacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.84), value: center.current?.id)
            // Pair each toast appearance with a matching Core Haptics
            // pulse so the user feels the same signal they read. iOS 17+
            // `.sensoryFeedback(_:trigger:)` handles the engine + dispose
            // dance for us and is a no-op when the user has disabled
            // system haptics.
            .sensoryFeedback(trigger: center.current?.id) { _, _ in
                guard let toast = center.current else { return nil }
                switch toast.kind {
                case .success: return .success
                case .warning: return .warning
                case .error:   return .error
                case .info:    return .selection
                }
            }
    }
}

private struct NuvyraToastView: View {
    @Environment(\.colorScheme) private var scheme
    let toast: NuvyraToast
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
        return HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            ZStack {
                Circle().fill(toast.kind.tint.opacity(scheme == .dark ? 0.22 : 0.16))
                Image(systemName: toast.kind.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(toast.kind.tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.bold))
                if let detail = toast.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let action = toast.action {
                // Trailing action pill — visually reads as "tap me",
                // and the whole row is hit-testable so the user can
                // tap the body too. Caret nudges the affordance
                // toward iOS-native row behaviour.
                HStack(spacing: 4) {
                    Text(action.title)
                        .font(.caption.weight(.bold))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(toast.kind.tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(toast.kind.tint.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, NuvyraSpacing.md)
        .padding(.vertical, NuvyraSpacing.sm)
        .background(.ultraThinMaterial, in: shape)
        .overlay(shape.stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.7))
        .overlay(
            shape
                .strokeBorder(NuvyraColors.specularHighlight(scheme), lineWidth: 1)
                .mask(LinearGradient(colors: [Color.black, Color.black.opacity(0)], startPoint: .top, endPoint: .center))
                .allowsHitTesting(false)
        )
        .nuvyraShadow(.floating, scheme: scheme)
        .contentShape(shape)
        .onTapGesture {
            guard let handler = toast.action?.handler else { return }
            handler()
            onDismiss()
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Allow drag-up to dismiss; clamp downward drag so
                    // the toast doesn't slide into the dashboard body.
                    dragOffset = min(value.translation.height, 0)
                }
                .onEnded { value in
                    if value.translation.height < -24 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toast.accessibilityPrefix)\(toast.title)")
        .accessibilityHint(toast.action == nil ? "Yukarı kaydırarak kapat." : "Açmak için dokun, kaydırarak kapat.")
    }
}

private extension NuvyraToast {
    var accessibilityPrefix: String {
        switch kind {
        case .success, .info:
            return ""
        case .warning:
            return "Uyarı: "
        case .error:
            return "Hata: "
        }
    }
}

#if DEBUG
#Preview("Toast variants") {
    struct DemoView: View {
        @StateObject private var center = NuvyraToastCenter()
        var body: some View {
            ZStack {
                NuvyraBackground(.animated)
                VStack(spacing: NuvyraSpacing.md) {
                    Spacer()
                    Button("Success") { center.success("250 ml su eklendi") }
                    Button("Warning") { center.warning("Premium analiz sınırına yaklaştın") }
                    Button("Error") { center.error("Kayıt başarısız", detail: "Yeniden bağlanmayı denedik, sonuç olmadı.") }
                    Button("Info") { center.info("Yarın için hatırlatma kuruldu") }
                    Spacer()
                }
                .buttonStyle(.borderedProminent)
            }
            .environmentObject(center)
            .nuvyraToastOverlay()
        }
    }
    return DemoView()
}
#endif
