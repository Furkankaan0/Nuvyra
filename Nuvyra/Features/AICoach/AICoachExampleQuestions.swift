import SwiftUI

struct AICoachExampleQuestions: View {
    @Environment(\.colorScheme) private var scheme
    var questions: [AICoachExampleQuestion]
    var onSelect: (AICoachExampleQuestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Örnek sorular")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(questions) { question in
                        Button {
                            onSelect(question)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: question.systemImage)
                                    .font(.caption.weight(.bold))
                                Text(question.text)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .foregroundStyle(NuvyraColors.accent)
                            .background(NuvyraColors.accent.opacity(0.10), in: Capsule())
                            .overlay(Capsule().stroke(NuvyraColors.accent.opacity(0.22)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    static let defaults: [AICoachExampleQuestion] = [
        AICoachExampleQuestion(text: "Bugün ne yemeliyim?", systemImage: "fork.knife"),
        AICoachExampleQuestion(text: "Protein hedefimi nasıl yakalarım?", systemImage: "bolt.heart"),
        AICoachExampleQuestion(text: "Su tüketimim nasıl gidiyor?", systemImage: "drop.fill"),
        AICoachExampleQuestion(text: "Adım hedefim için ne yapmalıyım?", systemImage: "figure.walk"),
        AICoachExampleQuestion(text: "Haftalık ritmim nasıl?", systemImage: "calendar")
    ]
}

#if DEBUG
#Preview {
    AICoachExampleQuestions(questions: AICoachExampleQuestions.defaults) { _ in }
        .padding()
        .background(NuvyraBackground())
}
#endif
