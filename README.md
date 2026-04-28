# Nuvyra

Nuvyra, iOS için beslenme, kalori, yürüyüş ve günlük wellness ritmi koçu olarak hazırlanmış SwiftUI-first bir MVP temelidir.

## Stack

- SwiftUI native iOS app
- Feature-based architecture
- Local-first JSON storage
- HealthKit step sync
- StoreKit 2 subscription abstraction
- UserNotifications
- Privacy-first in-memory analytics foundation
- XcodeGen + Codemagic CI/CD

## Windows geliştirme notu

Bu repo Windows laptop üzerinde yönetilebilir. Xcode projesi repoda elle tutulmaz; Codemagic macOS build makinesinde `project.yml` üzerinden `Nuvyra.xcodeproj` üretir.

Yerel Windows tarafında yapılacaklar:

1. Swift dosyalarını ve dokümanları düzenle.
2. Commit/push yap.
3. Codemagic PR veya TestFlight workflow sonucunu kontrol et.

## App Store uyum varsayımı

Nuvyra wellness/fitness uygulamasıdır; tıbbi teşhis veya tedavi iddiası taşımaz. HealthKit verisi reklam veya üçüncü taraf pazarlama amacıyla kullanılmaz.
