//
//  QuickDrawTypes.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 21.11.2023.
//

import Foundation

///  Quickdraw uses integer coordinates, most of the time.
///  Some values can be fixed point (horizontal position in particular).
///  So we use a fixed point value to represent coordinates.
///  This type supports math operations that could be done quickly on a 68000 processor:
///  - addition, substraction
///  - shifts
public struct FixedPoint : CustomStringConvertible, Equatable, AdditiveArithmetic {
  
  public init (rawValue: Int) {
    self.fixedValue = rawValue;
  }
  
  public init <T : BinaryInteger> (_ value: T) {
    self.fixedValue = Int(value) * FixedPoint.multiplier;
  }
  
  public var description: String {
    return "\(value)";
  }
  
  public var intValue : Int {
    return fixedValue / FixedPoint.multiplier;
  }
  
  public var value : Double {
    return Double(fixedValue) / Double(FixedPoint.multiplier);
  }
  
  private let fixedValue : Int;
  private static let multiplier : Int = 0x10000;
  
  public static let zero = FixedPoint(rawValue: 0);
  
  public static func + (a: FixedPoint, b: FixedPoint) -> FixedPoint {
    return FixedPoint(rawValue: a.fixedValue + b.fixedValue);
  }
  
  public static func - (a: FixedPoint, b: FixedPoint) -> FixedPoint {
    return FixedPoint(rawValue: a.fixedValue - b.fixedValue);
  }
  
  static func >> (a: FixedPoint, b: Int) -> FixedPoint {
    let raw = a.fixedValue >> b;
    return FixedPoint(rawValue: raw);
  }
  
  static func << (a: FixedPoint, b: Int) -> FixedPoint {
    let raw = a.fixedValue << b;
    return FixedPoint(rawValue: raw);
  }
  
}

/// Point in the QuickDraw space.
struct QDPoint : CustomStringConvertible, Equatable {
  
  init<T : BinaryInteger> (vertical : T, horizontal : T) {
    self.vertical = FixedPoint(vertical);
    self.horizontal = FixedPoint(horizontal);
  }
  
  init (vertical: FixedPoint, horizontal: FixedPoint) {
    self.vertical = vertical;
    self.horizontal = horizontal;
  }
  
  public var description: String {
    return "<h\(horizontal),v\(vertical)>";
  }

  static func + (point: QDPoint, delta: QDDelta) -> QDPoint {
    let vertical = point.vertical + delta.dv;
    let horizontal = point.horizontal + delta.dh;
    return QDPoint(vertical: vertical, horizontal: horizontal);
  }
  
  let vertical: FixedPoint;
  let horizontal: FixedPoint;
  
  static let zero = QDPoint(
      vertical: FixedPoint.zero, horizontal: FixedPoint.zero);
  
}

/// Relative position in Quickdraw space, functionally, this is the same as a point, but we distinguish
/// as adding deltas make sense, adding points does not.
struct QDDelta : CustomStringConvertible, Equatable, AdditiveArithmetic {
  
  init(dv : FixedPoint, dh : FixedPoint) {
    self.dv = dv;
    self.dh = dh;
  }
  
  init<T : BinaryInteger> (dv : T, dh : T) {
    self.dv = FixedPoint(dv);
    self.dh = FixedPoint(dh);
  }
  
  public var description: String {
    return "<∂h\(dh),∂v\(dv)>";
  }
  
  let dh: FixedPoint;
  let dv: FixedPoint;
  
  static func - (a: QDDelta, b: QDDelta) -> QDDelta {
    return QDDelta(dv: a.dv - b.dv, dh: a.dh - b.dh);
  }
  
  static func + (a: QDDelta, b: QDDelta) -> QDDelta {
    return QDDelta(dv: a.dv + b.dv, dh: a.dh + b.dh);
  }
  
  static let zero : QDDelta = QDDelta(dv: Int8(0), dh: Int8(0));
}

struct QDRect : CustomStringConvertible, Equatable {
  public var description: String {
    return "Rect: ⌜\(topLeft),\(bottomRight)⌟"
  }
  
  let topLeft: QDPoint;
  let bottomRight: QDPoint;
  var dimensions : QDDelta {
    get {
      let dv = bottomRight.vertical - topLeft.vertical;
      let dh = bottomRight.horizontal - topLeft.horizontal;
      return QDDelta(dv: dv, dh: dh);
    }
  }
  
  var center : QDPoint {
    get {
      let h = (topLeft.horizontal + bottomRight.horizontal) >> 1;
      let v = (topLeft.vertical + bottomRight.vertical) >> 1;
      return QDPoint(vertical: v, horizontal: h);
    }
  }
  
  var isEmpty : Bool {
    return topLeft == bottomRight;
  }
  
  static let empty = QDRect(topLeft: QDPoint.zero, bottomRight: QDPoint.zero);
}

struct QDPolygon {
  var boundingBox : QDRect;
  var points : [QDPoint];
}

struct QDRegionLine {
  let lineNumber : Int;
  let bitmap : [UInt8];
}

let QDRegionEndMark = 0x7fff;

func DecodeRegionLine(boundingBox: QDRect, data: [UInt16], index : inout Int) -> QDRegionLine? {
  var bitmap : [UInt8] = Array<UInt8>(repeating: 0, count: boundingBox.dimensions.dh.intValue);
  let lineNumber = Int(data[index]);
  if lineNumber == QDRegionEndMark {
    return nil;
  }
  index += 1
  while index < data.count {
    var start = Int(data[index]);
    index += 1;
    if (start == QDRegionEndMark) {
      return QDRegionLine(lineNumber: lineNumber, bitmap:bitmap);
    }
    var end = Int(data[index]);
    index += 1;
    if end == QDRegionEndMark {
      end = start;
      start = 0;
    }
    for i in start..<end {
      bitmap[i - boundingBox.topLeft.horizontal.intValue] = 0xff;
    }
  }
  return QDRegionLine(lineNumber: lineNumber, bitmap:bitmap);
}

func BitLineToRanges(line: [UInt8]) -> [Range<Int>] {
  var index = 0;
  var result : [Range<Int>] = [];
  while true {
    while index < line.count && line[index] == 0  {
      index += 1;
    }
    if index == line.count {
      return result;
    }
    let start = index;
    while index < line.count && line[index] != 0  {
      index += 1;
    }
    result.append(start..<index);
    if index == line.count {
      return result;
    }
  }
}

func DecodeRegionData(boundingBox: QDRect, data: [UInt16]) -> [QDRect]{// Why
  // Decode as bitmap
  let width = boundingBox.dimensions.dh.intValue;
  let height = boundingBox.dimensions.dv.intValue + 1;
  let emptyLine : [UInt8] = Array(repeating: 0, count: Int(width));
  var bitLines: [[UInt8]] = Array(repeating: emptyLine, count: Int(height));
  var index : Int = 0;
  /// Decode the region lines.
  while index < data.count {
    let line = DecodeRegionLine(boundingBox: boundingBox, data: data, index: &index);
    if line == nil {
      break;
    }
    let l = line!.lineNumber - boundingBox.topLeft.vertical.intValue;
    bitLines[l] = line!.bitmap;
  }
  /// Xor each line with the previous
  for y in 1..<height {
    for x in 0..<width {
      bitLines[y][x] = bitLines[y - 1][x] ^ bitLines[y][x];
    }
  }
  // Convert to rectangles
  // TODO: combine matching rects between lines
  var result : [QDRect] = [];
  for (l, line) in bitLines.enumerated() {
    let ranges = BitLineToRanges(line:line);
    for r in ranges {
      let topLeft = boundingBox.topLeft + QDDelta(dv: l, dh: r.lowerBound);
      let bottomRight = topLeft + QDDelta(dv : 1, dh : r.count);
      result.append(QDRect(topLeft:topLeft, bottomRight: bottomRight));
    }
  }
  return result;
}

struct QDRegion {
  var boundingBox: QDRect;
  var isRect : Bool {
    return rects.isEmpty;
  }
  
  let rects : [QDRect];
}

struct QDColor : CustomStringConvertible, Hashable {
  
  var description: String {
    var result = "Color: 0x";
    result += String(format: "%04X", red);
    result += "|";
    result += String(format: "%04X", green);
    result += "|";
    result += String(format: "%04X", green);
    return result;
  }
  
  let red : UInt16;
  let green: UInt16;
  let blue: UInt16;
  
  var rgb : [UInt8] {
    var data : [UInt8] = [];
    data.append(UInt8(red >> 8));
    data.append(UInt8(green >> 8));
    data.append(UInt8(blue >> 8));
    return data;
  }
  
  static let black = QDColor(red: 0x00, green: 0x00, blue: 0x00);
  static let white = QDColor(red: 0xffff, green: 0xffff, blue: 0xffff);
  static let red = QDColor(red: 0xffff, green: 0x00, blue: 0x00);
  static let green = QDColor(red: 0x00, green: 0xffff, blue: 0x00);
  static let blue = QDColor(red: 0x00, green: 0x00, blue: 0xffff);
  static let cyan = QDColor(red: 0x00, green: 0xffff, blue: 0xffff);
  static let magenta = QDColor(red: 0xffff, green: 0x00, blue: 0xffff);
  static let yellow = QDColor(red: 0xffff, green: 0xffff, blue: 0x00);
}

func QD1Color(code: UInt32) throws -> QDColor {
  switch code {
    case 33: return QDColor.black;
    case 30: return QDColor.white;
    case 205: return QDColor.red;
    case 341: return QDColor.green;
    case 409: return QDColor.blue;
    case 273: return QDColor.cyan;
    case 137: return QDColor.magenta;
    case 69: return QDColor.yellow;
  default:
    throw QuickDrawError.unsupportedColor(colorCode: code);
  }
}


enum QDVerb : UInt16 {
  case frame = 0;
  case paint = 1;
  case erase = 2;
  case invert = 3;
  case fill = 4;
  case clip = 50;
}

enum QDColorSelection : UInt8 {
  case foreground = 0;
  case background = 1;
  case operations = 2;
  case highlight = 3;
}

struct QDFontStyle : OptionSet {
  let rawValue: UInt8;
  static let boldBit = QDFontStyle(rawValue: 1 << 0);
  static let italicBit = QDFontStyle(rawValue: 1 << 1);
  static let ulineBit = QDFontStyle(rawValue: 1 << 2);
  static let outlineBit = QDFontStyle(rawValue: 1 << 3);
  static let shadowBit = QDFontStyle(rawValue: 1 << 4);
  static let condenseBit = QDFontStyle(rawValue: 1 << 5);
  static let extendBit = QDFontStyle(rawValue: 1 << 6);
  
  static let defaultStyle = QDFontStyle([]);
}

// the 8 first transfer modes from QuickDraw.p
// Patterns operation is bit 5.
enum QuickDrawTransferMode : UInt16 {
  case copyMode = 0;
  case orMode = 1;
  case xorMode = 2;
  case bicMode = 3;
  case notCopyMode = 4;
  case notOrMode = 5;
  case notXorMode = 6;
  case notBic = 7;
}

struct QuickDrawMode {
  init(value: UInt16) {
    mode = QuickDrawTransferMode(rawValue: value % 8)!;
    isPattern = value & 8 != 0;
    isDither = value & 64 != 0;
  }
  let mode : QuickDrawTransferMode;
  let isPattern : Bool;
  let isDither: Bool;
  
  static let defaultMode : QuickDrawMode  = QuickDrawMode(value: 0);
}

struct QDResolution {
  let hRes : FixedPoint;
  let vRes : FixedPoint;
  
  static let defaultResolution = QDResolution(hRes: FixedPoint(72), vRes : FixedPoint(72));
}

struct QDPattern {
  let bytes : [UInt8];
  
  var intensity : Double {
    var total = 0;
    for b in bytes {
      total += b.nonzeroBitCount;
    }
    return Double(total) / (8.0 * Double(bytes.count));
  }
  
  func mixColors(fgColor: QDColor, bgColor: QDColor) -> QDColor {
    let fg = intensity;
    let bg = 1 - fg;
    let red = UInt16(fg * Double(fgColor.red) + bg * Double(bgColor.red));
    let green = UInt16(fg * Double(fgColor.green) + bg * Double(bgColor.green));
    let blue = UInt16(fg * Double(fgColor.blue) + bg * Double(bgColor.blue));
    return QDColor(red: red, green: green, blue: blue);
  }
  
  static let full = QDPattern(bytes:[0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
  static let empty = QDPattern(bytes:[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
}

class PenState {
  
  var location : QDPoint = QDPoint.zero;
  var size: QDPoint = QDPoint(vertical: 1, horizontal: 1);
  var mode: QuickDrawMode = QuickDrawMode.defaultMode;
  var fgColor : QDColor = QDColor.black;
  var bgColor : QDColor = QDColor.white;
  var opColor : QDColor = QDColor.black;
  var highlightColor : QDColor = QDColor(red: 0, green: 0, blue: 0xffff);
  var drawPattern: QDPattern = QDPattern.full;
  var fillPattern: QDPattern = QDPattern.full;
  var ovalSize : QDDelta = QDDelta.zero;
  
  var drawColor : QDColor {
    let result = drawPattern.mixColors(fgColor: fgColor, bgColor: bgColor);
    return result;
  }
  
  var fillColor : QDColor {
    return fillPattern.mixColors(fgColor: fgColor, bgColor: bgColor);
  }
  
  var penWidth : FixedPoint {
    return (size.horizontal + size.vertical) >> 1;
  }
}

struct QDGlyphState : OptionSet {
  let rawValue: UInt8;
  static let outlinePreferred = QDGlyphState(rawValue: 1 << 0);
  static let preserveGlyphs = QDGlyphState(rawValue: 1 << 1);
  static let fractionalWidths = QDGlyphState(rawValue: 1 << 2);
  static let scalingDisabled = QDGlyphState(rawValue: 1 << 3);
  static let defaultState = QDGlyphState([]);
}

/// Various text related properties.
class QDFontState {
  func getFontName() -> String? {
    if let name = self.fontName {
      return name;
    }
    switch fontId {
      case 2: return "New York";
      case 3: return "Geneva";
      case 4: return "Monaco";
      case 5: return  "Venice";
      case 6: return "Venice";
      case 7: return "Athens";
      case 8: return "San Francisco";
      case 9: return "Toronto";
      case 11: return "Cairo";
      case 12: return "Los Angeles";
      case 20: return "Times";
      case 21: return "Helvetica";
      case 22: return "Courrier";
      case 23: return "Symbol";
      case 24: return "Mobile";
      default:
        return nil;
    }  // Switch
  }
  var fontId : Int = 0;
  var fontName : String?;
  var fontSize : Int = 12;
  var fontMode : QuickDrawMode = QuickDrawMode.defaultMode;
  var location : QDPoint = QDPoint.zero;
  var fontStyle : QDFontStyle = QDFontStyle.defaultStyle;
  var glyphState : QDGlyphState = QDGlyphState.defaultState;
}

enum QDPackType : UInt16 {
  case defaultPack = 0;
  case noPack = 1;
  case removePadByte = 2;
  case pixelRunLength = 3;
  case componentRunLength = 4;
}

// Confusingly, this is called `PixMap` record in Inside Quickdraw,.
// even though there is no actual pixel data.
class QDPixMapInfo : CustomStringConvertible {
  init() {}
  
  public var description: String {
    var result = "PixMapInfo version: \(version) pack-size: \(packSize) ";
    result += "pack-type: \(packType) ";
    if resolution != nil {
      result += "resolution: \(resolution!) ";
    }
    result += "pixel type: \(pixelType) ";
    result += "pixel size: \(pixelSize) ";
    result += "composant count: \(cmpCount) ";
    result += "composant size: \(cmpSize) ";
    result += "plane byte: \(planeByte) ";
    if clut != nil {
      result += "clut: \(clut!)";
    }
    return result;
  }

  var version : Int = 0;
  var packType : QDPackType = QDPackType.defaultPack;
  var packSize : Int = 0;
  var resolution : QDResolution?;
  var pixelType : Int = 0;
  var pixelSize : Int = 0;
  var cmpCount : Int = 0;
  var cmpSize : Int = 0;
  var planeByte : Int64 = 0;
  var clutId : String = "";
  var clutSeed : String = "";
  var clut : QDColorTable?;

}


class QDBitMapInfo : CustomStringConvertible {
  init(isPacked: Bool) {
    self.isPacked = isPacked;
  }
  
  var hasShortRows : Bool {
    return rowBytes < 250;
  }
  
  let isPacked : Bool;
  var rowBytes : Int = 0;
  var bounds : QDRect = QDRect.empty;
  var srcRect : QDRect?;
  var dstRect : QDRect?;
  var mode : QuickDrawMode = QuickDrawMode(value: 0);
  var data : [UInt8] = [UInt8]();
  var pixMapInfo : QDPixMapInfo?;
  
  var height : Int {
    return bounds.dimensions.dv.intValue;
  }
  
  var cmpSize : Int {
    if let pix_info = pixMapInfo {
      return pix_info.cmpSize;
    }
    return 1;
  }
  
  var pixelSize : Int {
    if let pix_info = pixMapInfo {
      return pix_info.pixelSize;
    }
    return 1;
  }
  
  var clut : QDColorTable {
    if let pix_info = pixMapInfo {
      return pix_info.clut!;
    }
    return QDColorTable.blackWhite;
  }
  
  public var description : String {
    var result = "Bitmap info [row_bytes: \(rowBytes) packed: \(isPacked) ";
    result += "Bounds \(bounds) "
    if srcRect != nil {
      result += "src: \(srcRect!) ";
    }
    if dstRect != nil {
      result += "dst: \(dstRect!) ";
    }
    result += "Mode: \(mode)]";
    if let pixmap = pixMapInfo {
      result += "Pixmap: \(pixmap)]";
    }
    return result;
  }
  
}

class QDColorTable : CustomStringConvertible {
  public var description: String {
    let string_flag = String(format: "%0X", clutFlags);
    var result = "flags: \(string_flag) ["
    /*
    for (index, color) in clut.enumerated() {
      let rgb = color.rgb;
      let color_str = String(format: "%02X|%02X|%02X", rgb[0], rgb[1], rgb[2]);
      result += "\(index) - \(color_str), ";
    }*/
    result += "size \(clut.count) ";
    result += "]";
    return result;
  }
  
  init(clutFlags: UInt16) {
    self.clutFlags = clutFlags;
  }
  
  init(clut : [QDColor]) {
    self.clutFlags = 0;
    self.clut = clut;
  }
  
  let clutFlags : UInt16;
  var clut : [QDColor] = [];
  
  static let blackWhite : QDColorTable = QDColorTable(clut:[QDColor.black, QDColor.white]);
}

class QuickTimePayload : CustomStringConvertible {
  
  public var description: String {
    var result = "dstRect : \(dstRect) version \(version).\(revision) ";
    result += "dimension : \(dimensions) type: \(payloadType)/\(compressorDevelopper) resolution: \(resolution) ";
    result += "frame: \(frameNumber) depth: \(depth) name: \(name) ";
    result += "data: \(data!.count)";
    return result;
  }
  
  var dstRect : QDRect = QDRect.empty;
  var size : Int = 0;
  var compressorCreator : String = "";
  var compressorDevelopper : String = "";
  var payloadType : String = "";
  var version : Int = 0;
  var revision : Int = 0;
  var temporalQuality : UInt32 = 0;
  var spatialQuality : UInt32 = 0;
  var dimensions: QDDelta = QDDelta.zero;
  var resolution: QDResolution = QDResolution.defaultResolution;
  var dataSize : Int = 0;
  var frameNumber : Int = 0;
  var depth : Int = 0;
  var name : String = "";
  var clutId : Int = 0;
  var data : Data?;
}

class QDPicture : CustomStringConvertible {
  init(size: UInt16, frame:QDRect) {
    self.size = size;
    self.frame = frame;
  }
  let size: UInt16;
  let frame: QDRect;
  var version: UInt8 = 1;
  var opcodes: [OpCode] = [];
  
  public var description : String {
    var result = "Picture size: \(size) version: \(version) ";
    result += "frame: \(frame)\n";
    result += "===========================\n";
    for (index, opcode) in opcodes.enumerated() {
      result += "\(index): \(opcode)\n";
    }
    result += "===========================\n";
    return result;
  }
}


