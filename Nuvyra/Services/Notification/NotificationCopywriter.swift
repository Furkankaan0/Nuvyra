import Foundation

/// Generates personalized, varied notification copy. Each category exposes 4-6
/// curated variants. The variant index is chosen deterministically from
/// `seedDate` (defaults to today) so users see the same message any time the
/// schedule rebuilds within the same calendar day, but a different one tomorrow.
struct NotificationCopywriter {
    private let calendar: Calendar
    private let seedDate: Date

    init(calendar: Calendar = .nuvyra, seedDate: Date = Date()) {
        self.calendar = calendar
        self.seedDate = seedDate
    }

    func compose(category: NotificationCategory, context: NotificationPersonalContext) -> (title: String, body: String) {
        let variants = variants(for: category, context: context)
        let index = variantIndex(for: category, in: variants.count)
        return variants[index]
    }

    // MARK: - Variant selection

    private func variantIndex(for category: NotificationCategory, in count: Int) -> Int {
        guard count > 0 else { return 0 }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: seedDate) ?? 1
        let categorySalt = abs(category.rawValue.hashValue % 31)
        return (dayOfYear + categorySalt) % count
    }

    // MARK: - Variants

    private func variants(for category: NotificationCategory, context: NotificationPersonalContext) -> [(title: String, body: String)] {
        switch category {
        case .morningKickoff: return morningVariants(context: context)
        case .hydrationMorning: return hydrationMorningVariants(context: context)
        case .hydrationAfternoon: return hydrationAfternoonVariants(context: context)
        case .hydrationEvening: return hydrationEveningVariants(context: context)
        case .breakfastReminder: return breakfastVariants(context: context)
        case .lunchReminder: return lunchVariants(context: context)
        case .dinnerReminder: return dinnerVariants(context: context)
        case .eveningWalk: return eveningWalkVariants(context: context)
        case .eveningReflection: return reflectionVariants(context: context)
        case .weeklySummary: return weeklySummaryVariants(context: context)
        }
    }

    // MARK: - Morning

    private func morningVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let hi = greeting(context: context)
        return [
            ("Günaydın\(hi)", "Bugünkü ritmin için Nuvyra hazır. Bir bardak suyla nazik bir başlangıç olabilir."),
            ("Yeni bir gün\(hi)", "Sabah birkaç dakika için Nuvyra'ya bakmak günü daha okunur kılabilir."),
            ("Sabah ritmi\(hi)", "\(goalAffirmation(context: context)) Küçük bir adım, gün boyu fark yaratır."),
            ("İyi sabahlar\(hi)", "Bugünün ilk hedefi: kendine sakin bir tempo verebilmek."),
            ("Hoş geldin\(hi)", "Suyla, hareketle ya da kısa bir nefesle başlamak — seçim senin.")
        ]
    }

    // MARK: - Hydration variants

    private func hydrationMorningVariants(context: NotificationPersonalContext) -> [(String, String)] {
        [
            ("Sabah suyu", "Güne sakin başlamanın en hafif yolu: bir bardak su."),
            ("Hidrasyon hatırlatıcısı", "Sabah suyun ritmini hafifçe açar — küçük yudumlar yeterli."),
            ("Su molası", "Şimdi kısa bir su molası, öğleye kadar dengeyi korur."),
            ("Bir bardak su", "İlk bardağını işaretle. Gün boyu \(waterTarget(context: context)) hedefi daha kolay yakalanır."),
            ("Nuvyra hatırlatır", "Suyun küçük dozları büyük fark yaratır.")
        ]
    }

    private func hydrationAfternoonVariants(context: NotificationPersonalContext) -> [(String, String)] {
        [
            ("Öğleden sonra suyu", "Günün ortasında küçük bir hidrasyon dengeyi korur."),
            ("Su zamanı", "Şu an bir bardak su, akşamı çok daha rahat geçirmeni sağlar."),
            ("Kısa bir mola", "Ekrandan kalk, suyu al, üç derin nefes — sonra devam."),
            ("Hidrasyon kontrolü", "Öğleden sonra su tüketimin yarıdaysa hâlâ vakit var."),
            ("Bir nefes, bir yudum", "Nuvyra senin için sakin bir hatırlatma bıraktı.")
        ]
    }

    private func hydrationEveningVariants(context: NotificationPersonalContext) -> [(String, String)] {
        [
            ("Akşam suyu", "Hedefe yaklaştın. Akşam birkaç küçük yudum yeter."),
            ("Günü dengele", "Akşamı kapatmadan önce su hedefini kontrol et."),
            ("Son kontrol", "Akşam saatinde küçük bir hidrasyon, gece ritmini destekler."),
            ("Su kapanışı", "Bugünkü tüketimine bakıp gerekirse tamamla."),
            ("Akşam yudumu", "Sıvı dengen tamamsa kendine bir takdir — değilse hâlâ vakit var.")
        ]
    }

    // MARK: - Meal variants

    private func breakfastVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let goalLine = mealGoalSuggestion(context: context, meal: .breakfast)
        return [
            ("Kahvaltı zamanı", "Bugünün ilk öğününü kaydetmek ritmin için iyi bir başlangıç."),
            ("Sabah öğünü", "\(goalLine) Kayıt sadece birkaç saniye."),
            ("İlk öğün", "Yumurta, yoğurt veya hafif bir tabak — ne olursa kaydet."),
            ("Kahvaltını işle", "Bugünkü makro dengen burada kuruluyor."),
            ("Sabah kaydı", "Nuvyra ilk öğünü bekliyor — küçük adım, büyük ritim.")
        ]
    }

    private func lunchVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let goalLine = mealGoalSuggestion(context: context, meal: .lunch)
        return [
            ("Öğle öğünü", "Öğle yemeğini kaydet, günün ortası burada şekilleniyor."),
            ("Öğle kaydı", "\(goalLine) Hızlı favorilerden de seçebilirsin."),
            ("Bugün ne yedin?", "Kısa bir not bile gün ritmini netleştirir."),
            ("Öğle ritmin", "Tabakta protein, tahıl, sebze dengesi varsa harika."),
            ("Nuvyra hatırlatır", "Öğle öğününü ekle — kalori ve makrolar otomatik güncellenir.")
        ]
    }

    private func dinnerVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let goalLine = mealGoalSuggestion(context: context, meal: .dinner)
        return [
            ("Akşam öğünü", "Bugünkü son öğünü kaydederek günü zihnen kapatabilirsin."),
            ("Akşam kaydı", "\(goalLine) Hafif bir tabak da harika bir kapanış."),
            ("Akşam ritmi", "Yemeği işle ve gerisini Nuvyra'ya bırak."),
            ("Sofranı işle", "Akşam yemeğin için kısa bir kayıt — gerisi otomatik."),
            ("Günün son öğünü", "Kayıt yapınca akşam ritmi netleşir.")
        ]
    }

    // MARK: - Movement

    private func eveningWalkVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let activityLine = activityFlavor(context: context)
        return [
            ("Kısa bir yürüyüş", "10 dakikalık nazik bir yürüyüş günü tatlı kapatır."),
            ("Akşam adımı", "\(activityLine) Açık hava ve kısa bir tur — sade bir mola."),
            ("Hareket molası", "Kısa bir yürüyüş hem zihni hem ritmi açar."),
            ("Akşam yürüyüşü", "Adım hedefine küçük bir tur ekle, kalan süreyi rahat geçir."),
            ("Açık hava", "Kısa bir yürüyüş bile uyku kalitesini destekleyebilir.")
        ]
    }

    // MARK: - Reflection

    private func reflectionVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let hi = greeting(context: context)
        return [
            ("Günü kapat\(hi)", "Bugün üç şey iyiydi diye düşün, gerisini bırak."),
            ("Akşam refleksiyonu", "Bugünkü ritmine kısa bir bakış: ne işe yaradı?"),
            ("Sakin bir kapanış", "Bugün küçük bir başarın varsa onu fark et."),
            ("Bugün için bir not\(hi)", "Tek cümle bile yeterli — yarına ipucu olur."),
            ("Yumuşak bir kapanış", "Telefona değil, kendi nefesine bir dakika ayır.")
        ]
    }

    // MARK: - Weekly summary

    private func weeklySummaryVariants(context: NotificationPersonalContext) -> [(String, String)] {
        let hi = greeting(context: context)
        return [
            ("Haftalık özet hazır\(hi)", "Geçen haftanın ritmine sakin bir bakış için Nuvyra'yı aç."),
            ("Hafta nasıl geçti?", "İçgörüler bekliyor — bir kahve eşliğinde bakabilirsin."),
            ("Pazar özeti\(hi)", "Geçen haftanın küçük başarıları seni bekliyor."),
            ("Haftanın bir bakışı", "Trendlerin Nuvyra'da; abartı yok, sadece görünür ritim."),
            ("Hafta kapanışı\(hi)", "Yeni haftaya başlamadan önce kısa bir özet okumaya değer.")
        ]
    }

    // MARK: - Helpers

    private func greeting(context: NotificationPersonalContext) -> String {
        guard let name = context.resolvedFirstName else { return "" }
        return ", \(name)"
    }

    private func goalAffirmation(context: NotificationPersonalContext) -> String {
        switch context.goalType {
        case .loseWeight:
            return "Sürdürülebilir ilerleme, küçük tutarlı kararlarla kurulur."
        case .gainMuscle:
            return "Protein hedefine kademeli ulaşmak, ani değişikliklerden daha kalıcı."
        case .gainHealthy:
            return "Sakin bir kalori fazlası, sürdürülebilir kazanım yaratır."
        case .maintain, .stayFit:
            return "Bugünkü ritmin geçen haftaki ritminle dengelenebilir."
        case .walkMore:
            return "Bugün birkaç adım daha eklemek, haftalık ritmini güçlendirir."
        case .eatHealthier, .healthyLiving:
            return "Bugünkü küçük seçimler, haftalık dengeni inşa eder."
        case nil:
            return "Bugünkü hedeflerin için sakin bir başlangıç."
        }
    }

    private func mealGoalSuggestion(context: NotificationPersonalContext, meal: MealType) -> String {
        switch context.goalType {
        case .loseWeight:
            return "Hafif protein ve lif odaklı bir tabak günü dengeleyebilir."
        case .gainMuscle:
            return "Bu öğüne biraz daha protein eklemek hedefini destekler."
        case .gainHealthy:
            return "Doyurucu, sakin bir kalori girdisi sağlıklı kazanım için iyi."
        case .eatHealthier, .healthyLiving:
            return "Sebze, protein ve tam tahıl dengesi günü tutarlı tutar."
        case .maintain, .stayFit:
            return "Bugünkü dengen için bilinçli bir tabak yeter."
        case .walkMore, nil:
            return "Sade bir tabak günün ritmine yardım eder."
        }
    }

    private func activityFlavor(context: NotificationPersonalContext) -> String {
        switch context.activityLevel {
        case .sedentary: return "Bugün hareket molasıyla başlangıç yapabilirsin."
        case .lightlyActive: return "Kısa bir tur, ritmine yumuşak bir dokunuş olur."
        case .moderatelyActive: return "Bugünkü temponu sakin bir yürüyüşle kapat."
        case .veryActive: return "Yoğun bir günde toparlayıcı kısa bir yürüyüş iyi gelir."
        case .athlete: return "Aktif tempo sonrası nazik bir kapanış yürüyüşü."
        case nil: return "Sakin, kısa bir yürüyüş yeterli."
        }
    }

    private func waterTarget(context: NotificationPersonalContext) -> String {
        // Generic — actual target from profile may not be available at scheduling time.
        "günlük su hedefini"
    }
}
