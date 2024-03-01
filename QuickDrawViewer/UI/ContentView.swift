//
//  ContentView.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import os
import SwiftUI
import UniformTypeIdentifiers


struct ContentView: View {
  
  @Binding var document: QuickDrawViewerDocument;
  @State private var renderZoom = 1.0
  @State private var isExporting = false
  
  let logger : Logger = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "view");
  
  func renderCG(context : CGContext) -> Void {
    let picture = $document.picture.wrappedValue!;
    let startTime = CFAbsoluteTimeGetCurrent();
    do {
      let renderer = QuickdrawCGRenderer(context: context);
      try renderer.execute(picture: picture, zoom: renderZoom);
      let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime;
      let filename = picture.filename ?? "";
      let frame = picture.frame;
      for (pos, opcode) in picture.opcodes.enumerated() {
        let entry = "\(pos): \(opcode)";
        self.logger.log(level: .debug, "\(entry)");
      }
      self.logger.log(level: .info, "\(filename) \(frame)\n rendered in : \(timeElapsed) seconds");
    } catch {
      self.logger.log(level: .error, "Failed rendering: \(error)");
    }
  }
  
  func render(context : inout GraphicsContext, dimension : CGSize) -> Void {
    context.withCGContext(content: self.renderCG);
  }
 
  func exportDone(result: Result<URL, Error> ) -> Void {
    isExporting = false;
  }
  
  func QDView() -> some View {
    let picture = $document.picture.wrappedValue!;
    let width = picture.frame.dimensions.dh.value * renderZoom;
    let height = picture.frame.dimensions.dv.value * renderZoom;
    let canvas = Canvas(opaque: true, colorMode: ColorRenderingMode.linear, rendersAsynchronously: true, renderer: self.render).frame(width: width, height: height);
    return canvas.focusable().copyable([picture]).draggable(picture).fileExporter(isPresented: $isExporting, item: picture, contentTypes: [.pdf], defaultFilename: MakePdfFilename(picture:picture), onCompletion: exportDone).toolbar {
      ToolbarItem() {
        Button {
          isExporting = true
        } label: {
          Label(String(localized: "Export file"), systemImage: "square.and.arrow.up")
        }
      }
    }
  }

  var body: some View {
    ScrollView([.horizontal, .vertical]){QDView()};
  }
}
  
#Preview {
  ContentView(document: .constant(QuickDrawViewerDocument(path: "file:///Users/wiesmann/Projects/personal/QuickDrawKit/test_files/7.pict")))
}
