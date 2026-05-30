//
//  BarcodeNormalizer.swift
//  Nuvyra - Barcode Scanner
//
//  Birçok ürün veritabanı aynı ürünü farklı barkod formatlarında saklar:
//  UPC-A (12 hane) ↔ EAN-13 (13 hane, leading 0 ile), EAN-8 (8 hane), ITF-14
//  (14 hane, dış paketleme). Kamera bir format okur ama hedef DB başka
//  formatta tutuyor olabilir. Bu utility tek bir scan'den ÖNCELİKLİ olarak
//  denenmesi gereken tüm valid varyantları döner.
//

import Foundation

public enum BarcodeNormalizer {

    /// Verilen barkoddan provider'ların sırayla deneyeceği varyantları
    /// üretir. Sıralama önemli: orijinal varyant her zaman ilk, sonra
    /// muhtemel format dönüşümleri.
    ///
    /// Örnek:
    /// - "036000291452" (UPC-A) → ["036000291452", "0036000291452" (EAN-13)]
    /// - "0036000291452" (EAN-13 leading-zero) → ["0036000291452", "036000291452" (UPC-A)]
    /// - "8690000000000" (EAN-13 TR) → ["8690000000000"] (UPC-A'ya çevrilemez)
    /// - "12345678" (EAN-8) → ["12345678"] (gerçek EAN-8, dönüşüm yok)
    /// - "00012345678905" (ITF-14) → ["00012345678905", "12345678905" (EAN-13)]
    public static func variants(of raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber }) else {
            return [trimmed]
        }

        var seen = Set<String>()
        var result: [String] = []

        func add(_ s: String) {
            guard !s.isEmpty, seen.insert(s).inserted else { return }
            result.append(s)
        }

        add(trimmed)

        switch trimmed.count {
        case 12:
            // UPC-A → EAN-13 (leading zero)
            add("0" + trimmed)
        case 13 where trimmed.hasPrefix("0"):
            // EAN-13 with leading 0 → UPC-A
            add(String(trimmed.dropFirst()))
        case 14:
            // ITF-14 → EAN-13 (drop leading packaging digit)
            add(String(trimmed.dropFirst()))
            // ITF-14 → UPC-A bazen mümkün (ilk 2 hane atılarak)
            if trimmed.hasPrefix("00") {
                add(String(trimmed.dropFirst(2)))
            }
        case 8:
            // EAN-8 dönüştürülemez; tek başına kalır.
            break
        default:
            break
        }

        return result
    }

    /// ISO 15420 / GS1 prefix tablosu — barkodun ilk 3 hanesinden ülke
    /// tahmini. AI enrichment'a "Türk markası" ipucu vermek için. Boş
    /// string döner: bilinmeyen / dönüştürülemez prefix.
    public static func countryHint(for barcode: String) -> String {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.allSatisfy({ $0.isNumber }) else { return "" }

        // EAN-13 ise ilk 3, UPC-A ise leading 0 ekleyip ilk 3'ü oku.
        let prefixSource = trimmed.count == 12 ? "0" + trimmed : trimmed
        let prefix = String(prefixSource.prefix(3))
        guard let prefixInt = Int(prefix) else { return "" }

        switch prefixInt {
        case 0...19: return "Amerika Birleşik Devletleri / Kanada"
        case 30...39: return "Fransa / Monako"
        case 40...44: return "Almanya"
        case 45, 49: return "Japonya"
        case 46: return "Rusya"
        case 50: return "Birleşik Krallık"
        case 54: return "Belçika / Lüksemburg"
        case 57: return "Danimarka"
        case 64: return "Finlandiya"
        case 70...79: return "Norveç / İsveç / İsviçre"
        case 80...83: return "İtalya"
        case 84: return "İspanya"
        case 86: return "Türkiye"
        case 87: return "Hollanda"
        case 90, 91: return "Avusturya"
        case 93: return "Avustralya"
        case 94: return "Yeni Zelanda"
        case 869: return "Türkiye"
        case 600...601: return "Güney Afrika"
        case 690...699: return "Çin"
        case 729: return "İsrail"
        case 750: return "Meksika"
        case 754, 755: return "Kanada"
        case 770, 771: return "Kolombiya"
        case 789, 790: return "Brezilya"
        case 850: return "Küba"
        case 858: return "Slovakya"
        case 859: return "Çek Cumhuriyeti"
        case 860: return "Sırbistan"
        case 865: return "Moğolistan"
        case 867: return "Kuzey Kore"
        case 880: return "Güney Kore"
        case 884: return "Kamboçya"
        case 885: return "Tayland"
        case 888: return "Singapur"
        case 890: return "Hindistan"
        case 893: return "Vietnam"
        case 896: return "Pakistan"
        case 899: return "Endonezya"
        case 977: return "ISSN (dergi)"
        case 978, 979: return "ISBN (kitap)"
        default: return ""
        }
    }
}
