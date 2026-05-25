import SwiftUI
import UIKit

struct MealCameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var photoData: Data?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(photoData: $photoData, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var photoData: Data?
        private let dismiss: DismissAction

        init(photoData: Binding<Data?>, dismiss: DismissAction) {
            self._photoData = photoData
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                photoData = Self.normalizedJPEG(from: image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        private static func normalizedJPEG(from image: UIImage) -> Data? {
            let maxSide: CGFloat = 1_400
            let longestSide = max(image.size.width, image.size.height)
            let scale = min(1, maxSide / max(longestSide, 1))
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let rendered = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return rendered.jpegData(compressionQuality: 0.72)
        }
    }
}

