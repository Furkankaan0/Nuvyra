//
//  FoodDetector.swift
//  Nuvyra - Portion Estimator
//
//  Vision framework ile ARFrame görüntüsü üzerinde yemek tespiti yapar:
//  Önce Core ML sınıflandırıcı (varsa), yoksa kontur (VNDetectContoursRequest)
//  fallback'i kullanılır.
//

import Foundation
import Vision
import CoreImage
import CoreVideo
import UIKit

/// Yemek tespit sonucu: bounding box (görüntü koordinatlarında, normalize)
/// ve sınıflandırma etiketi.
public struct FoodDetection: Sendable {
    /// Vision koordinatlarında normalize bounding box (0...1, alt-sol orijin).
    public let boundingBox: CGRect
    /// Tespit edilen yemek etiketi (örn. "pilav"). Sınıflandırma yoksa "default".
    public let label: String
    /// Sınıflandırma güveni (0...1). Sadece ML modeli kullanıldığında anlamlı.
    public let classificationScore: Float
}

/// Vision tabanlı yemek tespit servisi.
public actor FoodDetector {

    // MARK: - Properties

    private var classifier: VNCoreMLModel?

    // MARK: - Init

    /// Yeni bir FoodDetector oluşturur. Core ML modeli opsiyoneldir.
    /// - Parameter coreMLModel: Önceden yüklenmiş VNCoreMLModel (opsiyonel).
    public init(coreMLModel: VNCoreMLModel? = nil) {
        self.classifier = coreMLModel
    }

    // MARK: - Public API

    /// Verilen pixel buffer üzerinde yemek bounding box'ı ve etiketi tespit eder.
    /// - Parameter pixelBuffer: ARFrame.capturedImage (CVPixelBuffer).
    /// - Returns: En güçlü tespit ya da nil (hiçbir şey bulunamazsa).
    public func detect(in pixelBuffer: CVPixelBuffer) async throws -> FoodDetection? {
        // 1) ML sınıflandırıcı varsa onu dene
        if let classifier {
            if let mlResult = try await classifyWithML(pixelBuffer: pixelBuffer,
                                                       model: classifier) {
                return mlResult
            }
        }

        // 2) Kontur tabanlı fallback
        return try await detectByContours(pixelBuffer: pixelBuffer)
    }

    // MARK: - ML Path

    /// Core ML modeli ile sınıflandırma yapar ve bounding box'ı saliency
    /// haritasından türetir.
    private func classifyWithML(
        pixelBuffer: CVPixelBuffer,
        model: VNCoreMLModel
    ) async throws -> FoodDetection? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])

        // Sınıflandırma
        let classifyReq = VNCoreMLRequest(model: model)
        classifyReq.imageCropAndScaleOption = .scaleFill

        // Saliency (dikkat haritası) — bbox için
        let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()

        try handler.perform([classifyReq, saliencyReq])

        guard
            let topClass = (classifyReq.results as? [VNClassificationObservation])?.first,
            topClass.confidence > 0.25
        else {
            return nil
        }

        // Saliency observation'dan bbox
        let bbox: CGRect
        if let salient = (saliencyReq.results as? [VNSaliencyImageObservation])?.first,
           let salientObj = salient.salientObjects?.first {
            bbox = salientObj.boundingBox
        } else {
            bbox = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)
        }

        return FoodDetection(
            boundingBox: bbox,
            label: topClass.identifier,
            classificationScore: topClass.confidence
        )
    }

    // MARK: - Contour Fallback

    /// VNDetectContoursRequest ile en büyük kapalı konturu bularak bounding box çıkarır.
    /// Sınıflandırma yoksa label "default" döner.
    private func detectByContours(pixelBuffer: CVPixelBuffer) async throws -> FoodDetection? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = false
        request.maximumImageDimension = 512

        try handler.perform([request])

        guard
            let observation = request.results?.first as? VNContoursObservation
        else { return nil }

        // En büyük dış konturu seç
        var largestRect: CGRect = .null
        var largestArea: CGFloat = 0

        for i in 0..<observation.topLevelContourCount {
            guard let contour = try? observation.topLevelContour(at: i) else { continue }
            let path = contour.normalizedPath
            let bbox = path.boundingBoxOfPath
            let area = bbox.width * bbox.height
            if area > largestArea {
                largestArea = area
                largestRect = bbox
            }
        }

        guard largestRect != .null, largestArea > 0.05 else {
            return nil
        }

        return FoodDetection(
            boundingBox: largestRect,
            label: "default",
            classificationScore: 0.0
        )
    }
}
