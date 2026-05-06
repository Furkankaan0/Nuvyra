# Core Motion Walking Tracker

`CoreMotionWalkingTrackerService`, kullanıcının anlık hareket durumunu düşük güç tüketimli Core Motion sınıflandırmasıyla dinler.

## Kullanılan Apple API'leri

- `CMMotionActivityManager.startActivityUpdates(to:withHandler:)`
- `CMMotionActivity.stationary`
- `CMMotionActivity.walking`
- `CMMotionActivity.running`
- `CMPedometer.startUpdates(from:)`
- `CMPedometer.stopUpdates()`

## Batarya Stratejisi

Servis ham accelerometer stream'i okumaz. Önce M-serisi motion coprocessor tarafından sınıflandırılmış aktivite state'i dinlenir.

- `walking == true` veya `running == true`: pedometer açılır.
- `stationary == true`: pedometer beklemeye alınır.
- `unknown`, `automotive` veya adım saymaya değmeyen diğer durumlar: pedometer kapatılır.
- Activity update queue `utility` QoS ve tek operasyonlu background `OperationQueue` üzerinde çalışır.
- Snapshot stream `bufferingNewest(1)` kullanır; SwiftUI tarafı eski event kuyruğuyla şişmez.

## Kullanım

```swift
let tracker = CoreMotionWalkingTrackerService()
tracker.start()

Task {
    for await snapshot in tracker.snapshots {
        print(snapshot.isWalking, snapshot.trackedSteps)
    }
}
```

Uygulama kapanırken veya ekran artık takip etmiyorsa:

```swift
tracker.stop()
```

## Not

Bu servis GPS kullanmaz ve sürekli background location istemez. Amacı yürüyüş odağı açıkken adım sayımı için pedometer'ı yalnızca gerekli hareket durumlarında aktif tutmaktır.
