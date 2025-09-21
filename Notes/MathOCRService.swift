import Foundation
import UIKit

struct OCRResponse: Codable {
    let res: OCRResult
}

struct OCRResult: Codable {
    let latex: String
}

class MathOCRService {
    private let apiUrl = URL(string: "https://server.simpletex.net/api/latex_ocr")!

    func recognizeImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let apiKey = Bundle.main.infoDictionary?["SIMPLETEX_API_KEY"] as? String {
            request.setValue(apiKey, forHTTPHeaderField: "token")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            if let ocrResponse = try? JSONDecoder().decode(OCRResponse.self, from: data) {
                completion("\\(" + ocrResponse.res.latex + "\\)")
            } else {
                completion(nil)
            }
        }.resume()
    }
}