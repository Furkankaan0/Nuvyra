# BarcodeScanner Modülü

Production-ready barkod tarama + üç-katmanlı besin verisi entegrasyonu
(Open Food Facts → FatSecret → USDA), 24 saatlik bellek + SQLite kalıcı
cache, exponential backoff retry, shimmer + bottom-sheet UI.

## Klasör Yapısı

```
BarcodeScanner/
├── Models/
│   ├── ProductSource.swift
│   └── ScannedProduct.swift
├── Networking/
│   ├── HTTPClient.swift           // URLSession + retry + 24h URLCache
│   ├── RetryPolicy.swift          // Exponential backoff: 1s → 2s → 4s
│   └── MemoryProductCache.swift   // NSCache, 24h TTL
├── Services/
│   ├── BarcodeScannerService.swift   // AVFoundation tarayıcı
│   ├── NutritionAPIService.swift     // Sıralı fallback orchestrator (actor)
│   ├── ProductCacheService.swift     // SQLite kalıcı cache (actor)
│   └── Providers/
│       ├── NutritionProvider.swift
│       ├── OpenFoodFactsProvider.swift
│       ├── FatSecretProvider.swift
│       └── USDAProvider.swift
├── ViewModels/
│   └── BarcodeScannerViewModel.swift
└── Views/
    ├── BarcodeScannerView.swift
    ├── ScannerCameraView.swift
    ├── ProductCardSheet.swift
    ├── ShimmerView.swift
    └── ManualProductEntryView.swift
```

## Kurulum

### Info.plist

`NSCameraUsageDescription` zorunlu:

```xml
<key>NSCameraUsageDescription</key>
<string>Barkod taraması için kamera erişimi gereklidir.</string>
```

### App Transport Security

OFF + USDA + FatSecret hepsi HTTPS olduğu için ek ATS exception gerekmez.

## Kullanım

```swift
import SwiftUI

@MainActor
struct ScannerScreen: View {
    @StateObject private var vm: BarcodeScannerViewModel = {
        let client = HTTPClient()
        let off = OpenFoodFactsProvider(client: client)

        let fatSecret = FatSecretProvider(
            client: client,
            credentials: .init(
                clientID: ProcessInfo.processInfo.environment["FS_CLIENT_ID"] ?? "",
                clientSecret: ProcessInfo.processInfo.environment["FS_CLIENT_SECRET"] ?? ""
            )
        )

        let usda = USDAProvider(
            client: client,
            apiKey: ProcessInfo.processInfo.environment["USDA_API_KEY"] ?? ""
        )

        let disk = try? ProductCacheService()
        let api = NutritionAPIService(
            providers: [off, fatSecret, usda],
            diskCache: disk
        )

        return BarcodeScannerViewModel(
            scanner: BarcodeScannerService(),
            api: api
        )
    }()

    var body: some View {
        BarcodeScannerView(viewModel: vm)
    }
}
```

## Pipeline

1. **Tarama**: `BarcodeScannerService` (AVCaptureSession + MetadataOutput)
   EAN-13/EAN-8/UPC-E/QR yakalar. Aynı barkod 2 sn içinde tekrarlanırsa
   yok sayılır. Başarılı yakalamada `UIImpactFeedbackGenerator(.medium)`
   tetiklenir ve oturum 1.5 sn donar.
2. **API**: `NutritionAPIService` (actor) sırasıyla
   `OpenFoodFacts → FatSecret → USDA` dener.
   - Bellek cache (NSCache, 24h TTL) varsa anında döner.
   - Tüm provider'lar başarısız + offline ise SQLite cache'e düşer.
3. **UI**: bottom sheet `ProductSkeletonCard` (shimmer) → `ProductCardSheet`
   slide-up animasyonla açılır. Bulunamazsa `ManualProductEntryView`.

## Eşzamanlılık & Thread Safety

- `NutritionAPIService` ve `FatSecretProvider` ve `ProductCacheService`
  birer **`actor`**'dür — token erişimi, SQLite handle, attempt log
  hep serialize edilir.
- `BarcodeScannerService` ve `BarcodeScannerViewModel` `@MainActor`'dır.
- AVCaptureSession start/stop özel `sessionQueue` üzerinde çalışır.
- API çağrıları `async throws`, retry policy 3 deneme + exponential
  backoff (1s, 2s, 4s).

## Güvenlik

- FatSecret credential ve USDA API key'i Keychain'de tutulmalıdır
  (ProcessInfo örneği sadece dev içindir).
- Hiçbir kullanıcı verisi ya da barkod 3. parti'ye fazladan paylaşılmaz;
  sadece sorgulanan barkod ilgili public API'ye gönderilir.

## Performans Notları

- URLCache: 32 MB memory + 128 MB disk, `Cache-Control: max-age=86400`.
- NSCache: 512 entry, 24 saat TTL.
- SQLite: barcode primary key + updated_at index, ON CONFLICT upsert.
- Shimmer < 100 ms içinde tetiklenir (sheet açıldığı anda).
