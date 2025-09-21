import SwiftUI
import PDFKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
        // we will leave this empty and this is totally fine
    }
}