import SwiftUI

/// Glass message bubble. Coach bubble is left-aligned with a tiny avatar; user
/// bubble is right-aligned with an accent gradient.
struct AICoachMessageBubble: View {
    @Environment(\.colorScheme) private var scheme
    var message: AICoachMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: NuvyraSpacing.sm) {
            if message.role == .coach {
                AICoachAvatar(size: 32)
                bubble(alignment: .leading)
                Spacer(minLength: 32)
            } else {
                Spacer(minLength: 32)
                bubble(alignment: .trailing)
            }
        }
    }

    private func bubble(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(message.text)
                .font(.subheadline)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(message.role == .user ? .white : .primary)
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(message.role == .user ? Color.white.opacity(0.75) : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(BubbleShape(role: message.role))
        .overlay(
            BubbleShape(role: message.role)
                .stroke(message.role == .coach ? NuvyraColors.accent.opacity(0.18) : Color.white.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "Sen" : "Koç"): \(message.text)")
    }

    @ViewBuilder
    private var background: some View {
        if message.role == .user {
            LinearGradient(
                colors: [NuvyraColors.accent, NuvyraColors.softMint],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
        }
    }
}

private struct BubbleShape: Shape {
    var role: AICoachMessage.Role

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tail: CGFloat = 6
        var path = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        // Small visual tail on the bottom corner depending on role
        let corner = CGPoint(
            x: role == .coach ? rect.minX : rect.maxX,
            y: rect.maxY - radius
        )
        path.addPath(Path { tailPath in
            tailPath.move(to: CGPoint(x: corner.x, y: corner.y))
            tailPath.addLine(to: CGPoint(x: corner.x + (role == .coach ? -tail : tail), y: rect.maxY - 4))
            tailPath.addLine(to: CGPoint(x: corner.x + (role == .coach ? tail : -tail), y: rect.maxY))
            tailPath.closeSubpath()
        })
        return path
    }
}

/// Three-dot typing indicator used while the coach is composing a reply.
struct CoachTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            AICoachAvatar(size: 32)
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(NuvyraColors.accent)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animate ? 1 : 0.5)
                        .opacity(animate ? 1 : 0.4)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.18),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 32)
        }
        .onAppear { animate = true }
        .accessibilityLabel("Koç yazıyor")
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.sm) {
            AICoachMessageBubble(message: AICoachMessage(role: .coach, text: "Bugünkü ritmin gayet iyi gidiyor. Akşam bir bardak su iyi olabilir."))
            AICoachMessageBubble(message: AICoachMessage(role: .user, text: "Akşam atıştırmasını nasıl azaltabilirim?"))
            CoachTypingIndicator()
        }
        .padding()
    }
}
#endif
