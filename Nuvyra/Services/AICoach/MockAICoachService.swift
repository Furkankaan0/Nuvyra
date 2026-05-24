import Foundation

/// Deterministic on-device coach. Builds insights and chat replies from the
/// passed-in `AICoachContext` so the UI works without a network call.
/// Designed to be **safe**: no diagnosis, no weight-loss promises, framed as
/// general information.
@MainActor
final class MockAICoachService: AICoachService {
    func generateInsights(context: AICoachContext) async throws -> [AICoachInsight] {
        try? await Task.sleep(nanoseconds: 250_000_000)
        return [
            dailyInsight(context: context),
            weeklyInsight(context: context),
            caloriesInsight(context: context),
            waterInsight(context: context),
            stepsInsight(context: context)
        ]
    }

    func reply(to message: String, context: AICoachContext, history: [AICoachMessage]) async throws -> AICoachMessage {
        try? await Task.sleep(nanoseconds: 700_000_000)
        let text = generateReply(for: message, context: context)
        return AICoachMessage(role: .coach, text: text)
    }

    // MARK: - Insight builders
    private func dailyInsight(context: AICoachContext) -> AICoachInsight {
        let parts = [
            "\(context.greetingName), bugünkü ritmin",
            context.steps >= context.stepTarget ? "tempo açısından dengeli görünüyor." : "henüz tamamlanmadı.",
            context.waterMl < context.waterTargetMl ? "Bir bardak suyla küçük bir mola güzel gelir." : "Su tüketimin yeterli düzeyde."
        ]
        return AICoachInsight(
            topic: .daily,
            title: "Günün özeti",
            body: parts.joined(separator: " ")
        )
    }

    private func weeklyInsight(context: AICoachContext) -> AICoachInsight {
        let stepStatus: String
        if context.weeklyAverageSteps == 0 {
            stepStatus = "Bu hafta henüz veri yok; birkaç güne yaymak iyi gelir."
        } else if context.weeklyAverageSteps >= context.stepTarget {
            stepStatus = "Haftalık adım ortalaman hedefin üzerinde — tutarlılık güzel."
        } else {
            stepStatus = "Haftalık adım ortalaman \(context.weeklyAverageSteps.formatted()); küçük artışlar fark yaratır."
        }
        return AICoachInsight(
            topic: .weekly,
            title: "Haftalık gelişim",
            body: stepStatus
        )
    }

    private func caloriesInsight(context: AICoachContext) -> AICoachInsight {
        let remaining = max(context.caloriesTarget - context.caloriesConsumed, 0)
        let proteinGap = max(context.proteinTargetGrams - context.proteinGrams, 0)
        let calorieLine: String
        if context.caloriesConsumed == 0 {
            calorieLine = "Henüz öğün kaydın yok; ilk öğün dengeyi başlatır."
        } else if remaining == 0 {
            calorieLine = "Bugünkü kalori hedefini tamamladın; dengeli bir gün geçirdin."
        } else {
            calorieLine = "Kalori hedefine \(remaining) kcal kaldı."
        }
        let proteinLine: String
        if proteinGap < 10 {
            proteinLine = "Protein dengesi iyi görünüyor."
        } else {
            proteinLine = "Protein hedefi için \(Int(proteinGap)) g daha alabilirsin (örn. yoğurt, mercimek)."
        }
        return AICoachInsight(
            topic: .calories,
            title: "Kalori & makro",
            body: "\(calorieLine) \(proteinLine)"
        )
    }

    private func waterInsight(context: AICoachContext) -> AICoachInsight {
        let body: String
        if context.waterMl >= context.waterTargetMl {
            body = "Su hedefini tamamladın — vücut bunu seviyor."
        } else if context.waterMl == 0 {
            body = "Güne bir bardak suyla başlamak nazik bir hatırlatıcıdır."
        } else {
            let remaining = context.waterTargetMl - context.waterMl
            body = "Hedefe \(remaining) ml kaldı; saatte bir küçük yudum dengeli bir yol."
        }
        return AICoachInsight(
            topic: .water,
            title: "Su tüketimi",
            body: body
        )
    }

    private func stepsInsight(context: AICoachContext) -> AICoachInsight {
        let body: String
        if context.steps >= context.stepTarget {
            body = "Adım hedefin tamamlandı; akşam kısa bir esneme ritmi tamamlar."
        } else if context.steps == 0 {
            body = "Henüz adım kaydın yok; 10 dakikalık bir yürüyüş güzel bir başlangıç."
        } else {
            let remaining = context.stepTarget - context.steps
            body = "Hedefe \(remaining.formatted()) adım kaldı; 15-20 dakikalık tempolu yürüyüş bunu tamamlar."
        }
        return AICoachInsight(
            topic: .steps,
            title: "Yürüyüş ritmi",
            body: body
        )
    }

    // MARK: - Chat reply
    private func generateReply(for message: String, context: AICoachContext) -> String {
        let lower = message.lowercased(with: Locale(identifier: "tr_TR"))
        if lower.contains("protein") {
            return "Bilgilendirme amaçlı bir öneri: günlük protein hedefin yaklaşık \(Int(context.proteinTargetGrams)) g. Şu an \(Int(context.proteinGrams)) g alımın var. Yoğurt, mercimek çorbası, ızgara tavuk veya yumurta küçük artışlar için pratik seçenekler. Bu bireysel diyet önerisi değildir."
        }
        if lower.contains("su") {
            let remaining = max(context.waterTargetMl - context.waterMl, 0)
            if remaining == 0 {
                return "Bugün su hedefini zaten karşıladın. Eğer aktif geçen bir gün varsa 200-300 ml ekstra rahatça gidebilir."
            }
            return "Saatte bir bardak (yaklaşık 200 ml) hatırlatıcı kurmak çoğu kişiye yardımcı olur. Şu an hedefe \(remaining) ml kaldı."
        }
        if lower.contains("yürü") || lower.contains("adım") {
            let remaining = max(context.stepTarget - context.steps, 0)
            if remaining == 0 { return "Adım hedefini tamamladın; bu gece dinlenmek vücudun toparlanmasına yardım eder." }
            return "Hedefe \(remaining.formatted()) adım kaldı. Genelde 1.000 adım = 8-10 dk tempolu yürüyüş. Akşam molasında kısa bir tur işe yarayabilir."
        }
        if lower.contains("akşam") || lower.contains("atıştır") {
            return "Akşam atıştırma isteği çoğu zaman gün içi protein/su açığından kaynaklanır. Önce bir bardak su, ardından 10-15 dk kısa bir hareket dilimi denenebilir. Bu tıbbi bir öneri değildir."
        }
        if lower.contains("kalori") {
            let remaining = max(context.caloriesTarget - context.caloriesConsumed, 0)
            return "Kalori hedefin \(context.caloriesTarget), şu ana kadar aldığın \(context.caloriesConsumed). Kalan \(remaining) kcal. Dengeli bir öğün için karbonhidrat + protein + sebze üçlüsü pratiktir."
        }
        return "Bunu net bir cevapla karşılayamadım ama genel bir prensip: küçük ve sürdürülebilir adımlar uzun vadede dengeyi kurar. Daha spesifik bir konu yazarsan birlikte bakabiliriz. (Bu metin genel bilgilendirme amaçlıdır.)"
    }
}
