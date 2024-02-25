//
//  QuickDrawTypes.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 21.11.2023.
//

import Foundation

func byteArrayLE<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
  withUnsafeBytes(of: value.littleEndian, Array.init)
}

func byteArrayBE<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
  withUnsafeBytes(of: value.bigEndian, Array.init)
}

/// Point in the QuickDraw space.
struct QDPoint : CustomStringConvertible, Equatable {
  
  init (vertical: FixedPoint, horizontal: FixedPoint) {
    self.vertical = vertical;
    self.horizontal = horizontal;
  }
  
  public init <T : BinaryInteger> (vertical:  T, horizontal: T) {
    self.init(vertical: FixedPoint(vertical), horizontal: FixedPoint(horizontal));
  }
  
  public var description: String {
    return "<h\(horizontal),v\(vertical)>";
  }

  static func + (point: QDPoint, delta: QDDelta) -> QDPoint {
    let vertical = point.vertical + delta.dv;
    let horizontal = point.horizontal + delta.dh;
    return QDPoint(vertical: vertical, horizontal: horizontal);
  }
  
  static func - (point: QDPoint, delta: QDDelta) -> QDPoint {
    return point + (-delta);
  }
  
  static func - (p1: QDPoint, p2: QDPoint) -> QDDelta {
    let dv = p1.vertical - p2.vertical;
    let dh = p1.horizontal - p2.horizontal;
    return QDDelta(dv: dv, dh: dh);
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

  static func + (a: QDDelta, b: QDDelta) -> QDDelta {
    return QDDelta(dv: a.dv + b.dv, dh: a.dh + b.dh);
  }
  
  static func - (lhs: QDDelta, rhs: QDDelta) -> QDDelta {
    return lhs + (-rhs);
  }

  static prefix func -(d: QDDelta) -> QDDelta {
    return QDDelta(dv: -d.dv, dh: -d.dh);
  }
  
  static let zero : QDDelta = QDDelta(dv: Int8(0), dh: Int8(0));
}

/// Rectangle
struct QDRect : CustomStringConvertible, Equatable {
  
  init(topLeft: QDPoint, bottomRight: QDPoint) {
    self.topLeft = topLeft;
    self.bottomRight = bottomRight;
  }
  
  init(topLeft: QDPoint, dimension : QDDelta) {
    self.topLeft = topLeft;
    self.bottomRight = topLeft + dimension;
  }
  
  public var description: String {
    return "Rect: ⌜\(topLeft),\(bottomRight)⌟"
  }
  
  let topLeft: QDPoint;
  let bottomRight: QDPoint;
  
  var dimensions : QDDelta {
    get {
      return bottomRight - topLeft;
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

class QDPolygon {
  
  init(boundingBox: QDRect?, points: [QDPoint]) {
    self.boundingBox = boundingBox;
    self.points = points;
    self.closed  = false;
  }
  
  convenience init() {
    self.init(boundingBox: nil, points: []);
  }
  
  var boundingBox : QDRect?;
  var points : [QDPoint];
  var closed : Bool;
  
  func AddLine(line : [QDPoint]) {
    if points.isEmpty {
      self.points = line;
      return;
    }
    if line.first == points.last {
      points.removeLast();
    }
    points.append(contentsOf: line);
  }
}

/// A single, raw line of the QuickDraw region.
/// bitmap is one _byte_ per pixel.
struct QDRegionLine {
  let lineNumber : Int;
  let bitmap : [UInt8];
}

let QDRegionEndMark = 0x7fff;

/// Decodes one line of the region data.
/// - Parameters:
///   - boundingBox: bounding box of the region
///   - data: region data, as an array of shorts
///   - index: position in the data, will be updated.
/// - Returns: a decoded line (line number + byte array)
func DecodeRegionLine(boundingBox: QDRect, data: [UInt16], index : inout Int) throws -> QDRegionLine? {
  var bitmap : [UInt8] = Array<UInt8>(repeating: 0, count: boundingBox.dimensions.dh.rounded);
  let lineNumber = Int(data[index]);
  if lineNumber == QDRegionEndMark {
    return nil;
  }
  index += 1
  while index < data.count {
    var start = Int(Int16(bitPattern: data[index]));
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
    guard start <= end  else {
      throw QuickDrawError.corruptRegionLine(line: lineNumber);
    }
    for i in start..<end {
      let p = i - boundingBox.topLeft.horizontal.rounded;
      guard p >= 0 && p < bitmap.count else {
        throw QuickDrawError.corruptRegionLine(line: lineNumber);
      }
      bitmap[p] = 0xff;
    }
  }
  return QDRegionLine(lineNumber: lineNumber, bitmap:bitmap);
}

/// Convert a line of pixels into a sequence of ranges.
/// - Parameter line: pixels of one line, one byte per pixel
/// - Returns: set of ranges of active (non zero) pixels.
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


/// Decode the quickdraw  region data
/// - Parameters:
///   - boundingBox: bounding box of the region
///   - data: region data as an array of shorts
/// - Returns: two data structures representing the region,
///            a sequence of rectanbles and a bitmap (2D array, one byte per pixel).
func DecodeRegionData(boundingBox: QDRect, data: [UInt16]) throws -> ([QDRect], [[UInt8]])  {
  /// Decode as bitmap
  let width = boundingBox.dimensions.dh.rounded;
  let height = boundingBox.dimensions.dv.rounded + 1;
  guard width > 0 && height > 0 else {
    throw QuickDrawError.corruptRegion(boundingBox: boundingBox);
  }
  let emptyLine : [UInt8] = Array(repeating: 0, count: width);
  var bitLines: [[UInt8]] = Array(repeating: emptyLine, count: height);
  var index : Int = 0;
  /// Decode the region lines.
  while index < data.count {
    let line = try DecodeRegionLine(boundingBox: boundingBox, data: data, index: &index);
    guard line != nil else {
      break;
    }
    let l = line!.lineNumber - boundingBox.topLeft.vertical.rounded;
    bitLines[l] = line!.bitmap;
  }
  /// Xor each line with the previous
  for y in 1..<height {
    for x in 0..<width {
      bitLines[y][x] = bitLines[y - 1][x] ^ bitLines[y][x];
    }
  }
  /// Convert to rectangles
  /// TODO: combine matching rects between lines
  var rects : [QDRect] = [];
  for (l, line) in bitLines.enumerated() {
    let ranges = BitLineToRanges(line:line);
    for r in ranges {
      let topLeft = boundingBox.topLeft + QDDelta(dv: l, dh: r.lowerBound);
      let bottomRight = topLeft + QDDelta(dv : 1, dh : r.count);
      rects.append(QDRect(topLeft:topLeft, bottomRight: bottomRight));
    }
  }
  return (rects, bitLines);
}


struct QDRegion : CustomStringConvertible {
  
  public var description: String {
    return "Region \(boundingBox) \(rects.count) rects";
  }
  
  var boundingBox: QDRect = QDRect.empty;
  var isRect : Bool {
    return rects.isEmpty;
  }
  
  static func forRect(rect: QDRect) -> QDRegion {
    return QDRegion(boundingBox: rect, rects:[], bitlines:[[]]);
  }
  
  let rects : [QDRect];
  let bitlines: [[UInt8]];
}


/// Quickdraw stores RGB colours in 3 × 16 bit values.
struct QDColor : CustomStringConvertible, Hashable {
  
  public var description: String {
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
  
  /// Return classical 3 byte RGB representation.
  var rgb : [UInt8] {
    var data : [UInt8] = [];
    data.append(UInt8(red >> 8));
    data.append(UInt8(green >> 8));
    data.append(UInt8(blue >> 8));
    return data;
  }
  
  // Convert a 8 bit color value into a 16 bit one.
  static func pad16<T : BinaryInteger>(_ value: T) -> UInt16 {
    return UInt16(value & 0xff) << 8 | UInt16(value & 0xff);
  }
  
  // Constants that represent the colours of QuickDraw 1.
  static let black = QDColor(red: 0x00, green: 0x00, blue: 0x00);
  static let white = QDColor(red: 0xffff, green: 0xffff, blue: 0xffff);
  static let red = QDColor(red: 0xffff, green: 0x00, blue: 0x00);
  static let green = QDColor(red: 0x00, green: 0xffff, blue: 0x00);
  static let blue = QDColor(red: 0x00, green: 0x00, blue: 0xffff);
  static let cyan = QDColor(red: 0x00, green: 0xffff, blue: 0xffff);
  static let magenta = QDColor(red: 0xffff, green: 0x00, blue: 0xffff);
  static let yellow = QDColor(red: 0xffff, green: 0xffff, blue: 0x00);
}

/// Convert pict 1 colour into RGB Quickdraw colors.
/// These colours are basically plotter bits, with one bit per pen-colour.
/// - Parameter code: binary code representation
/// - Throws: unsupported colour error for invalid bit combinations.
/// - Returns: one of the constants defined in QDColor.
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
  case ignore = 0xFF;
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

struct QuickDrawMode : RawRepresentable {
  
  
  init(rawValue: UInt16) {
    mode = QuickDrawTransferMode(rawValue: rawValue % 8)!;
    isPattern = rawValue & QuickDrawMode.patternMask  != 0;
    isDither = rawValue & QuickDrawMode.ditherMask != 0;
  }
  var rawValue: UInt16 {
    return mode.rawValue | (isPattern ? QuickDrawMode.patternMask : 0)
      | (isDither ? QuickDrawMode.ditherMask : 0);
  }
  
  
  let mode : QuickDrawTransferMode;
  let isPattern : Bool;
  let isDither: Bool;
  
  static private let patternMask : UInt16 = 0x08;
  static private let ditherMask : UInt16 = 0x40;
  static let defaultMode : QuickDrawMode  = QuickDrawMode(rawValue: 0);
}


/// Operator  ⨴ is used for non commutative product between a structured type and a scalar or vector.
precedencegroup ComparisonPrecedence {
  associativity: left
  higherThan: AdditionPrecedence
}
infix operator ⨴ : MultiplicationPrecedence


/// Quickdraw picture resolution, in DPI.
struct QDResolution : Equatable, CustomStringConvertible {
  let hRes : FixedPoint;
  let vRes : FixedPoint;
  
  public var description: String {
    return "\(hRes)×\(vRes)";
  }
  
  /// Scale a delta as a function of the resolution, relative to the standard (72 DPI).
  /// - Parameters:
  ///   - dim: dimension to scale
  ///   - resolution: resolution description
  /// - Returns: scales dimension
  public static func ⨴ (dim : QDDelta, resolution: QDResolution) -> QDDelta {
    let h = dim.dh.value * defaultScalarResolution.value / resolution.hRes.value;
    let v = dim.dv.value * defaultScalarResolution.value / resolution.vRes.value;
    return QDDelta(dv: FixedPoint(v), dh: FixedPoint(h));
  }
  
  /// Return a rectangle scaled for a given resolution
  /// - Parameters:
  ///   - rect: rectangle to scale
  ///   - resolution: resolution to use for scaling
  /// - Returns: a scaled rectangle.
  public static func ⨴ (rect: QDRect, resolution: QDResolution) -> QDRect {
    let d = rect.dimensions ⨴ resolution;
    return QDRect(topLeft: rect.topLeft, dimension: d);
  }
  
  static let defaultScalarResolution = FixedPoint(72);
  static let defaultResolution = QDResolution(
    hRes: defaultScalarResolution, vRes: defaultScalarResolution);
  static let zeroResolution = QDResolution(hRes: FixedPoint.zero, vRes: FixedPoint.zero);
}

/// Black and white pattern (8×8 pixels)
struct QDPattern : Equatable {
  let bytes : [UInt8];

  /// Should the pattern represent a shade of color, i.e. the pattern was  used for dither.
  public var isShade : Bool {
    return [
      QDPattern.black, QDPattern.white,
      QDPattern.gray, QDPattern.darkGray,
      QDPattern.lightGray, QDPattern.batmanGray
    ].contains(where: {$0 == self} );
  }
  
  /// Scalar intensity of the pattern, going from 0 (white) to 1.0 (black).
  var intensity : Double {
    var total = 0;
    for b in bytes {
      total += b.nonzeroBitCount;
    }
    return Double(total) / (Double(UInt8.bitWidth) * Double(bytes.count));
  }
  
  func mixColors(fgColor: QDColor, bgColor: QDColor) -> QDColor {
    let fg = intensity;
    let bg = 1 - fg;
    let red = UInt16(fg * Double(fgColor.red) + bg * Double(bgColor.red));
    let green = UInt16(fg * Double(fgColor.green) + bg * Double(bgColor.green));
    let blue = UInt16(fg * Double(fgColor.blue) + bg * Double(bgColor.blue));
    return QDColor(red: red, green: green, blue: blue);
  }
  
  static let black = QDPattern(bytes:[0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);
  static let white = QDPattern(bytes:[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  static let gray = QDPattern(bytes:[0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55]);
  static let darkGray =  QDPattern(bytes:[0x88, 0x00, 0x22, 0x00, 0x88, 0x00, 0x22, 0x00]);
  static let lightGray = QDPattern(bytes:[0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77]);
  static let batmanGray = QDPattern(bytes: [0x88, 0x00, 0x22, 0x88, 0x00, 0x22]);
}

/// All the state associated with drawing
class PenState {
  var location : QDPoint = QDPoint.zero;
  var penSize: QDPoint = defaultPen;
  var mode: QuickDrawMode = QuickDrawMode.defaultMode;
  var fgColor : QDColor = QDColor.black;
  var bgColor : QDColor = QDColor.white;
  var opColor : QDColor = QDColor.black;
  var highlightColor : QDColor = QDColor(red: 0, green: 0, blue: 0xffff);
  var drawPattern: QDPattern = QDPattern.black;
  var fillPattern: QDPattern = QDPattern.black;
  var ovalSize : QDDelta = QDDelta.zero;
  
  var drawColor : QDColor {
    let result = drawPattern.mixColors(fgColor: fgColor, bgColor: bgColor);
    return result;
  }
  
  var fillColor : QDColor {
    return fillPattern.mixColors(fgColor: fgColor, bgColor: bgColor);
  }
  
  /// Pen width, assuming a square pen (height = width).
  var penWidth : FixedPoint {
    get {
      return (penSize.horizontal + penSize.vertical) >> 1;
    }
    set(width) {
      penSize = QDPoint(vertical: width, horizontal: width);
    }
  }
  
  static let defautPenWidth = FixedPoint.one;
  static let defaultPen = QDPoint(vertical: defautPenWidth, horizontal: defautPenWidth);
}

/// Text rendering options
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
    /// List of classic fonts with their canonical IDs.
    switch fontId {
    case 2: return "New York";
    case 3: return "Geneva";
    case 4: return "Monaco";
    case 5: return "Venice";
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
  var fontSize = FixedPoint(12);
  var fontMode : QuickDrawMode = QuickDrawMode.defaultMode;
  var location : QDPoint = QDPoint.zero;
  var fontStyle : QDFontStyle = QDFontStyle.defaultStyle;
  var glyphState : QDGlyphState = QDGlyphState.defaultState;
  var xRatio : FixedPoint = FixedPoint.one;
  var yRatio : FixedPoint = FixedPoint.one;
  var textCenter: QDDelta?;
  var textPictRecord : QDTextPictRecord?;
}

enum QDTextJustification : UInt8 {
  case justificationNone = 0;
  case justificationLeft = 1;
  case justificationCenter = 2;
  case justificationRight = 3;
  case justificationFull = 4;
  case justification5 = 5;  // Found in MacDraw 1
  case justification6 = 6;  // Found in MacDraw 1
}

enum QDTextFlip : UInt8 {
  case textFlipNone = 0;
  case textFlipHorizontal = 1;
  case textFlipVertical = 2;
}

// Text annotation for text comments
struct QDTextPictRecord {
  let justification : QDTextJustification;
  let flip : QDTextFlip;
  let angle : FixedPoint;
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
  var clutId : MacTypeCode = MacTypeCode.zero;
  var clutSeed : MacTypeCode = MacTypeCode.zero;
  var clut : QDColorTable?;
}

// Abstract view of a bitmap information
protocol PixMapMetadata {
  var rowBytes : Int {get};
  var cmpSize : Int {get};
  var pixelSize : Int {get};
  var dimensions : QDDelta {get};
}

class QDBitMapInfo : CustomStringConvertible, PixMapMetadata {
  
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
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
  var data : [UInt8] = [UInt8]();
  var pixMapInfo : QDPixMapInfo?;
  
  var destinationRect : QDRect {
    return dstRect!;
  }
  
  var dimensions: QDDelta {
    return bounds.dimensions;
  }
  
  var height : Int {
    return bounds.dimensions.dv.rounded;
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

let clut8Raw : [UInt32] = [0x000000,0x0b0b0b,0x222222,0x444444,0x555555,0x777777,0x888888,0xaaaaaa,0xbbbbbb,0xdddddd,0xeeeeee,0x00000b,0x000022,0x000044,0x000055,0x000077,0x000088,0x0000aa,0x0000bb,0x0000dd,0x0000ee,0x000b00,0x002200,0x004400,0x005500,0x007700,0x008800,0x00aa00,0x00bb00,0x00dd00,0x00ee00,0x0b0000,0x220000,0x440000,0x550000,0x770000,0x880000,0xaa0000,0xbb0000,0xdd0000,0xee0000,0x000033,0x000066,0x000099,0x0000cc,0x0000ff,0x003300,0x003333,0x003366,0x003399,0x0033cc,0x0033ff,0x006600,0x006633,0x006666,0x006699,0x0066cc,0x0066ff,0x009900,0x009933,0x009966,0x009999,0x0099cc,0x0099ff,0x00cc00,0x00cc33,0x00cc66,0x00cc99,0x00cccc,0x00ccff,0x00ff00,0x00ff33,0x00ff66,0x00ff99,0x00ffcc,0x00ffff,0x330000,0x330033,0x330066,0x330099,0x3300cc,0x3300ff,0x333300,0x333333,0x333366,0x333399,0x3333cc,0x3333ff,0x336600,0x336633,0x336666,0x336699,0x3366cc,0x3366ff,0x339900,0x339933,0x339966,0x339999,0x3399cc,0x3399ff,0x33cc00,0x33cc33,0x33cc66,0x33cc99,0x33cccc,0x33ccff,0x33ff00,0x33ff33,0x33ff66,0x33ff99,0x33ffcc,0x33ffff,0x660000,0x660033,0x660066,0x660099,0x6600cc,0x6600ff,0x663300,0x663333,0x663366,0x663399,0x6633cc,0x6633ff,0x666600,0x666633,0x666666,0x666699,0x6666cc,0x6666ff,0x669900,0x669933,0x669966,0x669999,0x6699cc,0x6699ff,0x66cc00,0x66cc33,0x66cc66,0x66cc99,0x66cccc,0x66ccff,0x66ff00,0x66ff33,0x66ff66,0x66ff99,0x66ffcc,0x66ffff,0x990000,0x990033,0x990066,0x990099,0x9900cc,0x9900ff,0x993300,0x993333,0x993366,0x993399,0x9933cc,0x9933ff,0x996600,0x996633,0x996666,0x996699,0x9966cc,0x9966ff,0x999900,0x999933,0x999966,0x999999,0x9999cc,0x9999ff,0x99cc00,0x99cc33,0x99cc66,0x99cc99,0x99cccc,0x99ccff,0x99ff00,0x99ff33,0x99ff66,0x99ff99,0x99ffcc,0x99ffff,0xcc0000,0xcc0033,0xcc0066,0xcc0099,0xcc00cc,0xcc00ff,0xcc3300,0xcc3333,0xcc3366,0xcc3399,0xcc33cc,0xcc33ff,0xcc6600,0xcc6633,0xcc6666,0xcc6699,0xcc66cc,0xcc66ff,0xcc9900,0xcc9933,0xcc9966,0xcc9999,0xcc99cc,0xcc99ff,0xcccc00,0xcccc33,0xcccc66,0xcccc99,0xcccccc,0xccccff,0xccff00,0xccff33,0xccff66,0xccff99,0xccffcc,0xccffff,0xff0000,0xff0033,0xff0066,0xff0099,0xff00cc,0xff00ff,0xff3300,0xff3333,0xff3366,0xff3399,0xff33cc,0xff33ff,0xff6600,0xff6633,0xff6666,0xff6699,0xff66cc,0xff66ff,0xff9900,0xff9933,0xff9966,0xff9999,0xff99cc,0xff99ff,0xffcc00,0xffcc33,0xffcc66,0xffcc99,0xffcccc,0xffccff,0xffff00,0xffff33,0xffff66,0xffff99,0xffffcc,0xffffff];

class QDColorTable : CustomStringConvertible {
  public var description: String {
    let string_flag = String(format: "%0X ", clutFlags);
    var result = "flags: \(string_flag) "
    result += "size \(clut.count)";
    return result;
  }
  
  init(clutFlags: UInt16) {
    self.clutFlags = clutFlags;
  }
  
  init(clut : [QDColor]) {
    self.clutFlags = 0;
    self.clut = clut;
  }
  
  init(raw: [UInt32], id: Int) {
    self.id = id;
    self.clutFlags = 0;
    for v in raw {
      let r = QDColor.pad16(v >> 16)
      let g = QDColor.pad16(v >> 8);
      let b = QDColor.pad16(v);
      let color = QDColor(red: r, green: g, blue: b);
      clut.append(color)
    }
  }
  
  let clutFlags : UInt16;
  var clut : [QDColor] = [];
  var id : Int = 0;
  
  static let blackWhite : QDColorTable = QDColorTable(clut:[QDColor.black, QDColor.white]);
  
  static func forClutId(clutId: Int) -> QDColorTable? {
    if (clutId == 8) {
      return QDColorTable(raw: clut8Raw.reversed(), id: 8);
    }
    return nil;
  }
}



public class QDPicture : CustomStringConvertible {
  init(size: Int, frame:QDRect, filename: String?) {
    self.size = size;
    self.frame = frame;
    self.filename = filename;
  }
  
  let size: Int;
  var frame: QDRect;
  var resolution : QDResolution = QDResolution.defaultResolution;
  var version: Int = 1;
  var opcodes: [OpCode] = [];
  var filename : String?;
  
  public var description : String {
    var result = "Picture size: \(size) bytes, version: \(version) ";
    if let name = filename {
      result += "filename: \(name) ";
    }
    result += "frame: \(frame) @ \(resolution)\n";
    result += "===========================\n";
    for (index, opcode) in opcodes.enumerated() {
      result += "\(index): \(opcode)\n";
    }
    result += "===========================\n";
    return result;
  }
}


