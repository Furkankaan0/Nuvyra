//
//  ChartDownsampler.swift
//  Nuvyra Design System / Charts
//
//  Büyük veri kümelerinde Swift Charts'ın belleği şişmesin diye basit
//  alt-örnekleme (her N'inci nokta) yardımcısı. Aylar/yıllar seviyesinde
//  zorunlu.
//

import Foundation

public enum ChartDownsampler {

    /// Veri sayısı `targetCount`'u aşarsa, her N'inci elemanı alarak
    /// dizinin uzunluğunu hedef seviyeye düşürür.
    /// - Parameters:
    ///   - input: Kaynak dizi.
    ///   - targetCount: Hedef maksimum eleman sayısı (örn. 200).
    /// - Returns: Alt örneklenmiş dizi.
    public static func downsample<T>(
        _ input: [T],
        targetCount: Int
    ) -> [T] {
        guard targetCount > 0, input.count > targetCount else { return input }
        let stride = max(1, Int((Double(input.count) / Double(targetCount)).rounded(.up)))
        var result: [T] = []
        result.reserveCapacity(targetCount + 1)
        var i = 0
        while i < input.count {
            result.append(input[i])
            i += stride
        }
        // Her zaman son elemanı dahil et (grafik kuyruğu eksilmesin).
        if let last = input.last, result.last as AnyObject !== last as AnyObject {
            result.append(last)
        }
        return result
    }
}
