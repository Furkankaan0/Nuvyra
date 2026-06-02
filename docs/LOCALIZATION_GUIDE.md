# Localization Guide — Nuvyra

Nuvyra TR + EN destekler. Bu doküman, **yeni bir TR-only ekranı EN'e geçirmek isteyen birinin** sıfırdan adım adım takip edebileceği rehberdir. Mevcut pattern'in arka planı:

- **Source language: `tr`** — `Localizable.xcstrings`'in `"sourceLanguage": "tr"` ayarı korunuyor (uygulama TR-first başladı, fazladan key rewrite'tan kaçınmak için).
- **Catalog: `Nuvyra/Resources/Localizable.xcstrings`** (Apple String Catalog).
- **Engine storyline'ları:** runtime'da `Locale`-aware copy bank ile resolve edilir (bkz. `WeeklyInsightEngine.swift`, `MealTimingEngine.swift`). Bunlar xcstrings'te değil.

---

## 1. Üç patern, üç farklı kullanım

### A) Statik UI string — `Text("key")` literal

SwiftUI'nin `Text` init'i `LocalizedStringKey` alır; literal string'ler otomatik olarak xcstrings'ten çevrilir.

```swift
Text("nutrition.daily.title")        // xcstrings key
Text("Günlük toplam")                // literal TR — key olarak da kullanılabilir
```

**Ne zaman:** view içinde compile-time'da bilinen tüm sabit copy'ler.

### B) String'e dönüştürülmesi gereken — `String(localized: "key")`

`Text`'in kabul etmediği API'lar (`navigationTitle(String)`, custom struct'larda `var title: String`, vs.).

```swift
.navigationTitle(String(localized: "nutrition.title"))
NuvyraPrimaryButton(title: String(localized: "nutrition.action.addMeal"), ...)
```

**Ne zaman:** parametre olarak `String` bekleyen yerler.

### C) Dynamik / runtime-derived string — engine copy bank

ViewModel'in ürettiği veya runtime'da hesaplanan dinamik metinler. xcstrings'te değil, engine'in kendisinde `Locale`-aware tutulur.

```swift
struct WeeklyStorylineCopy: Sendable {
    static let turkish: WeeklyStorylineCopy = ...
    static let english: WeeklyStorylineCopy = ...

    static func resolved(for locale: Locale) -> WeeklyStorylineCopy {
        let code = locale.language.languageCode?.identifier ?? "tr"
        return code == "en" ? .english : .turkish
    }
}
```

**Ne zaman:** parametrik (`"Bu hafta %d adım daha yüksek"`) ya da kural-bazlı (`Rule 1 → "kahvaltı atlandı"`) metinler.

---

## 2. Yeni bir ekran/component migrate ederken

### Adım 1: Hard-coded TR string'leri tara

```bash
# Bir ekranın `.swift` dosyasında hard-coded Türkçe string'leri bul:
rg '"[A-ZÇĞİÖŞÜ][^"]*"' Nuvyra/Features/Nutrition/NutritionView.swift
```

Component'in her görünür string'ini listele.

### Adım 2: xcstrings'e key'leri ekle

`Nuvyra/Resources/Localizable.xcstrings`'i aç ve her string için bir entry yarat. Naming convention: `screen.section.element` (örn. `nutrition.action.addMeal`).

**Şablon (statik string):**

```json
"nutrition.action.addMeal" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Add meal" } },
    "tr" : { "stringUnit" : { "state" : "translated", "value" : "Yemek ekle" } }
  }
}
```

**Şablon (CLDR plural):**

```json
"%lld kayıt" : {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "variations" : {
        "plural" : {
          "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld entry" } },
          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld entries" } }
        }
      }
    }
  }
}
```

(Source language `tr` için variations gerekmez; `tr` çoğulda "kayıt" tek formu kullanır.)

### Adım 3: View'i güncelle

**`Text(...)` çağrıları:**

```diff
- Text("Yemek ekle")
+ Text("nutrition.action.addMeal")
```

**`String` parametresi alan API'lar:**

```diff
- .navigationTitle("Beslenme")
+ .navigationTitle(String(localized: "nutrition.title"))
```

**Sayı + label kombinasyonları (plural):**

```swift
// Source language TR; xcstrings key = "%lld kayıt"
Text("\(viewModel.summary.mealCount) kayıt")
// EN'de otomatik "1 entry" / "5 entries" olarak resolve edilir.
```

### Adım 4: Test et

```bash
# Xcode'da simulator'un dilini değiştir:
# - Settings > General > Language & Region > iPhone Language → English
# - veya Scheme > Edit Scheme > Run > Options > App Language → English
```

Tüm görünür metinlerin EN'e döndüğünü doğrula. Hâlâ TR kalan string'ler varsa: ya literal kalmıştır (xcstrings'e key eklenmedi) ya da `.navigationTitle` gibi bir yerde `String(localized:)` kullanılmadı.

---

## 3. Component types — best practice

### `Text` view

```swift
Text("nutrition.daily.title")                                  // GOOD: localized
Text(verbatim: "1.240 kcal")                                   // GOOD: explicitly not localized
Text("\(viewModel.summary.mealCount) kayıt")                   // GOOD: TR source key with EN plural variation
```

### Custom component title parameter (`String`)

```swift
struct NuvyraPrimaryButton: View {
    var title: String           // <- String stays as-is for ViewModel-driven labels
    // ...
    Text(verbatim: title)       // <- verbatim: callers must pre-localize
}
```

Callers:

```swift
NuvyraPrimaryButton(
    title: String(localized: "nutrition.action.addMeal"),
    systemImage: "plus"
) { /* … */ }
```

### Modifiers expecting `String`

- `.navigationTitle(String(localized: "..."))`
- `.accessibilityLabel(String(localized: "..."))`
- `.alert("Başlık", ...)` ← `Text` overload mevcut, literal kullan: `.alert("alert.key", ...)`

### Runtime-derived strings (engine output)

```swift
struct MealTimingCopy: Sendable {
    let emptyHeadline: String
    // ...
    static let turkish: MealTimingCopy = ...
    static let english: MealTimingCopy = ...
}

DefaultMealTimingEngine(locale: .current).evaluate(meals: [...], at: Date())
```

ViewModel'lerden gelen metinler için **engine'lar locale'i constructor'da alır**, default `.current`. Test'ler `Locale(identifier: "tr_TR")` ile pinle.

---

## 4. Mevcut migration durumu

| Ekran | Migrate edildi? | Not |
| --- | --- | --- |
| `WeeklyComparisonCard` | ✅ Tam | Locale-aware engine storyline'ları dahil |
| `MealTimingCard` | ✅ Tam | Aynı |
| `WeightTrendCard` | ✅ Tam | Static label'lar |
| `NutritionView` | 🟡 Kısmi | Header, dateSelector, dailyTotalsCard, quickActions migrate edildi. `SmartMealEntryCard`, `EstimatedMealResultRow`, `QuickFoodPicker`, `MealSectionView`, `FavoriteMealsView` HENÜZ migrate edilmedi. |
| `DashboardView` | ❌ | TR-only literals — Hoş geldin başlığı, "Bugünkü ritim" vb. |
| `AddFoodView` | ❌ | TR-only |
| `OnboardingView` | ❌ | TR-only — `OnboardingViewModel.primaryButtonTitle` ve adımların hepsi hard-coded |
| `AICoachView` | ❌ | TR-only |
| Onboarding chrome | 🟡 | Skip CTA TR-only, "Şimdi değil" / "Premium'u sonra incelerim" hard-coded |

### Sıradaki migration için öneri sıralaması

1. **`AICoachView`** — küçük, izole; tüm chat copy'leri kaplı.
2. **`DashboardView` header + greeting** — kullanıcı ilk burayı görür.
3. **`AddFoodView`** — kompleks; alt component'lere bölünebilir (`AutoNutritionResultRow`, `ManualEntrySection`).
4. **`OnboardingView`** — viewModel-driven label'lar nedeniyle en uzun iş.
5. **`NutritionView` kalanı** — `SmartMealEntryCard` vb. private struct'lar.

Her ekran için pull-request başlığı: `i18n: migrate <view> to xcstrings (TR + EN)`.

---

## 5. Yasak (sık yapılan hata) pattern'ler

- ❌ `Text(LocalizedStringKey(stringLiteral: dynamicString))` — `LocalizedStringKey` sadece compile-time literal alır, runtime variable'a uygulanmaz.
- ❌ String concatenation: `"Hedefe " + String(remaining) + " kaldı"` — CLDR plural ve dil gramerini kırar. Tek bir formatlanmış key kullan: `"Hedefe %lld kaldı"` xcstrings'te.
- ❌ Kalıcı user veri (DB / Apple Health save) için localized string yazma — DB'de TR kayıt, EN locale'de okunduğunda yine TR görünür. **Sadece UI catı için** localize et; ham veri yapısı dil-agnostik kalmalı.
- ❌ Engine storyline'ını xcstrings'e koymak — runtime parametre içerirler (`"Bu hafta %d adım..."`), xcstrings'te tek tek tutulması zor. Bunlar `*Copy.swift` struct'larında kalır.

---

## 6. Pratik referanslar

- Apple String Catalog rehberi: https://developer.apple.com/documentation/xcode/localization
- CLDR plural rules: https://cldr.unicode.org/index/cldr-spec/plural-rules
- `String(localized:)` API: iOS 15+, mevcut deployment target 17+ ile uyumlu.
- SwiftUI `LocalizedStringKey`: https://developer.apple.com/documentation/swiftui/localizedstringkey
