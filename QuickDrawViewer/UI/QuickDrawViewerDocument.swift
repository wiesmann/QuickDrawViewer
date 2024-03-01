//
//  QuickDrawViewerDocument.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import os
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
  static var quickDrawImage: UTType {
    UTType(importedAs: "com.apple.pict")
  }
  static var quickTimeImage: UTType {
    UTType(importedAs: "com.apple.quicktime-image")
  }
  static var macPaintImage : UTType {
    UTType(importedAs: "com.apple.macpaint-image")
  }
}

struct QuickDrawViewerDocument: FileDocument {
  
  var picture : QDPicture?;
  let logger : Logger;
  
  init() {
    self.logger = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "document");
  }
  
  init(path: String) {
    self.init();
    do {
      let input_url = URL(string: path);
      let parser = try QDParser(contentsOf: input_url!);
      picture = try parser.parse();
    }
    catch {
      logger.log(level: .error, "Failed rendering \(error)");
    }
  }
  
  init(configuration: ReadConfiguration) throws {
    self.init();
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    switch configuration.contentType {
    case .quickDrawImage:
      let parser = try QDParser(data: data);
      parser.filename = configuration.file.filename;
      picture = try parser.parse();
    case .quickTimeImage:
      do {
        let reader = try QuickDrawDataReader(data: data, position: 0);
        reader.filename = configuration.file.filename;
        picture = try parseQuickTimeImage(reader: reader);
      } catch {
        logger.log(level: .error, "Failed parsing quicktime: \(error)");
        throw error;
      }
    case .macPaintImage:
      let macPaint = MacPaintImage();
      try macPaint.load(data: data.subdata(in: 512..<data.count));
      picture = macPaint.macPicture(filename: configuration.file.filename);
    default:
      throw CocoaError(.fileReadUnknown);
    }
  }
  
  static var readableContentTypes: [UTType] {
      [.quickDrawImage, .quickTimeImage, .macPaintImage] };
  // static var writableContentTypes: [UTType] { [.pdf] };
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    throw CocoaError(.fileWriteUnsupportedScheme);
  }
}
