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

/// Document wrapper for QuickDraw file types (also QuickTime and MacPaint).
final class QuickDrawViewerDocument: ReferenceFileDocument {

  typealias Snapshot = Data;
  @Published var picture: QDPicture;
  let logger  = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "document");
  
  init(testMessage: String) {
    let frame = QDRect(topLeft: QDPoint.zero, dimension: QDDelta(dv: 120, dh: 120));
    picture = QDPicture(size: 0, frame: frame, filename: testMessage + ".pict");
    let rect = QDRect(topLeft: QDPoint(vertical: 20, horizontal: 20), dimension: QDDelta(dv: 100, dh: 100));
    let frameOp = RectOp(same: false, verb: QDVerb.frame, rect: rect);
    picture.opcodes.append(frameOp);
    var magentaOp = ColorOp(rgb: false, selection: QDColorSelection.foreground);
    magentaOp.color = QDColor.qd1(qd1: QD1Color.magenta);
    picture.opcodes.append(magentaOp);
    let fillOp = RectOp(same: true, verb: QDVerb.fill);
    picture.opcodes.append(fillOp);
    var blueOp = ColorOp(rgb: false, selection: QDColorSelection.foreground);
    blueOp.color = QDColor.qd1(qd1: QD1Color.blue);
    picture.opcodes.append(blueOp);
    let textOp = LongTextOp(position: QDPoint(vertical: 70, horizontal: 40), text: testMessage);
    picture.opcodes.append(textOp);
  }

  init(path: String) throws {
    do {
      let input_url = URL(string: path);
      let parser = try QDParser(contentsOf: input_url!);
      parser.filename = path;
      self.picture = try parser.parse();
    }
    catch {
      let message = String(localized: "Failed parsing QuickDraw file");
      logger.log(level: .error, "\(message): \(error)");
      throw CocoaError(.fileReadCorruptFile);
    }
  }

  // Consiser checking if the file is actually an Apple-Single file and decode this first.
  required init(configuration: ReadConfiguration) throws {
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
        picture = try reader.readQuickTimeImage();
      } catch {
        let message = String(localized: "Failed parsing QuickTime file");
        logger.log(level: .error,  "\(message): \(error)");
        throw error;
      }
    case .macPaintImage:
        do {
          let macPaint = MacPaintImage();
          try macPaint.load(data: data.subdata(in: MacPaintImage.fileHeaderSize..<data.count));
          picture = macPaint.macPicture(filename: configuration.file.filename);
        } catch {
        let message = String(localized: "Failed parsing MacPaint file");
        logger.log(level: .error, "\(message): \(error)");
        throw error;
      }
    default:
      throw CocoaError(.fileReadUnknown);
    }
  }
  
  static var readableContentTypes: [UTType] {
      [.quickDrawImage, .quickTimeImage, .macPaintImage] };

  static var writableContentTypes: [UTType] { [] };

  func snapshot(contentType: UTType) throws -> Data {
    throw CocoaError(.fileWriteUnknown);
  }
  
  func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
    throw CocoaError(.fileWriteNoPermission);
  }
}
