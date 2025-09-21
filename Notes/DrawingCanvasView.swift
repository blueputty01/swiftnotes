//
//  DrawingCanvasView.swift
//  Notes
//
//  Created by Alex Yang on 3/6/25.
//

import SwiftUI
import PencilKit

struct DrawingCanvasView: View {
    @Environment(\.undoManager) private var undoManager
    @State var canvasView: PKCanvasView
    var onDrawingChanged: () -> Void = {}
    
    var body: some View {
        MyCanvas(canvasView: $canvasView, onDrawingChanged: onDrawingChanged)
    }
}
