# PortionEstimator

LiDAR + ARKit + SwiftUI ile yemek porsiyonu hacim & gramaj tahmin modülü.
Tüm görüntü/derinlik işleme cihaz üzerinde gerçekleşir.

## Gereksinimler

- iOS **16.0+**
- LiDAR'lı cihaz (iPhone 12 Pro veya üzeri / iPad Pro 2020+).
- Swift 5.9+ / Xcode 15+.

LiDAR yoksa modül otomatik olarak **manuel gram girişi** ekranına düşer.

## Klasör Yapısı

```
PortionEstimator/
├── Models/
│   ├── ConfidenceLevel.swift
│   ├── FoodDensityDatabase.swift
│   └── PortionEstimate.swift
├── Services/
│   ├── ARSessionManager.swift
│   ├── DepthProcessor.swift
│   ├── FoodDetector.swift
│   ├── GramEstimationService.swift
│   ├── RANSACPlaneDetector.swift
│   └── VolumeCalculator.swift
├── ViewModels/
│   └── PortionEstimatorViewModel.swift
├── Views/
│   ├── ARContainerView.swift
│   ├── BoundingBoxOverlay.swift
│   ├── ConfidenceIndicatorView.swift
│   ├── InfoCardView.swift
│   ├── ManualEntryView.swift
│   └── PortionEstimatorView.swift
└── Resources/
    ├── Info.plist.fragment.xml      // Info.plist'e merge edilmesi gereken anahtarlar
    └── PrivacyInfo.xcprivacy        // Apple privacy manifest
```

## Kullanım

```swift
import SwiftUI

@main
struct NuvyraApp: App {
    var body: some Scene {
        WindowGroup {
            PortionEstimatorView()
        }
    }
}
```

İsteğe bağlı: kendi Core ML sınıflandırıcınızı entegre etmek için:

```swift
let model = try VNCoreMLModel(for: MyFoodClassifier(configuration: .init()).model)
let detector = FoodDetector(coreMLModel: model)
let vm = PortionEstimatorViewModel(detector: detector)
PortionEstimatorView(viewModel: vm)
```

## Pipeline Özeti

1. `ARSessionManager` → `ARWorldTrackingConfiguration`
   - `sceneReconstruction = .meshWithClassification`
   - `frameSemantics = [.sceneDepth, .smoothedSceneDepth]`
2. `FoodDetector` (Vision) → bbox + label
   - Core ML modeli + saliency, yoksa `VNDetectContoursRequest` fallback.
3. `DepthProcessor` → bbox içi 3B nokta bulutu (kamera uzayı, metre)
   - Confidence < `.medium` veya 0/NaN/uç değer pikseller eler.
   - Z-score > 2 olan outlier'ları çıkarır.
4. `RANSACPlaneDetector` → tabak düzlemi
   - 200 iterasyon, 5 mm inlier eşiği, inlier'lar üzerinde rafinasyon.
5. `VolumeCalculator` → pinhole modelle bbox metrik alanı + ortalama yükseklik
   üzerinden hacim integrali (cm³).
6. `GramEstimationService` → hacim × yoğunluk = gram (±%15) + kcal.

Her tahmine `ConfidenceLevel.derive(...)` ile düşük/orta/yüksek seviye atanır.

## Privacy

`Resources/Info.plist.fragment.xml` dosyasındaki anahtarlar uygulamanın
`Info.plist` dosyasına merge edilmelidir:

- `NSCameraUsageDescription`
- `NSMotionUsageDescription`
- `NSWorldSensingUsageDescription`
- `UIRequiredDeviceCapabilities` → `arkit`

`Resources/PrivacyInfo.xcprivacy` Apple Privacy Manifest gereksinimlerini karşılar:
kamera + Core Motion + filesystem access + system boot time.

Hiçbir kamera, derinlik veya konum verisi sunucuya gönderilmez.

## Eşzamanlılık Notu

- UI/state: `@MainActor`.
- Heavy CPU (DepthProcessor, RANSAC, VolumeCalculator) `Task.detached`
  ile background priority'de koşar.
- Pipeline ~2 Hz throttle edilmiştir (CPU/ısı). `processingInterval` ile
  ayarlanabilir.

Swift 6 strict concurrency ile derlerken, `ARFrame`'in non-Sendable olması
nedeniyle uyarı görürseniz; kullanıcı kodunuzda işlenecek alanları
(intrinsics, capturedImage, depthMap) önce kopyalayıp detached task'a
o şekilde geçirebilirsiniz.
