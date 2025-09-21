import Foundation
import MLKit
import PencilKit

class OCRService {
    private var ink: Ink?
    private var strokes: [Stroke] = []

    func recognizeStrokes(_ pkStrokes: [PKStroke], completion: @escaping (String?) -> Void) {
        strokes = pkStrokes.map { pkStroke in
            let points = pkStroke.path.map { point in
                StrokePoint(
                    x: Float(point.location.x),
                    y: Float(point.location.y),
                    t: Int(point.timeOffset * 1000)
                )
            }
            return Stroke(points: points)
        }

        ink = Ink(strokes: strokes)

        guard let ink = ink else {
            completion(nil)
            return
        }

        let languageIdentifier = "en-US"
        var modelManager = ModelManager.modelManager()
        let languageTag = DigitalInkRecognitionModelIdentifier(forLanguageTag: languageIdentifier)
        let model = DigitalInkRecognitionModel(modelIdentifier: languageTag!)

        modelManager.download(
            model,
            conditions: ModelDownloadConditions(
                allowsCellularAccess: true,
                allowsBackgroundDownloading: true
            )
        )

        let recognizer = DigitalInkRecognizer.digitalInkRecognizer(options: DigitalInkRecognizerOptions(model: model))

        recognizer.recognize(ink: ink) { (result, error) in
            if let result = result, let candidate = result.candidates.first {
                completion(candidate.text)
            } else {
                completion(nil)
            }
        }
    }
}