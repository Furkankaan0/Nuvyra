# Privacy and KVKK Notes

Nuvyra wellness/fitness coach uygulamasıdır. Tıbbi teşhis, tedavi veya profesyonel diyet danışmanlığı sunmaz.

## Uygulama içi uyarılar

- Nuvyra tıbbi tavsiye vermez.
- Sağlık durumun, özel diyetin veya hastalığın varsa profesyonel destek al.
- Kalori ve besin değerleri tahminidir.

## Veri minimizasyonu

MVP'de hedeflenen veri türleri:

- Profil hedefi: hedef tipi, yaş aralığı için yaş, boy, kilo, hedef kilo, aktivite seviyesi.
- Öğün kayıtları: yemek adı, tahmini kalori/makro, tarih, kaynak tipi.
- Aktivite: Apple Health üzerinden adım sayısı.
- Abonelik: StoreKit entitlement durumu ve ürün ID'si.
- Bildirim tercihleri: nazik hatırlatma saatleri ve kategori tercihleri.

## HealthKit / Apple Health ilkeleri

- İlk fazda yalnızca step count okunur.
- Active energy, workouts, walking distance ve route verileri sonraki fazlarda ayrıca gerekçelendirilmelidir.
- Kullanıcı reddederse uygulama kırılmaz; manuel/demo açıklama gösterilir.
- HealthKit verisi reklam veya pazarlama SDK'sına gönderilmez.
- Kullanıcıya Apple Health verisinin nasıl kullanıldığı açıkça anlatılır.

## KVKK yaklaşımı

- Açık rıza ve aydınlatma metni yayına almadan önce hukuk danışmanı ile doğrulanmalıdır.
- Kullanıcı veri silme talebi için destek kanalı oluşturulmalıdır.
- Gereksiz üçüncü taraf SDK eklenmemelidir.
- Eğer ileride backend veya AI provider eklenirse veri işleyen, yurt dışına aktarım ve saklama süreleri ayrıca dokümante edilmelidir.

## Privacy manifest

`Nuvyra/Resources/PrivacyInfo.xcprivacy` app bundle'a eklenmiştir. Şu an üçüncü taraf SDK yoktur ve tracking kapalıdır.

Yeni API veya SDK eklendiğinde kontrol edilecekler:

- Required reason API kullanılıyor mu?
- Veri App Store privacy labels kapsamında toplanıyor mu?
- SDK Apple'ın privacy manifest/signature gerektiren SDK listesinde mi?
- Kullanıcı izni ve açıklama metinleri güncel mi?

## Paywall ve abonelik

- Fiyat App Store ürünü üzerinden net gösterilmelidir.
- Deneme varsa deneme sonrası fiyat açık yazılmalıdır.
- Restore Purchases görünür olmalıdır.
- İptal yolunun Apple ID abonelik ayarlarından yapıldığı açıklanmalıdır.

## Official references

- Apple privacy manifest files: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- Apple required reason API guidance: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple HealthKit privacy guidance: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
