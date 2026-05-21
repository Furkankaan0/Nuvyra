import Foundation

final class MockAICoachService: AICoachService {
    private let typingDelay: TimeInterval

    init(typingDelay: TimeInterval = 0.9) {
        self.typingDelay = typingDelay
    }

    func dailyInsights(context: AICoachContext) async -> [AICoachInsight] {
        var insights: [AICoachInsight] = []

        insights.append(buildDailyInsight(context: context))
        insights.append(buildWeeklyInsight(context: context))
        insights.append(buildCalorieInsight(context: context))
        insights.append(buildMacroInsight(context: context))
        insights.append(buildWaterInsight(context: context))
        insights.append(buildStepsInsight(context: context))

        return insights
    }

    func reply(to question: String, history: [AICoachMessage], context: AICoachContext) async throws -> AICoachMessage {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AICoachError.invalidInput }

        try? await Task.sleep(nanoseconds: UInt64(typingDelay * 1_000_000_000))

        let lower = trimmed.lowercased(with: Locale(identifier: "tr_TR"))
        let body = generateReply(for: lower, context: context)
        return AICoachMessage(role: .assistant, content: body)
    }

    private func generateReply(for lowerQuestion: String, context: AICoachContext) -> String {
        let footer = "\n\n— \(AICoachSafetyDisclaimer.short)"

        if lowerQuestion.contains("kilo") {
            return """
            Kilo değişimi tek bir günde değil, haftalık ritmin üzerinden okunur. Bugünkü verine baktığımda \(caloriesSentence(context)) ve \(stepsSentence(context)). Sürdürülebilir tempoyu hedefleyen küçük tutarlı adımlar genelde daha uzun ömürlüdür. Kilo verme garantisi veremem; bu süreçte bir uzmanla görüşmen tempoyu kişiselleştirmenize yardımcı olabilir.\(footer)
            """
        }

        if lowerQuestion.contains("kalori") {
            return """
            Bugün \(context.caloriesConsumed) kcal aldın, hedefin \(context.calorieTarget) kcal. \(remainingCaloriesSentence(context)) Akşam öğününde dengeli bir kombinasyon (protein + lif) ritmini yumuşak tutar.\(footer)
            """
        }

        if lowerQuestion.contains("protein") {
            return proteinReply(context: context, footer: footer)
        }

        if lowerQuestion.contains("karbon") || lowerQuestion.contains("karb") {
            return """
            Karbonhidrat alımın \(Int(context.carbsGrams)) g, hedefin \(Int(context.carbsTargetGrams)) g. Karbonhidratlar enerji için temel kaynaktır; tam tahıl, baklagil ve sebzeler gibi liften zengin seçimler tokluk hissini uzatır.\(footer)
            """
        }

        if lowerQuestion.contains("yağ") {
            return """
            Yağ alımın bugün \(Int(context.fatGrams)) g (hedef \(Int(context.fatTargetGrams)) g). Sağlıklı yağlar (zeytinyağı, fındık, balık) hem doygunluk hem temel besin emilimi için faydalı.\(footer)
            """
        }

        if lowerQuestion.contains("su") {
            return """
            Bugün \(context.waterMl) ml su içtin, hedefin \(context.waterTargetMl) ml. \(waterSentence(context)) Tek seferde değil, gün boyunca küçük yudumlar ritmi korumana yardımcı olur.\(footer)
            """
        }

        if lowerQuestion.contains("adım") || lowerQuestion.contains("yürü") {
            return """
            \(context.steps.formatted()) adım attın, hedefin \(context.stepGoal.formatted()). \(stepsSentence(context)) Kısa yürüyüş molaları hem zihinsel hem fiziksel ritmi destekler.\(footer)
            """
        }

        if lowerQuestion.contains("uyku") || lowerQuestion.contains("yorgun") {
            return """
            Yorgunluğun pek çok sebebi olabilir; düzenli su tüketimi, dengeli öğünler ve yürüyüş genelde günlük enerjini destekler. Sürekli yorgunluk hissediyorsan bir sağlık profesyoneliyle görüşmek doğru bir adım olur.\(footer)
            """
        }

        if lowerQuestion.contains("öneri") || lowerQuestion.contains("ne yap") || lowerQuestion.contains("nasıl") {
            return """
            Bugünün ritmine baktığımda en hızlı denge sağlayacak küçük adım: \(quickWinSentence(context)). Bu tarz tek bir küçük adım kümülatif olarak büyük fark yaratabilir.\(footer)
            """
        }

        return """
        Ne demek istediğini anlamaya çalışıyorum. Şu an bilgilendirme amaçlı yanıt verebiliyorum; tıbbi soruları bir uzmana sormak daha doğru olur. Bugünkü ritmine bakacak olursak: \(caloriesSentence(context)), \(waterSentence(context)) ve \(stepsSentence(context)).\(footer)
        """
    }

    private func proteinReply(context: AICoachContext, footer: String) -> String {
        let progress = context.proteinTargetGrams > 0 ? context.proteinGrams / context.proteinTargetGrams : 0
        let suggestion: String
        if progress < 0.4 {
            suggestion = "Hedefinin epey altındasın. Yumurta, yoğurt, mercimek veya tavuk gibi seçenekler dengeyi yakalamana yardımcı olur."
        } else if progress < 0.8 {
            suggestion = "İyi yoldasın. Akşam öğününde küçük bir protein takviyesi (örn. yoğurt) hedefini rahat tamamlar."
        } else {
            suggestion = "Protein hedefine yakın ya da ulaştın. Kalan günde sıvı ve sebze alımına odaklanmak ritmini destekler."
        }
        return "Bugün \(Int(context.proteinGrams)) g protein aldın (hedef \(Int(context.proteinTargetGrams)) g). \(suggestion)\(footer)"
    }

    private func buildDailyInsight(context: AICoachContext) -> AICoachInsight {
        let detail: String
        if context.caloriesConsumed == 0 && context.steps == 0 {
            detail = "Bugüne henüz başlamadın. Küçük bir öğün veya kısa bir yürüyüş günün ritmini açabilir."
        } else if context.steps >= context.stepGoal && context.waterMl >= context.waterTargetMl {
            detail = "Adım ve su hedeflerini tamamladın. Akşamı sakin kapatmak yeterli."
        } else {
            detail = "Bugünkü ritmin dengeli ilerliyor. Sıradaki küçük hareket: \(quickWinSentence(context))"
        }
        return AICoachInsight(category: .daily, headline: "Bugün için kısa not", detail: detail)
    }

    private func buildWeeklyInsight(context: AICoachContext) -> AICoachInsight {
        let detail: String
        if context.steps >= context.stepGoal {
            detail = "Bu hafta yürüyüş ritmin güçlü görünüyor. Tutarlılık genelde haftalık verinin en kıymetli işaretidir."
        } else if context.caloriesConsumed > context.calorieTarget {
            detail = "Bugün hedefin biraz üzerindesin. Haftalık ortalamada birkaç günlük denge çoğu zaman yeterli olur."
        } else {
            detail = "Haftalık gidişatın için birkaç gün daha kayıt biriktirmemiz iyi olur. Tutarlı kayıt, daha net içgörü demek."
        }
        return AICoachInsight(category: .weekly, headline: "Haftaya genel bakış", detail: detail)
    }

    private func buildCalorieInsight(context: AICoachContext) -> AICoachInsight {
        let remaining = max(context.calorieTarget - context.caloriesConsumed + context.burnedKcal, 0)
        let detail: String
        if context.caloriesConsumed == 0 {
            detail = "Henüz öğün eklemedin. İlk kayıt sonrası kalori dengen burada belirir."
        } else if context.caloriesConsumed > context.calorieTarget + context.burnedKcal {
            detail = "Bugün hedefini aştın. Akşamı hafif bir öğünle kapatmak ritmini yumuşatır."
        } else {
            detail = "Hedefe \(remaining) kcal kaldı. Akşam öğününde dengeli bir tabak iyi bir kapanış olabilir."
        }
        return AICoachInsight(category: .calories, headline: "Kalori dengesi", detail: detail)
    }

    private func buildMacroInsight(context: AICoachContext) -> AICoachInsight {
        let proteinProgress = context.proteinTargetGrams > 0 ? context.proteinGrams / context.proteinTargetGrams : 0
        let detail: String
        if proteinProgress < 0.4 {
            detail = "Protein alımın hedefin yarısının altında. Yoğurt, yumurta veya baklagil seçenekleri dengeyi destekler."
        } else if context.fatGrams > context.fatTargetGrams * 1.2 {
            detail = "Yağ alımın hedefini biraz aşmış. Akşamda hafif sebze ağırlıklı bir tabak günü dengeleyebilir."
        } else {
            detail = "Makrolar arası dağılım dengeli görünüyor. Tutarlı bu ritim genelde uzun vadede en iyi sonucu verir."
        }
        return AICoachInsight(category: .macros, headline: "Makro dağılımı", detail: detail)
    }

    private func buildWaterInsight(context: AICoachContext) -> AICoachInsight {
        let detail: String
        if context.waterTargetMl == 0 {
            detail = "Henüz su hedefin tanımlı değil. Profilden hedef ekleyince burada özel öneri görürsün."
        } else if context.waterMl >= context.waterTargetMl {
            detail = "Su hedefini tamamladın. Akşam birer küçük yudumla devam etmek yeterli."
        } else if context.waterMl < context.waterTargetMl / 2 {
            detail = "Bugün su tüketimin günün yarısının altında. Önündeki saatlerde küçük yudumlar dengeyi getirir."
        } else {
            detail = "Su ritmin dengeli ilerliyor. Hedefe \(max(context.waterTargetMl - context.waterMl, 0)) ml kaldı."
        }
        return AICoachInsight(category: .water, headline: "Su tüketimi", detail: detail)
    }

    private func buildStepsInsight(context: AICoachContext) -> AICoachInsight {
        let detail: String
        if context.stepGoal == 0 {
            detail = "Adım hedefin tanımlı değil. Profilden hedef ekleyince burada özel yorum görürsün."
        } else if context.steps >= context.stepGoal {
            detail = "Bugünkü adım hedefin tamamlandı. Akşamı kısa bir yürüyüşle nazikçe kapatmak ritmi destekler."
        } else if context.steps > context.stepGoal / 2 {
            detail = "Adım ritmin iyi gidiyor. Akşam kısa bir yürüyüş hedefi rahat tamamlar."
        } else {
            detail = "Bugün hareket ritmin biraz düşük. 10 dakikalık bir yürüyüş bile dengeyi açar."
        }
        return AICoachInsight(category: .steps, headline: "Yürüyüş yorumu", detail: detail)
    }

    private func caloriesSentence(_ ctx: AICoachContext) -> String {
        let remaining = max(ctx.calorieTarget - ctx.caloriesConsumed + ctx.burnedKcal, 0)
        return "kalori hedefine \(remaining) kcal kaldı"
    }

    private func remainingCaloriesSentence(_ ctx: AICoachContext) -> String {
        let remaining = max(ctx.calorieTarget - ctx.caloriesConsumed + ctx.burnedKcal, 0)
        return "Hedefe \(remaining) kcal kaldı."
    }

    private func waterSentence(_ ctx: AICoachContext) -> String {
        if ctx.waterMl >= ctx.waterTargetMl { return "su hedefin tamamlandı" }
        return "su hedefine \(max(ctx.waterTargetMl - ctx.waterMl, 0)) ml kaldı"
    }

    private func stepsSentence(_ ctx: AICoachContext) -> String {
        if ctx.steps >= ctx.stepGoal { return "adım hedefin tamamlandı" }
        return "adım hedefine \(max(ctx.stepGoal - ctx.steps, 0).formatted()) adım kaldı"
    }

    private func quickWinSentence(_ ctx: AICoachContext) -> String {
        if ctx.waterMl < ctx.waterTargetMl / 2 { return "bir bardak su" }
        if ctx.steps < ctx.stepGoal / 2 { return "10 dakikalık kısa bir yürüyüş" }
        if ctx.proteinTargetGrams > 0 && ctx.proteinGrams < ctx.proteinTargetGrams / 2 { return "protein içeren küçük bir atıştırmalık" }
        return "kısa bir nefes molası"
    }
}
