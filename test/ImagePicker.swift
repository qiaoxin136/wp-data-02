//
//  ImagePicker.swift
//  test
//
//  Wraps UIImagePickerController for camera capture (and optionally photo library).
//

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    var onPick: (UIImage) -> Void
    var onCancel: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: Context) {}

    final class Coordinator: NSObject,
                             UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            } else {
                parent.onCancel()
            }
            // Do NOT call picker.dismiss here — the fullScreenCover binding
            // (showCamera = false inside onPick/onCancel) dismisses it via SwiftUI.
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
            // Same — let SwiftUI dismiss via the binding.
        }
    }
}
