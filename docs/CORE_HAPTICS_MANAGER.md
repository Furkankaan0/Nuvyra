# Core Haptics Manager

`HapticManager` Nuvyra'nın zengin dokunsal geri bildirimlerini merkezi olarak yönetir.

## Success Pattern

Besin başarıyla eklendiğinde:

- Hafif ilk transient: kullanıcı eyleminin alındığını hissettirir.
- Daha belirgin ikinci transient: başarı hissini verir.
- Kısa continuous tail: premium ve yumuşak kapanış sağlar.

Core Haptics bileşenleri:

- `CHHapticEvent`
- `CHHapticEventParameter(parameterID: .hapticIntensity, value: ...)`
- `CHHapticEventParameter(parameterID: .hapticSharpness, value: ...)`

## Walking 50% Rhythm

Yürüyüş hedefinin yarısına ulaşıldığında:

- 4 kısa transient pulse
- Artan intensity
- Kontrollü sharpness
- Kısa continuous tail

Bu pattern hedefe ilerleme hissi verir ama kullanıcıyı cezalandırıcı veya alarm gibi hissettirmez.

## Fallback

Cihaz Core Haptics desteklemiyorsa veya engine başlatılamazsa `UIImpactFeedbackGenerator` fallback çalışır.
