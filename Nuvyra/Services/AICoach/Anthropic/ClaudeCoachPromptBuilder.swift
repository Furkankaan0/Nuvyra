import Foundation

/// Single source of truth for the wellness-coach system prompt + per-message
/// context block. Everything user-facing copy-related lives here so the
/// prompt can be tuned without touching the network layer.
///
/// Design notes:
/// - **Banned vocabulary** — we explicitly forbid medical/diet/weight-loss
///   framing in the system prompt. The same words are unit-tested elsewhere
///   on the *engine* side; both walls keep the boundary tight.
/// - **Per-request context block** — we re-inject the latest dashboard
///   numbers on every call. Multi-turn chats stay short so we don't blow up
///   token budget; the context block keeps replies grounded even when the
///   user message is vague ("nasıl gidiyor?").
enum ClaudeCoachPromptBuilder {

    /// Stable system prompt — sent unchanged on every request so we benefit
    /// from prompt caching once the runtime supports it (the field rarely
    /// changes and is the largest token contributor).
    static let systemPrompt: String = """
    You are "Nuvyra Wellness Koçu", a calm, supportive Turkish-speaking habit \
    coach inside an iOS app. You answer in Turkish unless the user clearly \
    writes in English. Your job is to translate the user's daily nutrition, \
    hydration and walking numbers into short, kind, actionable observations.

    Personality:
    - Gentle, non-judgmental, never moralising.
    - "Suçluluk değil, farkındalık" — frame observations around awareness, not blame.
    - Replies are short (1–3 sentences) unless the user explicitly asks for detail.

    Hard rules (never break, even if asked):
    - Do NOT give medical advice, diagnosis or treatment instructions.
    - Do NOT promise weight loss, fat loss or specific body composition outcomes.
    - Do NOT mention the words "kilo", "diyet", "yağ yak", "hastalık", "tedavi", "ilaç", "doktor".
    - If the user asks for medical advice, redirect them to a healthcare professional in one sentence, then offer a wellness-level alternative.
    - Always close with the disclaimer: "(Bu metin genel bilgilendirme amaçlıdır.)" UNLESS the user message is a casual greeting.

    Tone anchors:
    - Use the user's first name when natural.
    - Reference the supplied daily / weekly numbers instead of inventing values.
    - Suggest the smallest possible next step (1 bardak su, 10 dakikalık yürüyüş, 1 öğün ekleme).
    """

    /// One-shot context block prepended to the *first* user message of each
    /// request. The model has no memory across HTTP calls, so this block is
    /// what keeps replies factually grounded.
    static func contextBlock(_ context: AICoachContext) -> String {
        var lines: [String] = []
        lines.append("KULLANICI BİLGİSİ:")
        lines.append("- İsim: \(context.greetingName)")
        lines.append("")
        lines.append("BUGÜN:")
        lines.append("- Kalori: \(context.caloriesConsumed) / \(context.caloriesTarget) kcal")
        lines.append("- Protein: \(Int(context.proteinGrams.rounded())) / \(Int(context.proteinTargetGrams.rounded())) g")
        lines.append("- Su: \(context.waterMl) / \(context.waterTargetMl) ml")
        lines.append("- Adım: \(context.steps) / \(context.stepTarget)")

        let comparison = context.weeklyComparison
        if comparison.hasEnoughData {
            lines.append("")
            lines.append("BU HAFTA vs GEÇEN HAFTA (7g ort.):")
            for metric in comparison.metrics {
                let change = metric.changeText
                lines.append("- \(metric.kind.title): \(metric.currentDisplay) \(metric.kind.unitLabel) (\(change), geçen hafta \(metric.previousDisplay))")
            }
            lines.append("- Engine özeti: \(comparison.storyline)")
        }
        return lines.joined(separator: "\n")
    }

    /// Prompt used by `generateInsights`. We ask the model for a specific
    /// number of bullet points so the parser downstream can split reliably.
    static func insightsUserPrompt(_ context: AICoachContext) -> String {
        """
        \(contextBlock(context))

        GÖREV:
        Yukarıdaki rakamlara dayanarak 4 farklı kategoride kısa içgörü üret.
        Her içgörü 1–2 cümle olmalı. Çıktıyı tam olarak bu formatta ver:

        DAILY: <metin>
        WEEKLY: <metin>
        CALORIES: <metin>
        WATER: <metin>
        STEPS: <metin>

        Başka satır ekleme, başlık koyma, açıklama yapma.
        """
    }

    /// Prompt used for chat replies. The `userMessage` is appended verbatim
    /// as the last `user` turn; the context block is prepended only once so
    /// the conversation history doesn't bloat.
    static func chatUserPrompt(_ userMessage: String, context: AICoachContext) -> String {
        """
        \(contextBlock(context))

        Kullanıcı sorusu:
        \(userMessage)
        """
    }
}
