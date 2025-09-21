import SwiftUI
import PencilKit

let maxAllowedScale = 4.0

struct Page: Identifiable, Equatable {
    let id = UUID()
    var canvasView = PKCanvasView()

    static func == (lhs: Page, rhs: Page) -> Bool {
        lhs.id == rhs.id
    }
}

struct ContentView: View {
    @State private var pages = [Page()]
    @State private var scale: CGFloat = 1.0
    @State private var showingPDFPreview = false
    @State private var pdfData: Data?
    private let ocrService = OCRService()
    private let mathOcrService = MathOCRService()

    var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            if scale < maxAllowedScale / 2 {
                scale = maxAllowedScale
            } else {
                scale = 1.0
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center) {
                ZoomableScrollView(scale: $scale) {
                    VStack {
                        ForEach(pages) { page in
                            DrawingCanvasView(
                                canvasView: page.canvasView,
                                onDrawingChanged: {
                                    if page == pages.last {
                                        pages.append(Page())
                                    }
                                }
                            )
                            .border(Color.gray)
                            .frame(width: 8.5 * 96, height: 11 * 96) // US Letter size at 96 DPI
                        }
                    }
                }
                .gesture(doubleTapGesture)
                
                Button("Export to PDF") {
                    generatePDF()
                    showingPDFPreview = true
                }
                .padding()

            }
        }
        .sheet(isPresented: $showingPDFPreview) {
            if let pdfData = pdfData {
                PDFKitRepresentedView(data: pdfData)
            }
        }
    }


    func generatePDF() {
        let pdfMetaData = [
            kCGPDFContextCreator: "Notes App",
            kCGPDFContextAuthor: "Alex Yang"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 8.5 * 72, height: 11 * 72) // US Letter size at 72 DPI for PDF
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            let dispatchGroup = DispatchGroup()
            
            for page in pages {
                dispatchGroup.enter()
                context.beginPage()
                let image = page.canvasView.drawing.image(from: page.canvasView.bounds, scale: 1.0)
                image.draw(in: pageRect)
                
                let textStrokes = page.canvasView.drawing.strokes.filter { stroke in
                    if let inkTool = stroke.tool as? PKInkingTool {
                        return inkTool.color != .green
                    }
                    return true
                }
                
                ocrService.recognizeStrokes(textStrokes) { text in
                    if let text = text {
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = .natural
                        let attributes = [
                            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                            NSAttributedString.Key.paragraphStyle: paragraphStyle
                        ]
                        let attributedText = NSAttributedString(string: text, attributes: attributes)
                        attributedText.draw(in: pageRect)
                    }
                    
                    let mathStrokes = page.canvasView.drawing.strokes.filter { stroke in
                        if let inkTool = stroke.tool as? PKInkingTool {
                            return inkTool.color == .green
                        }
                        return false
                    }
                    let mathDrawing = PKDrawing(strokes: mathStrokes)
                    let mathImage = mathDrawing.image(from: page.canvasView.bounds, scale: 1.0)
                    
                    self.mathOcrService.recognizeImage(mathImage) { latex in
                        if let latex = latex {
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.alignment = .natural
                            let attributes = [
                                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                                NSAttributedString.Key.paragraphStyle: paragraphStyle
                            ]
                            let attributedText = NSAttributedString(string: latex, attributes: attributes)
                            attributedText.draw(in: pageRect)
                        }
                        dispatchGroup.leave()
                    }
                }
            }
            dispatchGroup.wait()
        }
        self.pdfData = data
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    @Binding private var scale: CGFloat

    init(scale: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self._scale = scale
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxAllowedScale
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)

        return scrollView
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content), scale: $scale)
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = self.content
        uiView.zoomScale = scale
        assert(context.coordinator.hostingController.view.superview == uiView)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        @Binding var scale: CGFloat

        init(hostingController: UIHostingController<Content>, scale: Binding<CGFloat>) {
            self.hostingController = hostingController
            self._scale = scale
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            self.scale = scale
        }
    }
}
