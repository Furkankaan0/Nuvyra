# App Store Privacy Label — Nuvyra

App Store Connect → **App Privacy** → **Get Started**'da girilecek "Data Collected" matrisi. Bu doküman:

- Hangi data type'ların hangi ekrandan/akıştan toplandığını,
- Her birinin amacını (Apple'ın `App Functionality` / `Analytics` / `Product Personalization` taksonomisinde),
- Üçüncü taraf SDK'lara/proxy'lere giden veriyi,
- "Data Used to Track You" durumunu

kayıt altına alır. Apple submission'ı bu cevaplara dayanır; **her release'te bu dosyayı güncel tut**.

> Son güncelleme: bu commit (Anthropic Claude API entegrasyonu sonrası).

---

## 1. Üst düzey cevaplar

| Soru | Cevap |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **Yes** |
| Is the data linked to the user's identity? | **No** (her şey on-device veya anonim) |
| Is the data used for tracking? | **No** |
| Do you use Privacy Manifest? | **Yes** — `Nuvyra/Resources/PrivacyInfo.xcprivacy` |

Detaylı kategoriler aşağıda.

---

## 2. Data type matrisi

| Apple kategori | Alt veri tipi | Toplanıyor? | Linked to user? | Tracking? | Purpose | Kaynak / detay |
| --- | --- | --- | --- | --- | --- | --- |
| **Health & Fitness** | Health and fitness data | **Yes** | No | No | App Functionality | HealthKit step / active energy / distance, kullanıcı izin verirse. Yalnızca cihazda işlenir; Anthropic'e gönderilmez. |
| **Health & Fitness** | Other (food logs, water intake, weight, mood) | **Yes** | No | No | App Functionality | SwiftData lokal store. Apple Health'e opsiyonel yazma. |
| **Contact Info** | Name | **Yes** | No | No | App Functionality | Onboarding'de istenir; sadece UI'da kullanılır, dışa yollanmaz. |
| **User Content** | Photos or videos | **Yes** | No | No | App Functionality | Öğün fotoğrafı (opsiyonel, MealEntry.photoData). Yalnızca lokal. |
| **User Content** | Other user content | **Yes** | No | No | App Functionality | AI coach chat mesajları ve `Bu metin general bilgilendirme amaçlıdır.` outro'lu yanıtlar. Mesajlar Anthropic API'sine gönderilir; cevaplar kaydedilmez (yalnızca runtime memory). |
| **Identifiers** | Device ID | **No** | — | — | — | IDFA/IDFV toplamıyoruz. |
| **Identifiers** | User ID | **No** | — | — | — | Hesap sistemi yok. |
| **Usage Data** | Product interaction | **Yes (limited)** | No | No | Analytics | `PrivacyPreservingAnalyticsService` — aggregate event sayaçları, kullanıcı detayı yok. Şu an no-op fallback, sadece local debug. |
| **Diagnostics** | Crash data | **Yes** | No | No | App Functionality | Sadece Xcode Organizer/TestFlight aracılığıyla Apple'a. Üçüncü taraf crash SDK yok. |
| **Diagnostics** | Performance data | **Yes** | No | No | App Functionality | Aynı — Apple aracılığıyla, third-party yok. |
| **Purchases** | Purchase history | **No** | — | — | — | StoreKit 2 entitlement; satın alma geçmişi bizim sunucumuza yazılmaz. |
| **Search History** | Search history | **Yes (local)** | No | No | App Functionality | Yiyecek aramaları yerel SQLite FTS5 cache'inde; cihaz dışına çıkmaz. |
| **Sensitive Info** | — | **No** | — | — | — | — |
| **Financial Info** | — | **No** | — | — | — | — |
| **Location** | — | **No** | — | — | — | İlerideki yürüyüş rotası özelliği eklendiğinde bu satır revize edilmeli. |
| **Contacts** | — | **No** | — | — | — | — |
| **Browsing History** | — | **No** | — | — | — | — |
| **Other Data** | Other data types | **Yes** | No | No | App Functionality | Anthropic API'ye gönderilen günlük metric snapshot (kalori/protein/su/adım sayıları + haftalık karşılaştırma rakamları). İsim/identifier içermez. |

---

## 3. Üçüncü taraf veri akışı

Apple'ın "third-party SDKs and partners" sorularına cevap için:

| Servis | Ne gönderiyoruz | Ne almıyoruz | Kontrol |
| --- | --- | --- | --- |
| **Anthropic Claude API** (Claude Messages v1, `claude-sonnet-4-6`) | Sistem prompt + kullanıcı sorusu + günlük/haftalık metric snapshot (kullanıcı adı = onboarding'deki ad, identifier yok) | Tool use, vector store, fine-tuning data — hiçbiri kullanılmıyor. Anthropic 30 günden uzun raw input saklamaz (mevcut policy, 2026). | `CLAUDE_API_KEY` yoksa servis tamamen devre dışı, mock'a düşer. |
| **Open Food Facts** | Barkod / arama sorgusu | Kullanıcı verisi yollanmaz | Anonim API; sorgular IP üzerinden cache-key olabilir. |
| **FatSecret** (opsiyonel) | OAuth token request + arama sorgusu | Kullanıcı verisi yollanmaz | `FATSECRET_*` env'leri yoksa devre dışı. |
| **USDA FoodData Central** (opsiyonel) | Arama sorgusu | — | API key yoksa devre dışı. |
| **Apple HealthKit** | Yerel — Apple'a hiçbir şey gitmez | Apple ekosistem | Kullanıcı izniyle. |
| **Apple StoreKit 2** | Apple'a satın alma akışı | — | Yerleşik. |
| **Apple WidgetKit / WidgetCenter** | Cihaz içi snapshot | — | Yerleşik. |
| **Google Gemini** (food intelligence — opsiyonel) | Türkçe öğün adı + tahmin sorgusu | Kullanıcı kimliği yok | `GeminiFoodLogService.apiKey` boşsa devre dışı, lokal Turkish heuristic'e düşer. |

---

## 4. "Data Used to Track You"

**Hiçbiri.** Apple'ın "tracking" tanımı: bir başka şirketin uygulamasında/web sitesinde aynı kullanıcıyı tanımak için veri paylaşmak (cross-app tracking) ya da data broker'a satmak. Nuvyra bunların hiçbirini yapmıyor.

ATT (App Tracking Transparency) prompt'u gerekmez.

---

## 5. Privacy Manifest (`PrivacyInfo.xcprivacy`)

Şu an deklare edilen Required Reason API'lar (manifest dosyasına bakın):

- `NSPrivacyAccessedAPICategoryFileTimestamp` — yedek/import için.
- `NSPrivacyAccessedAPICategoryUserDefaults` — `NuvyraWidgetSnapshotStore` App Group UserDefaults paylaşımı.

Eklendikçe güncellenecek:

- Anthropic API entegrasyonu Required Reason gerektirmez (network sadece).
- Apple'ın "SDKs requiring privacy manifests" listesindeki SDK yok — third-party SDK eklenirse manifest hash'i de eklenmeli.

---

## 6. Privacy Policy + Support URL

App Store Connect form'unda zorunlu alanlar:

- Privacy Policy URL — şu an placeholder. Launch öncesi yayınlanması gereken sayfa: nuvyra.app/privacy (sahiplenildi mi doğrula).
- Support URL — şu an placeholder. nuvyra.app/support önerilir.

İçerik için: `docs/PRIVACY_AND_KVKK_NOTES.md`'deki KVKK bölümünü genişlet, App Store'un "you must clearly describe..." kriterlerini karşılamak için EN + TR versiyonu gerekli.

---

## 7. Revision log

| Tarih | Değişiklik |
| --- | --- |
| 2026-05-28 | İlk versiyon — Anthropic Claude API entegrasyonu sonrası "User Content" + "Other Data" satırları eklendi. |

Yeni satır eklenmesi gereken durumlar:

- Backend / authentication eklenirse → `Contact Info: Email`, `User ID` etc.
- Crashlytics / Sentry / Mixpanel benzeri SDK eklenirse → `Diagnostics`, `Usage Data` linked'e dönüşebilir.
- Cihazda location capture / route recording eklenirse → `Location: Precise Location`.
- Sosyal paylaşım veya foto export eklenirse → akış yeniden değerlendirilmeli.
