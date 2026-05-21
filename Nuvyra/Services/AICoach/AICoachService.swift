import Foundation

protocol AICoachService {
    func dailyInsights(context: AICoachContext) async -> [AICoachInsight]
    func reply(to question: String, history: [AICoachMessage], context: AICoachContext) async throws -> AICoachMessage
}

enum AICoachError: Error, LocalizedError {
    case rateLimited
    case unavailable
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .rateLimited: return "Şu an çok hızlı yazıyorsun. Bir an sonra tekrar dene."
        case .unavailable: return "AI Coach şu an yanıt veremiyor. Birazdan tekrar dene."
        case .invalidInput: return "Bu sorudan anlam çıkaramadım. Biraz daha açıklayıcı yazabilir misin?"
        }
    }
}

enum AICoachSafetyDisclaimer {
    static let short = "Bilgilendirme amaçlıdır. Tıbbi tavsiye değildir."
    static let long = "Nuvyra AI Coach motivasyon ve farkındalık için kişisel veriler üzerinden öneriler sunar. Tıbbi teşhis koymaz, kesin sonuç vaat etmez ve doktor ya da diyetisyen yerine geçmez. Sağlığınla ilgili kararlar için bir uzmana danışman önerilir."
}
