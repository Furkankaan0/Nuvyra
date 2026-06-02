# Nuvyra Environment Variables

Bu proje Windows makineden GitHub + Codemagic üzerinden iOS build/TestFlight akışı için hazırlanmıştır.

## xcconfig pipeline (yeni — runtime API keys)

Runtime API keys (`CLAUDE_API_KEY`, `FATSECRET_*`, `USDA_API_KEY`) iki katmanlı bir xcconfig sistemi üzerinden uygulamaya ulaşır:

- **`Nuvyra/Resources/Defaults.xcconfig`** (commit edili) — her key'in iskeletini taşır, değerler boş. `project.yml`'nin `configFiles` entry'sinden Debug/Release config'lerine bağlanır. Son satırı `#include? "Secrets.xcconfig"` — eksik dosyayı sessizce kabul eder.
- **`Nuvyra/Resources/Secrets.xcconfig`** (`.gitignored`) — gerçek anahtarları taşır. `Secrets.sample.xcconfig` template olarak commit edilmiştir; yerel dev için `cp Secrets.sample.xcconfig Secrets.xcconfig` ve değerleri doldur.
- **Codemagic CI** — pipeline'da `Inject runtime secrets into Secrets.xcconfig` adımı, encrypted env vars'tan dosyayı build sırasında üretir. Bu adım xcodegen'den ÖNCE çalışır.
- **Info.plist** — her key için `<key>NAME</key><string>$(NAME)</string>` entry'si var; xcodebuild build-time substitution yapar.
- **Runtime resolve** — `FoodDataRuntimeConfig` ve `AICoachRuntimeConfig` önce `ProcessInfo.processInfo.environment`'a, sonra `Bundle.main.object(forInfoDictionaryKey:)`'e bakar. Boş/`$(...)`-prefixli değerler "absent" sayılır.

### Yerel geliştirme

```sh
cd Nuvyra/Resources
cp Secrets.sample.xcconfig Secrets.xcconfig
# Secrets.xcconfig içindeki CLAUDE_API_KEY satırını doldur
```

`Secrets.xcconfig` `.gitignore`'da; asla commit edilmemeli.

### Simulator launch (env-only path)

xcconfig'i değiştirmeden tek seferlik test için:

```sh
xcrun simctl launch booted com.nuvyra.app --env CLAUDE_API_KEY=sk-ant-...
```

## Codemagic variable group

Codemagic içinde `app_store_credentials` adında bir environment variable group oluştur.

Gerekli değişkenler:

- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect API Issuer ID.
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect API Key ID.
- `APP_STORE_CONNECT_PRIVATE_KEY`: `.p8` private key içeriği. Secret olarak saklanmalı.
- `APP_STORE_APPLE_ID`: App Store Connect app Apple ID.
- `CERTIFICATE_PRIVATE_KEY`: Manuel signing kullanılırsa certificate private key. Automatic signing/integration kullanılırsa gerekmeyebilir.

### Runtime API key değişkenleri (aynı group'a eklenebilir)

Aşağıdaki değişkenler `app_store_credentials` (veya ayrı bir `runtime_api_keys`) group'a eklenebilir. Hepsi opsiyonel — eksik olanlar uygulamanın ilgili özelliğini mock'a düşürür:

- `CLAUDE_API_KEY`: Anthropic Claude Messages API anahtarı. Yoksa `AICoachServiceFactory.live()` → `MockAICoachService` döner.
- `CLAUDE_MODEL` (ops): default `claude-sonnet-4-6`.
- `CLAUDE_ENDPOINT` (ops): proxy/staging host için override.
- `FATSECRET_CLIENT_ID`, `FATSECRET_CLIENT_SECRET`: FatSecret premier barkod kapsamı.
- `FATSECRET_SCOPE`, `FATSECRET_REGION`, `FATSECRET_LANGUAGE`: opsiyonel overrides.
- `USDA_API_KEY`: USDA FoodData Central anahtarı (ABD market kapsamı).

Projede kullanılan sabitler:

- `BUNDLE_ID=com.nuvyra.app`
- `WIDGET_BUNDLE_ID=com.nuvyra.app.widget`
- `APP_STORE_APPLE_ID=6763769241`
- `XCODE_PROJECT=Nuvyra.xcodeproj`
- `XCODE_SCHEME=Nuvyra`

## Codemagic integrations

`codemagic.yaml`, `app_store_connect: codemagic_app_store_connect` entegrasyon adını bekler. Codemagic UI tarafında App Store Connect integration adını aynı ver veya YAML içinde adı güncelle.

## StoreKit product IDs

App Store Connect içinde şu ürün ID'leri oluşturulmalı:

- `com.nuvyra.premium.monthly`
- `com.nuvyra.premium.yearly`

Premium Plus ürünleri MVP kapsamı dışında bırakıldı; App Store Connect'te ilk fazda yalnızca Premium aylık/yıllık ürünleri oluştur.

## Widget/App Group

Apple Developer > Identifiers altında hem app hem widget App ID için App Groups capability açık olmalı. İlk TestFlight signing öncesi şu grup tanımlanmalıdır:

- `group.com.nuvyra.app`

## Güvenlik notu

HealthKit, kilo, öğün, adım ve abonelik verileri hassas kabul edilir. API key, private key, signing certificate veya kullanıcı verisi repoya commit edilmemelidir.

## Local StoreKit configuration

`Nuvyra/Resources/Nuvyra.storekit` yerel StoreKit testleri için başlangıç ürünlerini içerir. Codemagic build bu dosyayı app bundle'a kopyalamaz; Xcode şemasında manuel StoreKit test koşusu için dosya grubu olarak görünür.

## Apple Developer account metadata

Güvenli şekilde repoda tutulabilecek değerler:

- Team ID: `J5CYS3RDGH`
- Developer ID: `579d53d0-534c-40bd-80e7-b964c69447e5`
- Bundle ID: `com.nuvyra.app`
- Widget Bundle ID: `com.nuvyra.app.widget`

Bu değerler `project.yml`, `codemagic.yaml` ve `ci/codemagic.yaml` içine eklendi.

## Provisioning profile metadata

Yerelde bulunan dosya:

- `C:\Users\furka\Downloads\Nuvyra_App.mobileprovision`

Okunan metadata:

- Profile name: `Nuvyra App`
- Profile UUID: `ac3fbe15-8d42-4e01-8605-9a32d3d8b239`
- Team ID: `J5CYS3RDGH`
- Application identifier: `J5CYS3RDGH.com.nuvyra.app`
- Expires: `2026-12-20T19:08:58Z`
- `get-task-allow`: `false`, App Store/TestFlight dağıtımı için uygun sinyal.

Bu `.mobileprovision` dosyası repoya commit edilmemelidir. Codemagic'te şu güvenli yollardan biri kullanılmalı:

1. Önerilen: Codemagic App Store Connect integration + automatic signing ile profil/certificate fetch.
2. Alternatif: Codemagic Team settings > codemagic.yaml settings > Code signing identities > iOS provisioning profiles bölümünden `Nuvyra_App.mobileprovision` dosyasını upload et.

## Secrets policy

Aşağıdaki değerler koda veya GitHub'a eklenmemeli; sadece Codemagic encrypted environment variables / integrations içinde saklanmalı:

- `APP_STORE_CONNECT_PRIVATE_KEY`
- `.p8` API key dosyası içeriği
- `CERTIFICATE_PRIVATE_KEY`
- `.p12` certificate
- `.mobileprovision` dosyası
