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

enum CommentPayload {
  case noPayload;
  case dataPayload(data: Data);
  case postScriptPayLoad(postscript: String);
  case textPictPayload(payload: QDTextPictRecord);
  case setLineWidthPayload(width: FixedPoint);
  case pointPayload(point: QDPoint);
}

func ReadTextPictRecord(reader: QuickDrawDataReader) throws -> QDTextPictRecord {
  guard let justification = QDTextJustification(rawValue: try reader.readUInt8()) else {
    throw QuickDrawError.quickDrawIoError(message: "Could not load textCenter payload");
  }
  guard let flip = QDTextFlip(rawValue: try reader.readUInt8()) else {
    throw QuickDrawError.quickDrawIoError(message: "Could not load textCenter payload");
  }
  let angle1 = try reader.readInt16();
  reader.skip(bytes: 2);
  let angle2 = try reader.readFixed();
  let angle = angle2 + FixedPoint(angle1);
  return QDTextPictRecord(justification: justification, flip: flip, angle: angle);
}

struct CommentOp : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    let value = try reader.readUInt16();
    kind = CommentType(rawValue: value) ?? .unknown;
    if kind == .unknown {
      print("Unknown comment \(value)")
    }
    if long_comment {
      let size = Data.Index(try reader.readUInt16());
      switch kind {
      case .proprietary:
        creator = try reader.readString(bytes: 4);
        payload = .dataPayload(data: try reader.readData(bytes: size - 4));
      case .postscriptBeginNoSave, .postscriptStart, .postscriptFile, .postscriptHandle:
        payload = .postScriptPayLoad(postscript : try reader.readString(bytes: size));
      case .textBegin:
        let subreader = try reader.subReader(bytes: size);
        payload = .textPictPayload(payload: try ReadTextPictRecord(reader: subreader));
      case .setLineWidth:
        let subreader = try reader.subReader(bytes: size);
        let point = try subreader.readPoint();
        payload = .setLineWidthPayload(width: point.vertical / point.horizontal);
      case .textCenter:
        let subreader = try reader.subReader(bytes: size);
        let v = try subreader.readFixed();
        let h = try subreader.readFixed();
        payload = .pointPayload(point: QDPoint(vertical: v, horizontal: h));
      default:
       payload = .dataPayload(data: try reader.readData(bytes: size));
      }
    }
  }
  
  let long_comment : Bool;
  var kind : CommentType = .unknown;
  var creator : String = "";
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
    mode = QuickDrawMode(value: try reader.readUInt16());
  }
  
  func execute(penState: inout PenState) {
    penState.mode = mode;
  }
  
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
}

struct TextModeOp : OpCode, FontStateOperation {
  mutating func load(reader: QuickDrawDataReader) throws {
    mode = QuickDrawMode(value: try reader.readUInt16());
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
    x = numerator.horizontal.value / denominator.horizontal.value;
    y = numerator.vertical.value / denominator.vertical.value;
    
  }
  
  func execute(fontState: inout QDFontState) {
    fontState.xRatio = x;
    fontState.yRatio = y;
  }
  
  var x : Double = 1.0;
  var y : Double = 1.0;
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
  pixMapInfo.resolution = try reader.readResolution();
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
        // DeskDraw produces index with value 0x8000
        if r_index != index && r_index != 0x8000 {
          print("Inconsistent index: \(r_index)≠\(index)");
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

func byteArrayLE<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
  withUnsafeBytes(of: value.littleEndian, Array.init)
}

/// Some data types (BMP) are missing the header data. Reconstruct it if needed.
/// - Parameter quicktimeImage: image whose data needs patching.
/// - Throws: missingQuickTimeData if there is not data
func patchQuickTimeImage(quicktimeImage : inout QuickTimeImage) throws {
  if quicktimeImage.codecType != "WRLE" {
    return;
  }
  guard let data = quicktimeImage.data else {
    throw QuickDrawError.missingQuickTimeData(quicktimeImage: quicktimeImage);
  }
  
  var patched = Data();
  patched.append(contentsOf: [0x42, 0x4D]);
  let bmpHeaderSize : Int32 = 14;
  let dibHeaderSize : Int32 = 12;
  let headerSize = bmpHeaderSize + dibHeaderSize;
  let totalSize = headerSize + Int32(data.count);
  patched.append(contentsOf: byteArrayLE(from: totalSize));
  patched.append(contentsOf: [0x00, 0x00, 0x00, 0x00]);
  patched.append(contentsOf: byteArrayLE(from: headerSize));
  patched.append(contentsOf: byteArrayLE(from: dibHeaderSize));
  let width = Int16(quicktimeImage.dimensions.dh.rounded);
  let height = Int16(quicktimeImage.dimensions.dv.rounded);
  patched.append(contentsOf: byteArrayLE(from: width));
  patched.append(contentsOf: byteArrayLE(from: height));
  let planes = Int16(1);
  patched.append(contentsOf: byteArrayLE(from: planes));
  let depth = Int16(quicktimeImage.depth);
  patched.append(contentsOf: byteArrayLE(from: depth));
  assert(patched.count == headerSize);
  patched.append(data);
  quicktimeImage.data = patched;
}

struct QuickTimeOpcode : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    dataSize = Int(try reader.readInt32());
    let subReader = try reader.subReader(bytes: dataSize);
    opcodeVersion = try subReader.readInt16();
    for _ in 0..<3 {
      var line : [FixedPoint] = [];
      for _ in 0..<3 {
        line.append(try subReader.readFixed());
      }
      quicktimePayload.transform.append(line);
    }
    matteSize = Int(try subReader.readInt32());
    quicktimePayload.matte = try subReader.readRect();
    quicktimePayload.mode = QuickDrawMode(value: try subReader.readUInt16());
    let srcRect = try subReader.readRect();
    quicktimePayload.accuracy = Int(try subReader.readUInt32());
    maskSize = Int(try subReader.readUInt32());
    // variable length parts
    reader.skip(bytes: matteSize);
    let maskData = try subReader.readUInt16(bytes: maskSize);
    let (rects, bitlines) = try DecodeRegionData(boundingBox: srcRect, data: maskData);
    quicktimePayload.srcMask = QDRegion(boundingBox: srcRect, rects: rects, bitlines: bitlines);
    // Picture size
    
    quicktimePayload.quicktimeImage.idSize = Int(try subReader.readUInt32());
    quicktimePayload.quicktimeImage.codecType = try subReader.readType();
    subReader.skip(bytes: 8);
    quicktimePayload.quicktimeImage.imageVersion = Int(try subReader.readUInt16());
    quicktimePayload.quicktimeImage.imageRevision = Int(try subReader.readUInt16());
    quicktimePayload.quicktimeImage.compressorDevelopper = try subReader.readType();
    quicktimePayload.quicktimeImage.temporalQuality = try subReader.readUInt32();  // 4
    quicktimePayload.quicktimeImage.spatialQuality = try subReader.readUInt32(); // 4
    quicktimePayload.quicktimeImage.dimensions = try subReader.readDelta();
    quicktimePayload.quicktimeImage.resolution = try subReader.readResolution();
    quicktimePayload.quicktimeImage.dataSize = Int(try subReader.readInt32());
    quicktimePayload.quicktimeImage.frameCount = Int(try subReader.readInt16());
    quicktimePayload.quicktimeImage.compressionName = try subReader.readStr31();
    quicktimePayload.quicktimeImage.depth = Int(try subReader.readInt16());
    quicktimePayload.quicktimeImage.clutId = Int(try subReader.readInt16());
    subReader.skip(bytes: quicktimePayload.quicktimeImage.idSize - 86);
    quicktimePayload.quicktimeImage.data = try subReader.readData(bytes: subReader.remaining);
    try patchQuickTimeImage(quicktimeImage: &quicktimePayload.quicktimeImage);
  }

  var opcodeVersion : Int16 = 0;
  var dataSize : Int = 0;
  var matteSize : Int = 0;
  var maskSize : Int = 0;
  var quicktimePayload : QuickTimePayload = QuickTimePayload();
  
}
