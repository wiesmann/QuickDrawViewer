//
//  QuickDrawTypes.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 21.11.2023.
//

import Foundation

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
    self.closed = false;
    self.smooth = false;
  }
  
  convenience init() {
    self.init(boundingBox: nil, points: []);
  }
  
  var boundingBox : QDRect?;
  var points : [QDPoint];
  var closed : Bool;
  var smooth : Bool;
  
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
    let result = drawPattern.blendColors(fgColor: fgColor, bgColor: bgColor);
    return result;
  }
  
  var fillColor : QDColor {
    return fillPattern.blendColors(fgColor: fgColor, bgColor: bgColor);
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
    result += "clut Id: \(clutId) ";
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
  var clutId : Int32 = 0;
  var clutSeed : MacTypeCode = MacTypeCode.zero;
  var clut : QDColorTable?;
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
  
  var clut : QDColorTable? {
    if let pix_info = pixMapInfo {
      return pix_info.clut!;
    }
    return QDColorTable.palette1;
  }
  
  public var description : String {
    let pm = describePixMap(self);
    var result = "Bitmap info [\(pm) packed: \(isPacked) ";
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

public class QDPicture : CustomStringConvertible {
  init(size: Int, frame:QDRect, filename: String?) {
    self.size = size;
    self.frame = frame;
    self.filename = filename;
    self.srcRect = frame;
  }
  
  let size: Int;
  var srcRect : QDRect;
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
    result += "frame: \(frame) src: \(srcRect) @ \(resolution)\n";
    result += "===========================\n";
    for (index, opcode) in opcodes.enumerated() {
      result += "\(index): \(opcode)\n";
    }
    result += "===========================\n";
    return result;
  }
}


