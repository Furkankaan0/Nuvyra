import SwiftUI

struct DashboardQuickAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

struct QuickActionsRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var actions: [DashboardQuickAction]

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            ForEach(actions) { action in
                QuickActionPill(action: action, reduceMotion: reduceMotion)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QuickActionPill: View {
    @Environment(\.colorScheme) private var scheme
    var action: DashboardQuickAction
    var reduceMotion: Bool
    @State private var pressed = false

    var body: some View {
        Button {
            action.action()
        } label: {
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(action.tint.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: action.systemImage)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(action.tint)
                }
                Text(action.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(action.tint.opacity(0.22))
            )
            .shadow(color: NuvyraShadow.card(scheme), radius: 8, x: 0, y: 4)
            .scaleEffect(pressed ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion, !pressed else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = true }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pressed = false }
                }
        )
        .accessibilityLabel(action.title)
    }
}

#if DEBUG
#Preview {
    QuickActionsRail(actions: [
        DashboardQuickAction(title: "Yemek ekle", systemImage: "fork.knife", tint: NuvyraColors.accent, action: {}),
        DashboardQuickAction(title: "+250 ml su", systemImage: "drop.fill", tint: Color(red: 0.30, green: 0.70, blue: 0.95), action: {}),
        DashboardQuickAction(title: "AI Coach", systemImage: "sparkles", tint: NuvyraColors.softSand, action: {})
    ])
    .padding()
    .background(NuvyraBackground())
}
#endif
