//
//  QuickDrawOpcodes.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 21.11.2023.
//

import Foundation

/// -------
/// Protocols
/// -------

/// Minimal interface: be able to load.
protocol OpCode {
  mutating func load(reader: QuickDrawDataReader) throws -> Void
}

/// opcodes that affect the pen-state can be execute independently of the target graphic system.
protocol PenStateOperation {
  func execute(penState : inout PenState) -> Void;
}

/// opcodes that affect the picture meta-data, typically execute at load time.
protocol PictureOperation {
  func execute(picture : inout QDPicture) -> Void;
}

/// opcodes that affect the font state (size, font-name, etc).
protocol FontStateOperation {
  func execute(fontState : inout QDFontState) -> Void;
}

/// -----------------
/// Simple control opcodes
/// -----------------

struct NoOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws -> Void {}
}

struct EndOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    let leftBytes = reader.data.count - reader.position;
    print("EndOp: \(leftBytes)");
  }
}

struct ReservedOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    length = Data.Index(try reader.readUInt32());
    reader.skip(bytes: length)
  }
  
  var length : Data.Index = 0;
}


struct DefHiliteOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws -> Void {}
}


struct VersionOp : OpCode, PictureOperation {
  func execute(picture: inout QDPicture) {
    picture.version = version;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws -> Void {
    version = try reader.readUInt8();
    if version == 2 {
      _ = try reader.readUInt8();
    }
  }
  var version: UInt8 = 0;
}

struct Version2HeaderOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws -> Void {
    reader.skip(bytes: 24);
  }
}

struct OriginOp : OpCode {
  
  mutating func load(reader: QuickDrawDataReader) throws -> Void {
    let dh = try reader.readInt16();
    let dv = try reader.readInt16();
    delta = QDDelta(dv: dv, dh: dh);
  }
  var delta : QDDelta = QDDelta.zero;
}

/// ---------------------
/// Shape opcodes
/// ---------------------

struct RegionOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    try region = reader.readRegion();
  }
  
  let same : Bool;
  let verb : QDVerb
  var region: QDRegion?;
}

struct RectOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    if !same {
      rect = try reader.readRect();
    }
  }
  
  let same: Bool;
  let verb: QDVerb;
  var rect: QDRect?;
}

struct OvalOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    if !same {
      rect = try reader.readRect();
    }
  }
  
  let same: Bool;
  let verb: QDVerb;
  var rect: QDRect?;
}

struct RoundRectOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    if !same {
      rect = try reader.readRect();
    }
  }
  
  let same: Bool;
  let verb: QDVerb;
  var rect: QDRect?;
}

struct OvalSizeOp : OpCode, PenStateOperation {
  func execute(penState: inout PenState) {
    penState.ovalSize = size;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    size = try reader.readDelta();
  }
  
  var size : QDDelta = QDDelta.zero;
}


///**Inside Macintosh** “Imaging with quickdraw” p 3-73
/// Use the startAngle parameter to specify where the arc begins as modulo 360.
/// Use the arcAngle parameter to specify how many degrees the arc covers.
/// Specify whether the angles are in positive or negative degrees; a positive angle goes clockwise,
/// while a negative angle goes counterclockwise. Zero degrees is at 12 o’clock high,
/// 90° (or –270°) is at 3 o’clock, 180° (or –180°) is at 6 o’clock, and 270° (or –90°) is at 9 o’clock.
/// Measure other angles relative to the bounding rectangle.
/// A line from the center of the rectangle through its upper-right corner is at 45°,
/// even if the rectangle isn’t square; a line through the lower-right corner is at 135°,
/// and so on, as shown in Figure 3-20.
struct ArcOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    if !same {
      rect = try reader.readRect();
    }
    startAngle = try reader.readInt16();
    angle = try reader.readInt16();
  }
  
  let same: Bool;
  let verb: QDVerb;
  var rect: QDRect?;
  var startAngle: Int16 = 0;
  var angle: Int16 = 0;
}

struct PolygonOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    poly = try reader.readPoly();
  }
  
  func GetPolygon(last : QDPolygon?) -> QDPolygon {
    return self.poly ?? last!;
  }
  
  let same: Bool;
  let verb: QDVerb;
  var poly: QDPolygon?;
}

/// ------------
/// Line operations
/// ------------

struct LineOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    if !from {
      start = try reader.readPoint();
    }
    if short {
      let dh = try reader.readInt8();
      let dv = try reader.readInt8();
      delta = QDDelta(dv: dv, dh:dh);
    } else {
      end = try reader.readPoint();
    }
  }
  
  // Get the set of points for the line (2).
  // current is required for `from` operations. 
  func getPoints(current : QDPoint?) -> [QDPoint] {
    var points : [QDPoint] = [];
    let p1 = (start ?? current)!;
    points.append(p1);
    let p2 = end ?? p1 + delta!;
    points.append(p2);
    return points;
  }
  
  let short : Bool;
  let from : Bool;
  var start : QDPoint?;
  var end : QDPoint?;
  var delta : QDDelta?;
}

/// ----------------
/// Comment operations
/// ----------------

enum CommentType : UInt16 {
  case groupBegin = 0;
  case groupEnd = 1;
  case proprietary = 100;
  case macDrawBegin = 130;
  case macDrawEnd = 131;
  case groupedBegin = 140 ;
  case groupedEnd = 141 ;
  case bitmapBegin = 142 ;
  case bitmapEnd = 143 ;
  case textBegin   = 150;
  case textEnd   = 151;
  case stringBegin = 152 ;
  case stringEnd   = 153;
  case textCenter  = 154;
  case lineLayoutOff = 155;
  case lineLayoutOn = 156;
  case lineLayoutClient = 157;
  case polyStart   = 160;
  case polyEnd   = 161;
  case polyCurve   = 162;
  case polyIgnore  = 163;
  case polySmooth  = 164;
  case polyClose   = 165;
  case arrow1 = 170 ;
  case arrow2 = 171 ;
  case arrow3 = 172 ;
  case arrowEnd = 173;
  case postscriptStart = 190 ;
  case postscriptEnd = 191 ;
  case postscriptHandle = 192 ;
  case postscriptFile = 193 ;
  case textIsPostscript = 194 ;
  case resourcePostscript = 195;
  case postscriptBeginNoSave = 196;
  case setGrayLevel = 197;
  case rotateBegin = 200;
  case rotateEnd   = 201;
  case rotateCenter = 202;
  case creator = 498 ;
  case picLasso = 12345;
}

struct CommentOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    let value = try reader.readUInt16();
    kind = CommentType(rawValue: value);
    if long_comment {
      let size = Data.Index(try reader.readUInt16());
      switch kind {
      case .proprietary:
        creator = try reader.readString(bytes: 4);
        data = try reader.readUInt8(bytes: size - 4);
      case .postscriptBeginNoSave, .postscriptStart, .postscriptFile, .postscriptHandle:
        postscript = try reader.readString(bytes: size);
      default:
        data = try reader.readUInt8(bytes :size);
      }
    }
  }
  
  let long_comment : Bool;
  var kind : CommentType?;
  var creator : String?;
  var data : [UInt8]?;
  var postscript : String?;
}

/// -------------
/// Color operations
/// -------------

struct ColorOp : OpCode, PenStateOperation {
  func execute(penState: inout PenState) {
    switch selection {
    case QDColorSelection.foreground: penState.fgColor = color;
    case QDColorSelection.background: penState.bgColor = color;
    case QDColorSelection.operations: penState.opColor = color;
    case QDColorSelection.highlight: penState.highlightColor = color;
    }
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    if rgb {
      color = try reader.readColor();
    } else {
      let code = try reader.readUInt32();
      color = try QD1Color(code: code);
    }
  }
  
  let rgb : Bool;
  let selection : QDColorSelection;
  var color : QDColor = QDColor.white;
}


// Pen operations

struct PatternOp : OpCode, PenStateOperation  {
  func execute(penState: inout PenState) {
    switch verb {
    case .fill, .paint:
      penState.fillPattern = pattern;
    case .frame:
      penState.drawPattern = pattern;
    default:
      print("Unsupported pattern verb in \(self)");
    }
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    pattern = QDPattern(bytes:try reader.readUInt8(bytes: 8));
  }
  
  let verb : QDVerb;
  var pattern : QDPattern = QDPattern.full;
}

struct PenSizeOp : OpCode, PenStateOperation {
  func execute(penState: inout PenState) {
    penState.size = penSize;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    penSize = try reader.readPoint();
  }
  
  var penSize : QDPoint = QDPoint(vertical: 1, horizontal: 1);
}

struct PenModeOp : OpCode, PenStateOperation {
  func execute(penState: inout PenState) {
    penState.mode = mode;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    mode = QuickDrawMode(value: try reader.readUInt16());
  }
  
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
}

struct TextModeOp : OpCode, FontStateOperation {
  
  func execute(fontState: inout QDFontState) {
    fontState.fontMode = mode;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    mode = QuickDrawMode(value: try reader.readUInt16());
  }
  
  
  
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
}

/// --------------------------------------------------------
/// Font operations
/// --------------------------------------------------------



struct FontOp : OpCode, FontStateOperation {
  func execute(fontState: inout QDFontState) {
    if fontName != nil {
      fontState.fontName = fontName!;
    }
    if fontId != nil {
      fontState.fontId = fontId!;
    }
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    if longOp {
      let _ = try reader.readUInt16();
      fontId = Int(try reader.readUInt16());
      fontName = try reader.readPascalString();
    } else {
      fontId = Int(try reader.readUInt16());
    }
  }

  let longOp: Bool;
  var fontId: Int?;
  var fontName: String?;
}


struct FontSizeOp : OpCode, FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.fontSize = textSize;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    textSize = Int(try reader.readUInt16());
  }
  
  var textSize : Int = 0;
}

struct GlyphStateOp : OpCode, FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.glyphState = glyphState;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    let len = Data.Index(try reader.readUInt16());
    guard len >= 4 else {
      throw QuickDrawError.corruptPayload(message: "GlyphState too short: \(len)");
    }
    if try reader.readBool() {
      glyphState.insert(.outlinePreferred);
    }
    if try reader.readBool() {
      glyphState.insert(.preserveGlyphs);
    }
    if try reader.readBool() {
      glyphState.insert(.fractionalWidths);
    }
    if try reader.readBool() {
      glyphState.insert(.scalingDisabled);
    }
    reader.skip(bytes: len - 4);
  }
  
  var glyphState : QDGlyphState = QDGlyphState.defaultState;
}

struct TextRatioOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    numerator = try reader.readPoint();
    denominator = try reader.readPoint();
  }
  
  var numerator : QDPoint?;
  var denominator :QDPoint?;
}

struct FontStyleOp : OpCode, FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.fontStyle = fontStyle;
  }
  
  init() {
    fontStyle = QDFontStyle(rawValue:0);
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    fontStyle = QDFontStyle(rawValue: try reader.readUInt8());
  }
  
  var fontStyle : QDFontStyle;
}

struct DHDVTextOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    var dv = 0;
    var dh = 0;
    if readDh {
      dh = Int(try reader.readUInt8());
    }
    if readDv {
      dv = Int(try reader.readUInt8());
    }
    delta = QDDelta(dv:dv, dh:dh);
    text = try reader.readPascalString();
  }
  
  let readDh : Bool;
  let readDv : Bool;
  var delta : QDDelta = QDDelta.zero;

  var text : String = "";
  
}

struct LongTextOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    position = try reader.readPoint();
    text = try reader.readPascalString();
  }
  
  var position : QDPoint = QDPoint.zero;
  var text : String = "";
  
}

/// ---------------
/// Bitmap op-codes
/// ---------------

func readPixMapInfo(reader: QuickDrawDataReader) throws -> QDPixMapInfo {
  let pixMapInfo = QDPixMapInfo();
  pixMapInfo.version = Int(try reader.readUInt16());
  pixMapInfo.packType = QDPackType(rawValue:try reader.readUInt16())!;
  pixMapInfo.packSize = Int(try reader.readUInt32());
  let h_res = try reader.readFixed();
  let v_res = try reader.readFixed();
  pixMapInfo.resolution = QDResolution(hRes: h_res, vRes: v_res);
  pixMapInfo.pixelType = Int(try reader.readUInt16());
  pixMapInfo.pixelSize = Int(try reader.readUInt16());
  pixMapInfo.cmpCount = Int(try reader.readUInt16());
  pixMapInfo.cmpSize = Int(try reader.readUInt16());
  pixMapInfo.planeByte = Int64(try reader.readUInt32());
  pixMapInfo.clutId = try reader.readType();
  pixMapInfo.clutSeed = try reader.readType();
  return pixMapInfo;
}

struct BitRectOpcode : OpCode {
  init(isPacked : Bool) {
    self.bitmapInfo = QDBitMapInfo(isPacked: isPacked);
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    var masked = try reader.readUInt16();
    if masked & 0x8000 != 0 {
      isPixMap = true;
      masked = masked ^ 0x8000;
    }
    bitmapInfo.rowBytes = Int(masked);
    bitmapInfo.bounds = try reader.readRect();
    if isPixMap {
      let pixMapInfo = try readPixMapInfo(reader:reader);
      reader.skip(bytes: 4);
      let clutFlags = try reader.readUInt16();
      let colorTable = QDColorTable(clutFlags: clutFlags);
      let clutSize = try reader.readUInt16();
      for index in 0...clutSize {
        let r_index = try reader.readUInt16();
        if r_index != index {
          print("Inconsistent index: \(r_index)≠\(index)");
          /* throw QuickDrawError.corruptColorTableError(
            message: "Inconsistent index: \(r_index)≠\(index)");*/
        }
        let color = try reader.readColor();
        colorTable.clut.append(color)
      }
      pixMapInfo.clut = colorTable;
      bitmapInfo.pixMapInfo = pixMapInfo;
    }
    
    bitmapInfo.srcRect = try reader.readRect();
    bitmapInfo.dstRect = try reader.readRect();
    bitmapInfo.mode = try QuickDrawMode(value: reader.readUInt16());
    
    let rows = bitmapInfo.bounds.dimensions.dv.intValue;
    for row in 0 ..< rows {
      if !bitmapInfo.isPacked {
        let line_data = try reader.readUInt8(bytes: Data.Index(bitmapInfo.rowBytes));
        bitmapInfo.data.append(contentsOf: line_data);
        continue;
      }
      var lineLength : Data.Index;
      if bitmapInfo.hasShortRows {
        lineLength = Data.Index(try reader.readUInt8());
      } else {
        lineLength = Data.Index(try reader.readUInt16());
      }
      let rowData = try reader.readUInt8(bytes: lineLength);
      let decompressed = DecompressPackBit(data: rowData);
      guard bitmapInfo.rowBytes == decompressed.count else {
        throw QuickDrawError.corruptPackbitLine(
          row: row,
          expectedLength:  Data.Index(bitmapInfo.rowBytes),
          actualLength:  Data.Index(decompressed.count))
      }
      bitmapInfo.data.append(contentsOf: decompressed);
    }
  }
  
  var isPixMap : Bool = false;
  var bitmapInfo : QDBitMapInfo;
}

struct DirectBitOpcode : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    reader.skip(bytes: 4);  // Base address
    var masked = try reader.readUInt16();
    if masked & 0x8000 != 0 {
      masked = masked ^ 0x8000;
    }
    bitmapInfo.rowBytes = Int(masked);
    bitmapInfo.bounds = try reader.readRect();
    bitmapInfo.pixMapInfo = try readPixMapInfo(reader:reader);
    bitmapInfo.srcRect = try reader.readRect();
    bitmapInfo.dstRect = try reader.readRect();
    bitmapInfo.mode = try QuickDrawMode(value: reader.readUInt16());
    switch bitmapInfo.pixMapInfo!.packType {
    case .noPack, .defaultPack:
      try loadUnpacked(reader:reader);
    case .removePadByte:
      try loadRemovePad(reader: reader);
    case .pixelRunLength:
      try loadPixelRunLength(reader: reader);
    case .componentRunLength:
      try loadComponentRunLength(reader: reader);
    }
  }
  
  /// Pack 1
  mutating func loadUnpacked(reader: QuickDrawDataReader) throws {
    let rows = bitmapInfo.height;
    let rowBytes = bitmapInfo.rowBytes;
    let byteNum = rows * rowBytes;
    data = try reader.readUInt8(bytes: byteNum);
  }
  
  /// Pack 2
  /// This is basically 24-bits RGB, Quickdraw would actually pad this to 32 bits.
  /// We just load it as 24-bits and update rowBytes to reflect this. 
  mutating func loadRemovePad(reader: QuickDrawDataReader) throws {
    let rows = bitmapInfo.height;
    let rowBytes = bitmapInfo.rowBytes * 3 / 4;
    let byteNum = rows * rowBytes;
    bitmapInfo.rowBytes = rowBytes;
    data = try reader.readUInt8(bytes: byteNum);
  }
  
  /// Pack 3
  /// Packbit algorithm on 16 bit quantities.
  ///
  mutating func loadPixelRunLength(reader: QuickDrawDataReader) throws {
    let rows = bitmapInfo.height;
    for row in 0..<rows {
      var lineLength : Data.Index;
      if bitmapInfo.hasShortRows {
        lineLength = Data.Index(try reader.readUInt8());
      } else {
        lineLength = Data.Index(try reader.readUInt16());
      }
      let line_data = try reader.readUInt8(bytes: lineLength);
      let decompressed = DecompressPackBit(data: line_data, byteNum: 2);
      guard bitmapInfo.rowBytes == decompressed.count else {
        throw QuickDrawError.corruptPackbitLine(
          row: row,
          expectedLength: Data.Index(bitmapInfo.rowBytes),
          actualLength: Data.Index(decompressed.count))
      }
      bitmapInfo.data.append(contentsOf: decompressed);
    }
  }
  
  /// Pack 4
  /// Packbit algorithm on 8 bit quantities, for each row, first the red values, then the green, blue.
  mutating func loadComponentRunLength(reader: QuickDrawDataReader) throws {
    let rows = bitmapInfo.height;
    guard bitmapInfo.pixMapInfo?.cmpCount == 3 else {
      throw QuickDrawError.wrongComponentNumber(componentNumber: bitmapInfo.cmpSize);
    }
    
    let rowBytes = bitmapInfo.rowBytes * 3 / 4;
    for row in 0..<rows {
      var lineLength : Data.Index;
      if bitmapInfo.hasShortRows {
        lineLength = Data.Index(try reader.readUInt8());
      } else {
        lineLength = Data.Index(try reader.readUInt16());
      }
      let line_data = try reader.readUInt8(bytes: lineLength);
      let decompressed = DecompressPackBit(data: line_data, byteNum: 1);
      guard rowBytes == decompressed.count else {
        throw QuickDrawError.corruptPackbitLine(
          row: row,
          expectedLength: Data.Index(bitmapInfo.rowBytes),
          actualLength: Data.Index(decompressed.count))
      }
      let w = decompressed.count  / 3;
      for i in 0..<w  {
        bitmapInfo.data.append(decompressed[i]);
        bitmapInfo.data.append(decompressed[i + w]);
        bitmapInfo.data.append(decompressed[i + (2 * w)]);
      }
      
    }
    /// Update the pixel information to reflect reality. There is no alpha. 
    bitmapInfo.rowBytes = rowBytes ;
    bitmapInfo.pixMapInfo?.pixelSize = 24;
  }
  
  var bitmapInfo : QDBitMapInfo = QDBitMapInfo(isPacked: false);
  var data : [UInt8] = [];
  
}

struct QuickTimeOpcode : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    quicktimePayload.size = Int(try reader.readInt32());
    reader.skip(bytes: 18);
    quicktimePayload.version = Int(try reader.readUInt16());
    quicktimePayload.revision = Int(try reader.readUInt16());
    reader.skip(bytes: 30);
    // 34 bytes to dimensions
    /*
    quicktimePayload.compressorVendor = try reader.readUInt32(); // 4
    quicktimePayload.temporalQuality = try reader.readUInt16(); // 2
    quicktimePayload.spatialQuality = try reader.readUInt16(); // 2
     
     let width = Int(try reader.readInt16());
     let height = Int(try reader.readInt16());
     quicktimePayload.dimensions = QDPoint(vertical: height, horizontal: width);
     */
    quicktimePayload.dstRect = try reader.readRect();
    reader.skip(bytes: 12);
    quicktimePayload.payloadType = try reader.readType();
    reader.skip(bytes :12);
    quicktimePayload.compressorDevelopper = try reader.readType();
    quicktimePayload.temporalQuality = try reader.readUInt32();  // 4
    quicktimePayload.spatialQuality = try reader.readUInt32(); // 4
    quicktimePayload.dimensions = try reader.readDelta();  // 4
    let hRes = try reader.readFixed();
    let vRes = try reader.readFixed();
    quicktimePayload.resolution = QDResolution(hRes: hRes, vRes: vRes);
    quicktimePayload.dataSize = Int(try reader.readInt32());
    quicktimePayload.frameNumber = Int(try reader.readInt16());
    quicktimePayload.name = try reader.readStr31();
    quicktimePayload.depth = Int(try reader.readInt16());
    quicktimePayload.clutId = Int(try reader.readInt16());
    let tailSize = quicktimePayload.size - quicktimePayload.dataSize - 154
    print("\(tailSize)");
    quicktimePayload.data = try reader.readData(bytes: quicktimePayload.dataSize);
    // reader.skip(bytes: 128);
  }
  
  var quicktimePayload : QuickTimePayload = QuickTimePayload();
}
