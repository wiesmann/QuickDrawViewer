//
//  ContentView.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import os
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
  
  @ObservedObject  var document: QuickDrawViewerDocument;
  
  @State private var renderZoom = 1.0;
  @State private var isExporting = false;
  @State private var isAlerting = false;
  @State private var alertMessage : Alert? = nil;
  
  let logger : Logger = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "view");
  
  func renderCG(context : CGContext) -> Void {
    let picture = $document.picture.wrappedValue;
    do {
      try renderPicture(picture: picture, context: context, zoom: renderZoom, logger: self.logger);
    } catch {
      alert(title: String(localized: "Failed rendering picture"), message: "\(error)");
    }
  }
  
  func render(context : inout GraphicsContext, dimension : CGSize) -> Void {
    context.withCGContext(content: self.renderCG);
  }
  
  func alert(title: String, message: String?) -> Void {
    isAlerting = true;
    if let msg = message {
      alertMessage = Alert(title:Text(title), message:Text(msg));
    } else {
      alertMessage = Alert(title:Text(title));
    }
  }
 
  func exportDone(result: Result<URL, Error> ) -> Void {
    isExporting = false;
  }
    
  func doPrint(picture: QDPicture) -> Void {
    let printInfo = NSPrintInfo();
    let pdfData = picture.pdfData();
    guard let document = PDFDocument(data: pdfData as Data) else {
      alert(title: String(localized: "Failed to generate PDF document"), message: nil);
      return;
    }
    guard let operation = document.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) else {
      alert(title: String(localized: "Failed build print operation"), message: nil);
      return;
    }
    operation.run();
  }
  
  func QDView() -> some View {
    let picture = $document.picture.wrappedValue;
    let width = picture.frame.dimensions.dh.value * renderZoom;
    let height = picture.frame.dimensions.dv.value * renderZoom;
    let canvas = Canvas(opaque: true, colorMode: ColorRenderingMode.linear, rendersAsynchronously: true, renderer: self.render).frame(width: width, height: height);
    return AnyView(canvas.focusable().copyable([picture]).draggable(picture).fileExporter(isPresented: $isExporting, item: picture, contentTypes: [.pdf], defaultFilename: MakePdfFilename(picture:picture), onCompletion: exportDone).toolbar {
      ToolbarItemGroup() {
        Button {
          isExporting = true
        } label: {
          Label(String(localized: "Export file"), systemImage: "square.and.arrow.up")
        }
        Button {
          doPrint(picture:picture);
        } label: {
          Label(String(localized: "Print"), systemImage: "printer")
        }
      }
    }.alert(isPresented:$isAlerting){return $alertMessage.wrappedValue!})
  }

  var body: some View {
    ScrollView([.horizontal, .vertical]){QDView()};
  }
}
  
