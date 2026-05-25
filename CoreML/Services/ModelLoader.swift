//
//  ModelLoader.swift
//  Nuvyra Core ML
//
//  .mlmodelc dosyasını şu sırayla arar:
//  1. App bundle (Xcode'a eklenmiş, derlenmiş model).
//  2. Application Support/Nuvyra/Models/ (uygulama içi indirme cache).
//  3. (Opsiyonel) Uzaktan URL → indir, cache'le, açıp döndür.
//
//  Tüm IO actor-isolated (tek seferlik kurulumda race olmasın).
//

import Foundation
import CoreML

public actor ModelLoader {

    // MARK: - Properties

    /// Model adı (uzantısız, örn. "FoodClassifier").
    public let modelName: String
    /// Compute units (default .all → Neural Engine + GPU + CPU).
    public let computeUnits: MLComputeUnits
    /// Opsiyonel uzaktan model URL'i (uygulama büyürse asset kataloğu yerine CDN).
    public let remoteURL: URL?

    private var cachedModel: MLModel?

    // MARK: - Init

    /// - Parameters:
    ///   - modelName: Bundle/cache'te aranacak model dosyasının uzantısız adı.
    ///   - remoteURL: Opsiyonel CDN URL (cache miss olunca indirir).
    ///   - computeUnits: Çıkarım birimi.
    public init(
        modelName: String,
        remoteURL: URL? = nil,
        computeUnits: MLComputeUnits = .all
    ) {
        self.modelName = modelName
        self.remoteURL = remoteURL
        self.computeUnits = computeUnits
    }

    // MARK: - Public API

    /// Modeli yükler ve cache'ler. İlk çağrı maliyetli olabilir,
    /// sonrakiler anında döner.
    public func loadModel() async throws -> MLModel {
        if let cachedModel { return cachedModel }

        let config = MLModelConfiguration()
        config.computeUnits = computeUnits

        // 1) Bundle
        if let url = bundleURL() {
            let model = try MLModel(contentsOf: url, configuration: config)
            cachedModel = model
            return model
        }

        // 2) Application Support cache
        if let cached = try cachedURL(), FileManager.default.fileExists(atPath: cached.path) {
            let model = try MLModel(contentsOf: cached, configuration: config)
            cachedModel = model
            return model
        }

        // 3) Remote download (varsa)
        if let remoteURL {
            let downloaded = try await downloadAndCompile(from: remoteURL)
            let model = try MLModel(contentsOf: downloaded, configuration: config)
            cachedModel = model
            return model
        }

        throw FoodClassifierError.modelFileMissing(modelName)
    }

    /// Cache'i temizler (force reload için).
    public func reset() {
        cachedModel = nil
    }

    // MARK: - Bundle / Disk

    /// Uygulama bundle'ında derlenmiş veya kaynak modeli arar.
    private func bundleURL() -> URL? {
        // Xcode model derleme çıktısı → "<name>.mlmodelc"
        if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
            return url
        }
        // Ham .mlmodel da olabilir; runtime compile edilir
        if let url = Bundle.main.url(forResource: modelName, withExtension: "mlmodel") {
            return (try? MLModel.compileModel(at: url)) ?? url
        }
        // Modern .mlpackage formatı
        if let url = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") {
            return (try? MLModel.compileModel(at: url)) ?? url
        }
        return nil
    }

    /// Application Support/Nuvyra/Models/<name>.mlmodelc yolunu döner.
    private func cachedURL() throws -> URL? {
        let fm = FileManager.default
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support.appendingPathComponent("Nuvyra/Models", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(modelName).mlmodelc")
    }

    // MARK: - Remote download

    /// Uzak URL'den .mlmodel indirir, compile eder ve cache'e koyar.
    private func downloadAndCompile(from remote: URL) async throws -> URL {
        let (tmp, response) = try await URLSession.shared.download(from: remote)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FoodClassifierError.modelFileMissing(
                "\(modelName) (HTTP \(http.statusCode))"
            )
        }

        let compiled = try MLModel.compileModel(at: tmp)

        // Cache'e taşı
        if let target = try cachedURL() {
            let fm = FileManager.default
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: compiled, to: target)
            return target
        }
        return compiled
    }
}
