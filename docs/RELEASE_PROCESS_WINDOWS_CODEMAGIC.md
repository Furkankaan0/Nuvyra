# Windows + Codemagic Release Process

Nuvyra yerelde Xcode gerektirmeden GitHub ve Codemagic üzerinden build edilecek şekilde hazırlanmıştır.

## 1. Repo hazırlığı

1. Değişiklikleri küçük parçalara böl.
2. `codemagic.yaml`, `project.yml`, Swift kaynakları ve dokümanları commit et.
3. GitHub remote'a push et.

## 2. Codemagic kurulumu

1. Codemagic'te GitHub reposunu bağla.
2. `codemagic.yaml` workflow kullanımını seç.
3. App Store Connect integration oluştur ve adını `codemagic_app_store_connect` yap veya YAML'daki adı güncelle.
4. `app_store_credentials` variable group değerlerini ekle.
5. Automatic code signing için `com.nuvyra.app` ve widget extension `com.nuvyra.app.widget` profillerinin üretilebildiğini kontrol et.
6. App Groups altında `group.com.nuvyra.app` grubunu app ve widget App ID'lerine bağla.

## 3. Build akışı

- Pull request açıldığında `ios-pr-check` workflow testleri çalıştırır.
- `main` veya `release/*` branch push edildiğinde `ios-testflight` workflow çalışır.
- Workflow önce XcodeGen ile `Nuvyra.xcodeproj` üretir.
- Sonra Swift package resolve, test, signing, IPA build ve TestFlight publish adımlarını çalıştırır.

## 4. İlk TestFlight yüklemesi

İlk App Store Connect app kaydı manuel oluşturulmalıdır.

- App name: Nuvyra
- Bundle ID: `com.nuvyra.app`
- Widget Bundle ID: `com.nuvyra.app.widget`
- App Group: `group.com.nuvyra.app`
- SKU: `nuvyra-ios`
- Primary language: Turkish
- Category: Health & Fitness

İlk build sonrası App Store Connect'te şu alanları kontrol et:

- Privacy Policy URL
- Support URL
- App Privacy answers
- HealthKit açıklamaları
- Subscription products
- Screenshot setleri

## 5. Release öncesi kontrol

- HealthKit izni yalnızca ihtiyaç anında isteniyor mu?
- Paywall fiyat/deneme/iptal dili net mi?
- Uygulama tıbbi iddia taşımıyor mu?
- Privacy manifest target resource olarak bundle'a giriyor mu?
- TestFlight internal testers grubuna build düşüyor mu?

## 6. Rollback yaklaşımı

Release branch'te problem olursa yeni bir düzeltme commit'i ile ilerle. `git reset --hard` veya history rewrite kullanma.

## Official references

- Codemagic App Store Connect publishing: https://docs.codemagic.io/yaml-publishing/app-store-connect/

## Apple Developer signing metadata

- Team ID: `J5CYS3RDGH`
- App Store Apple ID: `6763769241`
- Bundle ID: `com.nuvyra.app`
- Widget Bundle ID: `com.nuvyra.app.widget`
- App Group: `group.com.nuvyra.app`
- Provisioning profile: `Nuvyra App`
- Profile UUID: `ac3fbe15-8d42-4e01-8605-9a32d3d8b239`
- Profile expiry: `2026-12-20T19:08:58Z`

Private key, `.p8`, `.p12` ve `.mobileprovision` dosyaları GitHub'a push edilmemelidir. Codemagic Code signing identities veya encrypted environment variables kullanılmalıdır.
