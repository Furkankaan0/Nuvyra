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
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Hızlı işlem", subtitle: "Tek dokunuşla bugünü besle.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(actions) { action in
                        QuickActionButton(action: action, reduceMotion: reduceMotion)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct QuickActionButton: View {
    @Environment(\.colorScheme) private var scheme
    var action: DashboardQuickAction
    var reduceMotion: Bool
    @State private var pressed = false

    var body: some View {
        Button {
            action.action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [action.tint, action.tint.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: action.tint.opacity(0.45), radius: 10, x: 0, y: 6)
                    Image(systemName: action.systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text(action.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 84)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(action.tint.opacity(0.18))
            )
            .scaleEffect(pressed ? 0.94 : 1)
            .rotation3DEffect(
                .degrees(pressed ? 6 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.4
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !reduceMotion else { return }
                    if !pressed {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = true }
                    }
                }
                .onEnded { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = false }
                }
        )
        .accessibilityLabel(action.title)
    }
}

#if DEBUG
#Preview {
    QuickActionsRail(actions: [
        DashboardQuickAction(title: "Yemek ekle", systemImage: "fork.knife", tint: NuvyraColors.accent, action: {}),
        DashboardQuickAction(title: "Barkod tara", systemImage: "barcode.viewfinder", tint: NuvyraColors.softSand, action: {}),
        DashboardQuickAction(title: "Sesle ekle", systemImage: "mic.fill", tint: NuvyraColors.mutedCoral, action: {}),
        DashboardQuickAction(title: "Su ekle", systemImage: "drop.fill", tint: Color(red: 0.30, green: 0.70, blue: 0.95), action: {}),
        DashboardQuickAction(title: "Su azalt", systemImage: "drop", tint: Color(red: 0.30, green: 0.70, blue: 0.95).opacity(0.7), action: {}),
        DashboardQuickAction(title: "Yürüyüş", systemImage: "figure.walk", tint: NuvyraColors.paleLime, action: {})
    ])
    .padding()
    .background(NuvyraBackground())
}
#endif
