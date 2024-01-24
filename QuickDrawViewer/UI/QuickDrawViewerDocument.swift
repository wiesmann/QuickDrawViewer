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
      picture = try parser.parse(filename: path);
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
    let parser = try QDParser(data:data);
    picture = try parser.parse(filename: configuration.file.filename);
  }

  static var readableContentTypes: [UTType] { [.quickDrawImage] };
  // static var writableContentTypes: [UTType] { [.pdf] };

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    throw CocoaError(.fileWriteUnsupportedScheme);
  }
}
