//
//  SuccessToast.swift
//  Nuvyra Design System
//
//  Üstten slide-in toast bileşeni. Otomatik dismissal + haptic notify.
//  `.successToast(...)` modifier'ı ile herhangi bir view'a takılır.
//

import SwiftUI

// MARK: - Toast Model

public struct ToastConfig: Equatable {
    public enum Kind: Equatable { case success, info, warning, danger }

    public let title: String
    public let subtitle: String?
    public let kind: Kind
    public let duration: Double

    public init(
        title: String,
        subtitle: String? = nil,
        kind: Kind = .success,
        duration: Double = 2.4
    ) {
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.duration = duration
    }

    public var icon: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.octagon.fill"
        }
    }

    public var tint: Color {
        switch kind {
        case .success: return AppColors.success
        case .info:    return AppColors.info
        case .warning: return AppColors.warning
        case .danger:  return AppColors.danger
        }
    }
}

// MARK: - Toast View

public struct SuccessToast: View {

    public let config: ToastConfig
    public let onDismiss: () -> Void

    public init(config: ToastConfig, onDismiss: @escaping () -> Void) {
        self.config = config
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(config.tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: config.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(config.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(config.title)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(AppColors.textPrimary)
                if let subtitle = config.subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer(minLength: 8)
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(8)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            AppRadius.shape(AppRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    AppRadius.shape(AppRadius.lg)
                        .fill(AppColors.glassTint)
                )
        )
        .overlay(
            AppRadius.shape(AppRadius.lg)
                .stroke(AppColors.borderHairline, lineWidth: 1)
        )
        .clipShape(AppRadius.shape(AppRadius.lg))
        .shadow(AppShadow.toast)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(config.title)" + (config.subtitle.map { ". \($0)" } ?? ""))
    }
}

// MARK: - Modifier API

public struct ToastHostModifier: ViewModifier {

    @Binding public var config: ToastConfig?
    @State private var visible: Bool = false

    public func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let config, visible {
                SuccessToast(config: config) {
                    dismiss()
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, 8)
                .transition(
                    .move(edge: .top).combined(with: .opacity)
                )
                .zIndex(1000)
            }
        }
        .onChange(of: config) { _, new in
            guard new != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(notify(for: new))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                visible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (new?.duration ?? 2.4)) {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            config = nil
        }
    }

    private func notify(for cfg: ToastConfig?) -> UINotificationFeedbackGenerator.FeedbackType {
        switch cfg?.kind {
        case .success: return .success
        case .warning: return .warning
        case .danger:  return .error
        default:       return .success
        }
    }
}

public extension View {
    /// Bir Binding<ToastConfig?>'a takılı slide-in toast host.
    func successToast(_ config: Binding<ToastConfig?>) -> some View {
        modifier(ToastHostModifier(config: config))
    }
}

// MARK: - Preview

#if DEBUG
private struct ToastDemo: View {
    @State var toast: ToastConfig?
    var body: some View {
        ZStack {
            NuvyraPageBackground()
            VStack(spacing: 12) {
                PrimaryButton("Başarı toast") {
                    toast = .init(title: "Öğün eklendi",
                                  subtitle: "247 kcal · 12g protein", kind: .success)
                }
                SecondaryButton("Uyarı toast", style: .soft) {
                    toast = .init(title: "Su hedefi yaklaşıyor",
                                  subtitle: "500 ml kaldı", kind: .warning)
                }
            }
            .padding()
        }
        .successToast($toast)
    }
}

#Preview("Light") { ToastDemo().preferredColorScheme(.light) }
#Preview("Dark")  { ToastDemo().preferredColorScheme(.dark)  }
#endif
