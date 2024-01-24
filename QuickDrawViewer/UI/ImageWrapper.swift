//
//  ImageWrapper.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 02.01.2024.
//

import os
import Foundation
import UniformTypeIdentifiers
import SwiftUI

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


extension QDPicture : Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .pdf) {
      picture in picture.pdfData() as Data }.suggestedFileName { $0.filename ?? "quickdraw" + ".pdf" }
  }
}

/// Utility function that converts a picture into an image provider.
/// - Parameter picture: picture to render
/// - Returns: description
func ProvidePicture(picture: QDPicture) -> [NSItemProvider] {
  let pdfProvider = NSItemProvider(item:picture.pdfData(), typeIdentifier: UTType.pdf.identifier);
  return [pdfProvider];
}

