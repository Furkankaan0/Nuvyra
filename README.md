# Nuvyra

Nuvyra, Türkiye pazarı için tasarlanan premium iOS beslenme, kalori, su ve yürüyüş ritmi koçudur. Uygulama sert diyet dili kullanmaz; günlük alışkanlıkları sakin, Apple-native ve gizlilik öncelikli bir deneyimle takip eder.

## Stack

- Native iOS, SwiftUI, iOS 17+
- SwiftData local-first persistence
- MVVM + Services + Repository
- HealthKit: step count, active energy, walking/running distance
- CoreMotion fallback
- StoreKit 2 subscriptions
- WidgetKit small/medium widget extension
- UserNotifications placeholder flow
- XcodeGen + Codemagic CI/CD

## Requirements

- Xcode 15+ veya Codemagic macOS builder
- iOS 17 minimum deployment target
- Bundle ID: `com.nuvyra.app`
- Widget Bundle ID: `com.nuvyra.app.widget`
- Team ID: `J5CYS3RDGH`

Windows geliştirme için Xcode projesi repoda tutulmaz. Codemagic `project.yml` üzerinden `Nuvyra.xcodeproj` üretir.

## Codemagic Setup

Codemagic'te `app_store_credentials` variable group oluştur:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_APPLE_ID`
- `CERTIFICATE_PRIVATE_KEY` veya Codemagic automatic signing identity

Private key, `.p8`, `.p12`, `.mobileprovision` ve certificate dosyaları GitHub'a commit edilmez.

Workflow:

- PR: project generate, package resolve, unit/UI tests
- `main` / `release/*`: tests, signing, IPA build, TestFlight placeholder publish

Codemagic code signing tarafında hem `com.nuvyra.app` hem `com.nuvyra.app.widget` için App Store provisioning profile üretilebildiğinden emin olun.

## StoreKit Product IDs

- `com.nuvyra.premium.monthly`
- `com.nuvyra.premium.yearly`

StoreKit ürünleri App Store Connect'te yoksa paywall fallback ürünlerle kırılmadan açılır.

## HealthKit Capability

App target için HealthKit capability açık olmalıdır. Okunan veri tipleri:

- `stepCount`
- `activeEnergyBurned`
- `distanceWalkingRunning`

İzin verilmezse uygulama CoreMotion/manual fallback moduna düşer ve crash olmaz.

## Widget Capability

Widget extension target: `NuvyraWidgetExtension`.

- Small widget: Nuvyra ring, adım, kalori dengesi
- Medium widget: kalori, adım, su, mini içgörü
- Live Activity: yürüyüş odağı için Kilit Ekranı ve Dynamic Island görünümü
- App group placeholder: `group.com.nuvyra.app`

`project.yml` içinde widget extension ana app archive'ına `embed: true` olarak eklenir. Bu karar Live Activity desteği için bilinçlidir.

TestFlight archive öncesi Apple Developer > Identifiers altında hem `com.nuvyra.app` hem `com.nuvyra.app.widget` için App Groups capability açılmalı ve `group.com.nuvyra.app` grubu tanımlanmalıdır. Codemagic automatic signing bu iki bundle ID için App Store provisioning profile üretebilmelidir. Widget'ı geçici olarak devre dışı bırakmak istenirse `project.yml` app target dependencies içindeki `NuvyraWidgetExtension` satırı kaldırılmalı ve Codemagic IPA metadata validasyonundaki widget kontrolleri de aynı committe kapatılmalıdır.

## App Store Copy

App adı: Nuvyra: Kalori & Yürüyüş

Subtitle: Beslen, yürü, ritmini koru

Promotional text: Türkçe beslenme takibi, yürüyüş hedefleri ve sakin premium koçluk tek yerde.

Keywords: kalori,adım sayar,yürüyüş,beslenme,diyet,su takibi,kilo verme,sağlık,öğün,makro

İlk açıklama: Nuvyra, günlük beslenme ve yürüyüş ritmini tek bir sakin ekranda toplayan premium yaşam koçudur.

## Privacy Notes

Nuvyra wellness/fitness uygulamasıdır; tıbbi teşhis veya tedavi sunmaz. Sağlık verileri yalnızca uygulama içindeki hedef ve içgörüleri oluşturmak için kullanılır. Sağlık verileri reklam hedefleme için kullanılmaz.

## Production Service Defaults

- Akıllı öğün kaydı bu fazda `LocalFoodIntelligenceService` ile cihaz içi, deterministik Türkçe örnek gıda eşleştirmesi yapar. Cloud LLM, Passio, FatSecret veya Open Food Facts adapter'ları için protokol hazırdır; API key veya ücretli SDK Git'e eklenmez.
- Analytics bu fazda `PrivacyPreservingAnalyticsService` ile no-op çalışır. Sağlık verisi veya kişisel beslenme detayı üçüncü taraf reklam/marketing SDK'sına gönderilmez. Gerçek analytics sağlayıcısı eklenecekse event payload'ları anonim ve aggregate kalmalıdır.
- StoreKit restore/sync kullanıcı aksiyonuna bağlıdır. App foreground olduğunda entitlement refresh yapılır; `AppStore.sync()` otomatik çağrılmaz.

Launch öncesi tamamlanacak alanlar:

- Gerçek Privacy Policy URL
- Support URL
- KVKK/GDPR veri silme ve export akışı
- App Store privacy labels
