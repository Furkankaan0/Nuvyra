# Nuvyra Walking Live Activity

Bu ActivityKit hattı `NuvyraWalkingAttributes` üzerine kuruludur ve iOS 16.1+ API yüzeyini hedefler.

## Attributes

```swift
@available(iOS 16.1, *)
struct NuvyraWalkingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var steps: Int
        var caloriesBurned: Double
        var elapsedTime: TimeInterval
    }

    var sessionName: String
    var startedAt: Date
}
```

## Manager

Ana uygulama tarafında:

```swift
let manager = NuvyraWalkingLiveActivityManager()
await manager.startLiveActivity(steps: 0, caloriesBurned: 0, elapsedTime: 0)
await manager.updateLiveActivity(steps: 1_240, caloriesBurned: 87, elapsedTime: 12 * 60)
await manager.endLiveActivity(steps: 2_800, caloriesBurned: 160, elapsedTime: 25 * 60)
```

## Compatibility

- iOS 16.2+ için `ActivityContent(state:staleDate:)` kullanılır.
- iOS 16.1 için deprecated ama uyumlu `contentState` / `update(using:)` / `end(using:)` fallback'i vardır.
- Nuvyra uygulamasının genel minimum hedefi SwiftData nedeniyle iOS 17'dir; ActivityKit sınıfı daha geniş API uyumluluğu için availability-gated yazılmıştır.
