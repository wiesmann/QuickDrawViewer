//
//  ImageWrapper.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 02.01.2024.
//
// Various utility functions to glue the QuickDraw renderer with UI-Kit.

import os
import Foundation
import UniformTypeIdentifiers
import SwiftUI


/// Add UI related features.
extension QDPicture {
  
  func pdfData() -> NSData {
    let data = NSMutableData();
    let renderer = PDFRenderer(data: data);
    do {
      try renderer.execute(picture: self, zoom: 1.0);
    } catch {
      let logger : Logger = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "imageWrapper");
      logger.log(level: .error, "Failed rendering \(error)");
    }
    return data;
  }
}

func MakePdfFilename(picture: QDPicture) -> String {
  let filename = picture.filename ?? "picture.pict";
  return filename.replacingOccurrences(of: "pict", with: "pdf");
}

/// Make it possible to transfer pictures into the clipboard, drag-and-drop.
extension QDPicture : Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .pdf) {
      picture in picture.pdfData() as Data }.suggestedFileName { MakePdfFilename(picture: $0) }
  }
}

/// Utility function that converts a picture into an image provider.
/// - Parameter picture: picture to render
/// - Returns: description
func ProvidePicture(picture: QDPicture) -> [NSItemProvider] {
  let pdfProvider = NSItemProvider(item:picture.pdfData(), typeIdentifier: UTType.pdf.identifier);
  return [pdfProvider];
}

func renderPicture(picture: QDPicture, context : CGContext, zoom: Double, logger: Logger) throws -> Void {
  let startTime = CFAbsoluteTimeGetCurrent();
  let renderer = QuickdrawCGRenderer(context: context);
  try renderer.execute(picture: picture, zoom: zoom);
  let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime;
  let filename = picture.filename ?? "";
  let frame = picture.frame;
  for (pos, opcode) in picture.opcodes.enumerated() {
    let entry = "\(pos): \(opcode)";
    logger.log(level: .debug, "\(entry)");
  }
  logger.log(level: .info, "\(filename) \(frame)\n rendered in : \(timeElapsed) seconds");
}
