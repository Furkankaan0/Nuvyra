//
//  ARContainerView.swift
//  Nuvyra - Portion Estimator
//
//  ARView'i SwiftUI'ya bağlayan UIViewRepresentable + scene reconstruction
//  mesh'ini yarı saydam yeşil olarak boyayan koordinatör. ARSession'un tek
//  delegate'i Coordinator'dur; olaylar ARSessionManager'a forward edilir.
//

import SwiftUI
import ARKit
import RealityKit
import Metal

/// ARView'i SwiftUI ağacında kullanılabilir hale getiren wrapper.
public struct ARContainerView: UIViewRepresentable {

    // MARK: - Inputs

    /// AR oturumunu sahiplenen manager.
    public let sessionManager: ARSessionManager

    // MARK: - Init

    /// SwiftUI tarafında doğrudan kurulur.
    public init(sessionManager: ARSessionManager) {
        self.sessionManager = sessionManager
    }

    // MARK: - UIViewRepresentable

    public func makeCoordinator() -> Coordinator {
        Coordinator(sessionManager: sessionManager)
    }

    public func makeUIView(context: Context) -> ARView {
        let arView = sessionManager.arView
        arView.debugOptions = []
        arView.environment.sceneUnderstanding.options = [.occlusion]

        arView.session.delegate = context.coordinator
        context.coordinator.attach(to: arView)
        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        // Mesh güncellemesi Coordinator delegate akışı ile otomatik gerçekleşir.
    }

    // MARK: - Coordinator

    /// ARSession delegate olaylarını dinleyip mesh anchor'larına yarı saydam
    /// yeşil materyal atayan koordinatör.
    public final class Coordinator: NSObject, ARSessionDelegate {

        // MARK: Refs

        private weak var arView: ARView?
        private let sessionManager: ARSessionManager
        private var meshAnchorEntities: [UUID: AnchorEntity] = [:]

        // MARK: Init

        public init(sessionManager: ARSessionManager) {
            self.sessionManager = sessionManager
        }

        /// View hazırlandığında bağlanır.
        public func attach(to arView: ARView) {
            self.arView = arView
        }

        // MARK: ARSessionDelegate (frame)

        public nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // ARSessionManager'a yeni frame'i forward et.
            Task { @MainActor in
                self.sessionManager.forwardFrameUpdate(frame)
            }
        }

        public nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in
                self.sessionManager.forwardError(error)
            }
        }

        public nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor in
                self.sessionManager.forwardInterrupted()
            }
        }

        public nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor in
                self.sessionManager.forwardInterruptionEnded()
            }
        }

        // MARK: ARSessionDelegate (anchors)

        public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView else { return }
            for anchor in anchors {
                if let mesh = anchor as? ARMeshAnchor {
                    addMesh(mesh, in: arView)
                }
            }
        }

        public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            // Mesh güncellemelerini agresif yeniden çizmiyoruz (ısı/CPU).
            // İsteğe bağlı: belirli bir aralıkla refresh'i burada yapabilirsiniz.
        }

        public func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                if let entity = meshAnchorEntities.removeValue(forKey: anchor.identifier) {
                    entity.removeFromParent()
                }
            }
        }

        // MARK: Mesh rendering

        /// Yeni bir ARMeshAnchor için yarı saydam yeşil materyalle entity ekler.
        private func addMesh(_ anchor: ARMeshAnchor, in arView: ARView) {
            guard meshAnchorEntities[anchor.identifier] == nil else { return }

            guard let mesh = try? makeMeshResource(from: anchor.geometry) else { return }

            var material = SimpleMaterial()
            material.color = .init(
                tint: UIColor.green.withAlphaComponent(0.35),
                texture: nil
            )
            material.metallic = .float(0.0)
            material.roughness = .float(0.9)

            let modelEntity = ModelEntity(mesh: mesh, materials: [material])
            let anchorEntity = AnchorEntity(world: anchor.transform)
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)

            meshAnchorEntities[anchor.identifier] = anchorEntity
        }

        /// ARMeshGeometry → MeshResource dönüşümü. Pozisyon ve indeks
        /// buffer'larını okuyarak triangle list üretir.
        private func makeMeshResource(from geometry: ARMeshGeometry) throws -> MeshResource {
            let vertexBuffer = geometry.vertices.buffer
            let vertexCount = geometry.vertices.count
            let stride = geometry.vertices.stride
            let offset = geometry.vertices.offset

            var positions: [SIMD3<Float>] = []
            positions.reserveCapacity(vertexCount)
            for i in 0..<vertexCount {
                let ptr = vertexBuffer.contents()
                    .advanced(by: offset + i * stride)
                    .assumingMemoryBound(to: SIMD3<Float>.self)
                positions.append(ptr.pointee)
            }

            let faces = geometry.faces
            let indexCount = faces.count * faces.indexCountPerPrimitive
            var indices: [UInt32] = []
            indices.reserveCapacity(indexCount)
            let indexPtr = faces.buffer.contents().assumingMemoryBound(to: UInt32.self)
            for i in 0..<indexCount {
                indices.append(indexPtr[i])
            }

            var descriptor = MeshDescriptor(name: "foodMesh")
            descriptor.positions = MeshBuffer(positions)
            descriptor.primitives = .triangles(indices)
            return try MeshResource.generate(from: [descriptor])
        }
    }
}
