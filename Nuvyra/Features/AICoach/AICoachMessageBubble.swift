import SwiftUI

struct AICoachMessageBubble: View {
    @Environment(\.colorScheme) private var scheme
    var message: AICoachMessage

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            if isUser { Spacer(minLength: 36) }

            if !isUser {
                AICoachOrb(size: 30)
                    .frame(width: 30, height: 30)
                    .padding(.top, 4)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.isTyping {
                    AICoachTypingIndicator()
                } else {
                    bubbleContent
                }
                if !message.isTyping {
                    Text(Self.timeFormatter.string(from: message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 36) }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "Sen" : "AI Coach"): \(message.content)")
    }

    private var bubbleContent: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isUser ? 18 : 4,
            bottomTrailingRadius: isUser ? 4 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
        return Text(message.content)
            .font(NuvyraTypography.body)
            .foregroundStyle(isUser ? Color.white : NuvyraColors.primaryText(scheme))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                if isUser {
                    LinearGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.softMint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .overlay(shape.stroke(isUser ? Color.clear : NuvyraColors.accent.opacity(0.18)))
            .shadow(color: NuvyraShadow.card(scheme), radius: 6, x: 0, y: 4)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        AICoachMessageBubble(message: AICoachMessage(role: .assistant, content: "Bugün su hedefine 600 ml kaldı. Küçük yudumlar dengeyi getirir.\n\n— Bilgilendirme amaçlıdır."))
        AICoachMessageBubble(message: AICoachMessage(role: .user, content: "Bugün ne yemeliyim?"))
        AICoachMessageBubble(message: AICoachMessage.typingPlaceholder())
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
