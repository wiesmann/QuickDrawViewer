//
//  Targa.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.04.2024.
//

import Foundation

enum TargaImageError : Error {
  case unknownColorMapType(colorMapType: UInt8);
  case unknownImageType(imageType: UInt8);
  case unsupportedImageType(imageType: TargaImageType);
  case mismatchedDimensions(expected: QDDelta, parsed: QDDelta);
  case unsupportedOrigin(origin: QDPoint);
  case unsupportedAlphaDepth(depth: UInt8);
  case unsupportPaletteDepth(depth: UInt8);
  case wrongColorMapType;
  case unsupportPaletteFirstEntry(offset: UInt16);
}

enum TargaColorMapType : UInt8 {
  case noColorMap = 0;
  case hasColorMap = 1;
}

enum TargaImageType : UInt8 {
  case noImageData = 0;
  case colorMap = 1;
  case trueColor = 2;
  case grayScale = 3;
  case rleColorMap = 9;
  case rleTrueColor = 10;
  case rleGrayScale = 11;
}

func decompressTarga(data : ArraySlice<UInt8>, maxSize : Int, byteNum: Int) throws -> [UInt8] {
  var result : [UInt8] = [];
  var p = data.startIndex;
  while p < data.endIndex && result.count < maxSize {
    let c = data[p];
    p += 1;
    if c & 0x80 > 0 {
      let run = Int(c & 0x7f) + 1;
      let end = p + byteNum;
      p += try copyRepeated(length: run, src: data[p..<end], destination: &result, byteNum: byteNum);
    } else {
      let run = Int(c + 1);
      let end = p + run * byteNum
      p += try copyDiscrete(length: run, src: data[p..<end], destination: &result, byteNum: byteNum);
    }
  }
  return result;
}

/// We need a special Targa decoder because the color-table can be external.
class TargaImage : PixMapMetadata {
  
  init(dimensions: QDDelta, clut: QDColorTable?) {
    self.dimensions = dimensions;
    self.clut = clut;
    self.pixmap = [];
  }
  
  private func swap16BitColor() {
    let pairs = pixmap.count / 2;
    for p in 0..<pairs {
      let i = p * 2;
      pixmap.swapAt(i, i + 1);
    }
  }
  
  private func invert8BitGray() {
    for i in 0..<pixmap.count {
      pixmap[i] = 255 - pixmap[i];
    }
  }
  
  func load(data : Data) throws {
    let reader = try QuickDrawDataReader(data: data, position:0);
    let idLength = try reader.readUInt8();
    let rawColorType = try reader.readUInt8();
    guard let colorMapType = TargaColorMapType(rawValue: rawColorType) else {
      throw TargaImageError.unknownColorMapType(colorMapType: rawColorType);
    }
    let rawImageType = try reader.readUInt8();
    guard let imageType = TargaImageType(rawValue: rawImageType) else {
      throw TargaImageError.unknownImageType(imageType: rawImageType);
    }
    self.imageType = imageType;
    // Color map specification
    let paletteFirstEntry = try reader.readUInt16LE();
    guard paletteFirstEntry == 0 else {
      throw TargaImageError.unsupportPaletteFirstEntry(offset: paletteFirstEntry);
    }
    let paletteSize = try reader.readUInt16LE();
    let paletteDepth = try reader.readUInt8();
    assert(reader.position == 8);
    // Image specification
    let xOrigin = try reader.readUInt16LE();
    let yOrigin = try reader.readUInt16LE();
    let origin = QDPoint(vertical: yOrigin, horizontal: xOrigin);
    guard origin == QDPoint.zero else {
      throw TargaImageError.unsupportedOrigin(origin: origin);
    }
    let width = Int(try reader.readUInt16LE());
    let height = Int(try reader.readUInt16LE());
    let headerDimensions = QDDelta(dv: FixedPoint(height), dh: FixedPoint(width));
    guard headerDimensions == dimensions else {
      throw TargaImageError.mismatchedDimensions(expected: dimensions, parsed: headerDimensions);
    }
    // Adjust cmp size
    self.pixelSize = Int(try reader.readUInt8());
    switch pixelSize  {
      case 8: cmpSize = 8;
      case 16: cmpSize = 5
      case 24: cmpSize = 8;
      default: cmpSize = 0;
    }
    // TODO: do something about α-channels
    let imageDescriptor = try reader.readUInt8();
    let alphaBits = imageDescriptor & 0x7;
    guard alphaBits == 0 else {
      throw TargaImageError.unsupportedAlphaDepth(depth: alphaBits);
    }
    // Image ID
    imageIdData = try reader.readUInt8(bytes: Int(idLength));
    // Palette data
    let paletteBytes = Int(paletteSize) * Int(paletteDepth / 8);
    let paletteData = try reader.readUInt8(bytes: paletteBytes);
    // Only load the palette if we need to.
    if paletteData.count > 0 && self.clut == nil {
      if colorMapType == .noColorMap {
        throw TargaImageError.wrongColorMapType;
      }
      switch paletteDepth {
        case 8:
          clut = clutFromRgb(rgb: paletteData);
        default: 
          throw TargaImageError.unsupportPaletteDepth(depth: paletteDepth);
      }
    }
    // Check the tail
    /*
    let tailPosition = data.count - 26
    let tailReader = try QuickDrawDataReader(data: data, position: tailPosition);
    let extensionAreaOffset = try tailReader.readUInt32LE();
    let developperOffset = try tailReader.readUInt32LE();
    let signature = try tailReader.readString(bytes: 16);
     */
    // Decoding
    self.rowBytes = width * pixelSize / 8;
    let imageData = try reader.readUInt8(bytes: reader.remaining);
    
    switch imageType {
      case .rleColorMap:
        let slice = imageData[0..<imageData.count];
        pixmap = try decompressTarga(data: slice, maxSize: rowBytes * height, byteNum: 1);
      case .rleTrueColor:
        let slice = imageData[0..<imageData.count];
        pixmap = try decompressTarga(data: slice, maxSize: rowBytes * height, byteNum: pixelSize / 8);
        if pixelSize == 16 {
          swap16BitColor();
        }
      case .rleGrayScale:
        let slice = imageData[0..<imageData.count];
        pixmap = try decompressTarga(data: slice, maxSize: rowBytes * height, byteNum: 1);
        invert8BitGray()
      default:
        throw TargaImageError.unsupportedImageType(imageType: imageType);
    }
  }
  
  var description: String {
    return "Targa: " + describePixMap(self);
  }
  
  let dimensions: QDDelta
  var clut: QDColorTable?
  var imageType: TargaImageType = .noImageData;
  var rowBytes: Int = 0;
  var cmpSize: Int = 0;
  var pixelSize: Int = 0;

  var pixmap : [UInt8];
  var imageIdData : [UInt8] = [];
}
