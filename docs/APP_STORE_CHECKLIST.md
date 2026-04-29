# App Store Checklist

## App bilgileri

- App name: Nuvyra
- App Store name: Nuvyra: Kalori ve Yürüyüş Koçu
- Subtitle: Kalori ve Yürüyüş Koçu
- Category: Health & Fitness
- Bundle ID: `com.nuvyra.app`
- Content rights: Uygulamadaki içerik Nuvyra'ya ait veya lisanslı olmalı.
- Age rating: Medikal iddia yok; Health & Fitness / Wellness olarak işaretlenmeli.
- Privacy Policy URL: Yayına almadan önce gerçek URL girilmeli.
- Support URL: Yayına almadan önce gerçek URL girilmeli.
- Marketing URL: Opsiyonel.

## App Store metin önerisi

App adı:

Nuvyra: Kalori ve Yürüyüş Koçu

Alt başlık:

Fotoğrafla öğün kaydet, adımlarını senkronize et

Promosyon metni:

Türkçe beslenme takibi, akıllı yürüyüş hedefleri ve haftalık koç özetleriyle sürdürülebilir sağlık ritmi kur.

Açıklama başlangıcı:

Nuvyra, katı diyet listeleri yerine günlük ritim kurmana yardımcı olur. Öğününü fotoğrafla kaydet, adımlarını Apple Sağlık'tan otomatik al, sana özel kalori ve yürüyüş önerilerini tek ekranda gör.

Anahtar kelime kümeleri:

kalori sayacı, kalori takip, beslenme takibi, diyet, kilo verme, adım sayar, yürüyüş takibi, makro hesaplama, yemek fotoğrafı, su takibi, Apple Watch, HealthKit

## Ekran görüntüsü planı

1. Öğününü saniyeler içinde kaydet
2. Adımların Apple Sağlık'tan otomatik gelsin
3. Bugün için gerçekçi kalori ve adım hedefi
4. Düşük enerji günlerinde bile uygulanabilir mini yürüyüş planları
5. Haftalık koç özetin hazır
6. Apple Watch ile ritmini kaybetme

## App Review risk kontrolü

- Nuvyra tıbbi teşhis veya tedavi iddiası taşımaz.
- Kalori ve makro değerleri tahmini olarak etiketlenir.
- HealthKit verisi reklam, data broker veya pazarlama SDK'sı için kullanılmaz.
- Apple Health ifadesi kullanıcıya dönük metinde tercih edilir; HealthKit geliştirici dokümantasyon terimi olarak kalır.
- Paywall içinde fiyat, dönem, deneme sonrası fiyat, iptal yolu, Terms/Privacy ve Restore Purchases görünür olmalı.
- App Store Connect'te gerçek Privacy Policy ve Support URL olmadan review'a gönderme.

## Subscription ürünleri

- `com.nuvyra.premium.monthly`
- `com.nuvyra.premium.yearly`

## Demo verisi

Review ekibinin boş state ve demo akışı görebilmesi için onboarding sonrası dashboard, meal logging, walking ve paywall ekranları kırılmadan açılmalıdır.

## Official references

- Apple HealthKit HIG: https://developer.apple.com/design/human-interface-guidelines/healthkit
- Apple HealthKit privacy: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Apple privacy manifest: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Codemagic App Store Connect publishing: https://docs.codemagic.io/yaml-publishing/app-store-connect/
