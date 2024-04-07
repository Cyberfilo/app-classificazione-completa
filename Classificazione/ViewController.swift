//
//  ViewController.swift
//  Classificazione
//
//  Created by Filippo Mattia Menghi on 07/04/24.
//

import UIKit
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var resultLabel: UILabel!

    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.delegate = self
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        resultLabel.text = "Choose an image to start"
    }

    @IBAction func pickImage(_ sender: UIButton) {
        let alert = UIAlertController(title: "Choose Image", message: nil, preferredStyle: .actionSheet)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
                self.imagePicker.sourceType = .camera
                self.present(self.imagePicker, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.imagePicker.sourceType = .photoLibrary
            self.present(self.imagePicker, animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // If you're using an iPad, actionsheets must be presented from a popover.
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            resultLabel.text = "Could not get the image."
            return
        }
        imageView.image = image
        classifyImage(image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    private func classifyImage(_ image: UIImage) {
        guard let model = try? VNCoreMLModel(for: MyImageClassifier(configuration: MLModelConfiguration()).model) else {
            resultLabel.text = "Loading the model failed."
            return
        }
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                DispatchQueue.main.async {
                    self?.resultLabel.text = "Unable to classify image. \(error?.localizedDescription ?? "Error")"
                }
                return
            }
            DispatchQueue.main.async {
                self?.resultLabel.text = "Class: \(topResult.identifier)\nConfidence: \(topResult.confidence)"
            }
        }
        request.imageCropAndScaleOption = .centerCrop
        guard let ciImage = CIImage(image: image) else {
            resultLabel.text = "Could not convert UIImage to CIImage."
            return
        }
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: image.cgImageOrientation())
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.resultLabel.text = "Failed to perform classification. \(error.localizedDescription)"
                }
            }
        }
    }
}

// Extension to handle CGImagePropertyOrientation for UIImage
extension UIImage {
    func cgImageOrientation() -> CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
