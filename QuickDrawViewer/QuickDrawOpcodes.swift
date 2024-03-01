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

struct NoOp : OpCode, PictureOperation {
  func execute(picture: inout QDPicture) {}
  
  mutating func load(reader: QuickDrawDataReader) throws {}
}

struct EndOp : OpCode, PictureOperation {
  func execute(picture: inout QDPicture) {}
  
  mutating func load(reader: QuickDrawDataReader) throws {}
}

enum ReservedOpType {
  case fixedLength(bytes: Int);
  case readLength(bytes: Int);
}

struct ReservedOp : OpCode, PictureOperation {
  func execute(picture: inout QDPicture) {}
  
  mutating func load(reader: QuickDrawDataReader) throws {
    switch reservedType {
    case let .fixedLength(bytes):
      length = bytes;
    case let .readLength(bytes) where bytes == 4:
      length = Data.Index(try reader.readUInt32());
    case let .readLength(bytes) where bytes == 2:
      length = Data.Index(try reader.readUInt16());
    case let .readLength(bytes) where bytes == 1:
      length = Data.Index(try reader.readUInt8());
    default:
      throw QuickDrawError.invalidReservedSize(reservedType: reservedType);
    }
    reader.skip(bytes: length)
  }
  
  let reservedType : ReservedOpType ;
  var length : Data.Index = 0;
}


struct DefHiliteOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws -> Void {}
}


struct VersionOp : OpCode, PictureOperation {
  func execute(picture: inout QDPicture) {
    picture.version = Int(version);
  }
  
  mutating func load(reader: QuickDrawDataReader) throws -> Void {
    version = try reader.readUInt8();
    if version == 2 {
      _ = try reader.readUInt8();
    }
  }
  var version: UInt8 = 0;
}

struct Version2HeaderOp : OpCode, PictureOperation {
  mutating func load(reader: QuickDrawDataReader) throws -> Void {
    reader.skip(bytes: 4);
    resolution = try reader.readResolution();
    srcRect = try reader.readRect();
    reader.skip(bytes: 4);
    // reader.skip(bytes: 24);
  }
  
  func execute(picture: inout QDPicture) {
    if resolution != QDResolution.zeroResolution {
      picture.resolution = resolution;
    }
  }
  
  var resolution : QDResolution = QDResolution.defaultResolution;
  var srcRect : QDRect = QDRect.empty;
  
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

enum LineDestination {
  case unset;
  case relative(delta: QDDelta);
  case absolute(point: QDPoint);
}

struct LineOp : OpCode, CustomStringConvertible {
  
  mutating func load(reader: QuickDrawDataReader) throws {
    if !from {
      start = try reader.readPoint();
    }
    if short {
      let dh = try reader.readInt8();
      let dv = try reader.readInt8();
      end = .relative(delta: QDDelta(dv: dv, dh:dh))
    } else {
      end = .absolute(point: try reader.readPoint());
    }
  }
  
  // Get the set of points for the line (2).
  // current is required for `from` operations.
  func getPoints(current : QDPoint?) -> [QDPoint] {
    let p1 = (start ?? current)!;
    var points : [QDPoint] = [p1];
    switch end {
    case .absolute(let point):
      points.append(point);
    case .relative(let delta):
      points.append(p1 + delta);
    case .unset:
      break;
    }
    return points;
  }
  
  public var description: String {
    var result = "Line ";
    if let s = start {
      result += "\(s)"
    }
    switch end {
    case .absolute(let point):
      result += "→ \(point)";
    case .relative(let delta):
      result += "→ \(delta)";
    case .unset:
      break;
    }
    return result;
  }
  
  
  let short : Bool;
  let from : Bool;
  var start : QDPoint?;
  var end : LineDestination = .unset;
}

/// ----------------
/// Comment operations
/// ----------------

enum CommentType : UInt16, CaseIterable {
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
  case polyBegin   = 160;
  case polyEnd   = 161;
  case polyCurve   = 162;
  case polyIgnore  = 163;
  case polySmooth  = 164;
  case polyClose   = 165;
  case arrow1 = 170 ;
  case arrow2 = 171 ;
  case arrow3 = 172 ;
  case arrowEnd = 173;
  case dashedLineBegin = 180;
  case dashedLineEnd = 181;
  case setLineWidth = 182;
  case postscriptStart = 190 ;
  case postscriptEnd = 191 ;
  case postscriptHandle = 192 ;
  case postscriptFile = 193 ;
  case textIsPostscript = 194 ;
  case resourcePostscript = 195;
  case postscriptBeginNoSave = 196 ;
  case setGrayLevel = 197;
  case rotateBegin = 200;
  case rotateEnd   = 201;
  case rotateCenter = 202;
  case formsPrinting = 210;
  case endFormsPrinting = 211;
  case creator = 498 ;
  case scale = 499;
  case bitmapThinBegin = 1000;
  case bitmapThinEnd = 1001;
  case picLasso = 12345;
  case unknown = 0xffff;
}

/// Define pen and font comment  payloads as operations, so they can be executed like opcodes.
/// This allows some generic processing on the renderer code.

struct LineWidthPayload : PenStateOperation {
  func execute(penState: inout PenState) {
    penState.penWidth = width;
  }
  let width: FixedPoint;
}

struct TextCenterPayload : FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.textCenter = center;
  }
  let center : QDDelta;
}

struct TextPictPayload : FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.textPictRecord = textPictRecord;
  }
  let textPictRecord : QDTextPictRecord;
}

enum CommentPayload {
  case noPayload;
  case dataPayload(creator: String, data: Data);
  case postScriptPayLoad(postscript: String);
  case fontStatePayload(fontOperation: FontStateOperation);
  case penStatePayload(penOperation: PenStateOperation);
  case unknownPayload(rawType: Int, data: Data);
}

func readTextPictRecord(reader: QuickDrawDataReader) throws -> QDTextPictRecord {
  let raw_justification = try reader.readUInt8();
  guard let justification = QDTextJustification(rawValue: raw_justification) else {
    throw QuickDrawError.quickDrawIoError(message: "Could not parse justification value \(raw_justification)");
  }
  let raw_flip = try reader.readUInt8();
  guard let flip = QDTextFlip(rawValue: raw_flip) else {
    throw QuickDrawError.quickDrawIoError(message: "Could not parse flip value \(raw_flip)");
  }
  let angle1 = FixedPoint(try reader.readInt16());
  reader.skip(bytes: 2);
  // MacDraw 1 comments are shorter
  if reader.remaining < 4 {
    return QDTextPictRecord(justification: justification, flip: flip, angle: angle1);
  }
  let angle2 = try reader.readFixed();
  let angle = angle2 + angle1
  return QDTextPictRecord(justification: justification, flip: flip, angle: angle);
}

struct CommentOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    let value = try reader.readUInt16();
    kind = CommentType(rawValue: value) ?? .unknown;
    let size = long_comment ? Data.Index(try reader.readUInt16()) : Data.Index(0);
    switch (kind, size) {
    case (.proprietary, let size) where size > 4:
      payload = .dataPayload(creator: try reader.readString(bytes: 4), data: try reader.readData(bytes: size - 4));
    case (.postscriptBeginNoSave, _),
      (.postscriptStart, _),
      (.postscriptFile, _),
      (.postscriptHandle, _):
      payload = .postScriptPayLoad(postscript : try reader.readString(bytes: size));
    case (.textBegin, let size) where size > 0:
      let subreader = try reader.subReader(bytes: size);
      let fontOp =  TextPictPayload(textPictRecord: try readTextPictRecord(reader: subreader));
      payload = .fontStatePayload(fontOperation: fontOp);
    case (.setLineWidth, let size) where size > 0:
      let subreader = try reader.subReader(bytes: size);
      let point = try subreader.readPoint();
      let penOp = LineWidthPayload(width: point.vertical / point.horizontal);
      payload = .penStatePayload(penOperation: penOp);
    case (.textCenter, let size) where size > 0:
      let subreader = try reader.subReader(bytes: size);
      // readDelta assumes integer, here we want to read fixed points.
      let v = try subreader.readFixed();
      let h = try subreader.readFixed();
      let fontOp = TextCenterPayload(center: QDDelta(dv: v, dh: h));
      payload = .fontStatePayload(fontOperation: fontOp);
    case (_, 0):
      payload = .noPayload;
    case (.unknown, let size) where size > 0:
      payload = .unknownPayload(rawType: Int(value), data: try reader.readData(bytes: size));
    case (_, let size) where size > 0:
      payload = .dataPayload(creator: "APPL", data: try reader.readData(bytes: size));
    default:
      payload = .unknownPayload(rawType: Int(value), data: try reader.readData(bytes: size));
    }
  }
  
  let long_comment : Bool;
  var kind : CommentType = .unknown;
  var payload : CommentPayload = CommentPayload.noPayload;
}

/// -------------
/// Color operations
/// -------------

struct ColorOp : OpCode, PenStateOperation {
  
  mutating func load(reader: QuickDrawDataReader) throws {
    if rgb {
      color = try reader.readColor();
    } else {
      let code = try reader.readUInt32();
      color = try QD1Color(code: code);
    }
  }
  
  func execute(penState: inout PenState) {
    switch selection {
    case QDColorSelection.foreground: penState.fgColor = color;
    case QDColorSelection.background: penState.bgColor = color;
    case QDColorSelection.operations: penState.opColor = color;
    case QDColorSelection.highlight: penState.highlightColor = color;
    }
  }
  
  let rgb : Bool;  // should color be loaded as RGB (true), or old style QuickDraw?
  let selection : QDColorSelection;  // What xxh
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
  var pattern : QDPattern = QDPattern.black;
}

struct PenSizeOp : OpCode, PenStateOperation {
  func execute(penState: inout PenState) {
    penState.penSize = penSize;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    penSize = try reader.readPoint();
  }
  
  var penSize = QDPoint.zero;
}

struct PenModeOp : OpCode, PenStateOperation {
  mutating func load(reader: QuickDrawDataReader) throws {
    mode = QuickDrawMode(rawValue: try reader.readUInt16());
  }
  
  func execute(penState: inout PenState) {
    penState.mode = mode;
  }
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
}

struct TextModeOp : OpCode, FontStateOperation {
  mutating func load(reader: QuickDrawDataReader) throws {
    mode = QuickDrawMode(rawValue: try reader.readUInt16());
  }
  
  func execute(fontState: inout QDFontState) {
    fontState.fontMode = mode;
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
    textSize = FixedPoint(try reader.readUInt16());
  }
  
  var textSize = FixedPoint.zero;
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

struct TextRatioOp : OpCode, FontStateOperation {
  
  mutating func load(reader: QuickDrawDataReader) throws {
    let numerator = try reader.readPoint();
    let denominator = try reader.readPoint();
    guard denominator.vertical.value != 0.0 else {
      throw QuickDrawError.invalidFract(message: "Zero denominator");
    }
    guard denominator.horizontal.value != 0.0 else {
      throw QuickDrawError.invalidFract(message: "Zero denominator");
    }
    x = numerator.horizontal / denominator.horizontal;
    y = numerator.vertical / denominator.vertical;
    
  }
  
  func execute(fontState: inout QDFontState) {
    fontState.xRatio = x;
    fontState.yRatio = y;
  }
  
  var x : FixedPoint = FixedPoint.one;
  var y : FixedPoint = FixedPoint.one;
}

struct FontStyleOp : OpCode, FontStateOperation {
  func execute(fontState: inout QDFontState) {
    fontState.fontStyle = fontStyle;
  }
  
  mutating func load(reader: QuickDrawDataReader) throws {
    fontStyle = QDFontStyle(rawValue: try reader.readUInt8());
  }
  
  var fontStyle = QDFontStyle(rawValue:0);
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
  pixMapInfo.resolution = try reader.readResolution();
  pixMapInfo.pixelType = Int(try reader.readUInt16());
  pixMapInfo.pixelSize = Int(try reader.readUInt16());
  pixMapInfo.cmpCount = Int(try reader.readUInt16());
  pixMapInfo.cmpSize = Int(try reader.readUInt16());
  pixMapInfo.planeByte = Int64(try reader.readUInt32());
  pixMapInfo.clutId = try reader.readInt32();
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
      pixMapInfo.clut = try reader.readClut();
      bitmapInfo.pixMapInfo = pixMapInfo;
    }
    
    bitmapInfo.srcRect = try reader.readRect();
    bitmapInfo.dstRect = try reader.readRect();
    bitmapInfo.mode = try QuickDrawMode(rawValue: reader.readUInt16());
    
    let rows = bitmapInfo.bounds.dimensions.dv.rounded;
    for _ in 0 ..< rows {
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
      let decompressed = try DecompressPackBit(data: rowData, unpackedSize: bitmapInfo.rowBytes);
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
    bitmapInfo.mode = try QuickDrawMode(rawValue: reader.readUInt16());
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
    for _ in 0..<rows {
      var lineLength : Data.Index;
      if bitmapInfo.hasShortRows {
        lineLength = Data.Index(try reader.readUInt8());
      } else {
        lineLength = Data.Index(try reader.readUInt16());
      }
      let line_data = try reader.readUInt8(bytes: lineLength);
      let decompressed = try DecompressPackBit(
        data: line_data, unpackedSize: bitmapInfo.rowBytes, byteNum: 2);
      
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
    for _ in 0..<rows {
      var lineLength : Data.Index;
      if bitmapInfo.hasShortRows {
        lineLength = Data.Index(try reader.readUInt8());
      } else {
        lineLength = Data.Index(try reader.readUInt16());
      }
      let line_data = try reader.readUInt8(bytes: lineLength);
      let decompressed = try DecompressPackBit(data: line_data, unpackedSize: rowBytes, byteNum: 1);
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
