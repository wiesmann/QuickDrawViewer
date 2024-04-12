//
//  Cinepak.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 07.04.2024.
//

/// Cinepak codec, see https://multimedia.cx/mirror/cinepak.txt

import Foundation

enum CinepakError : Error {
  case inconsistentHeight(frame : QDDelta, height: UInt16);
  case inconsistentWidth(frame : QDDelta, width: UInt16);
  case inconsistentSize(container: Int, header: Int);
  case tooManyStrips(strips: UInt16);
  case tooManyCodebookEntries(number: Int);
  case invalidStripId(_ id: UInt16);
  case invalidChunkId(_ id: UInt16, strip: CinepakStripHeader);
  case codeBookOutOfRange(_ index: UInt8, max: Int, name: String);
}

enum CinepakStripId : UInt16 {
  case intraCodedStrip = 0x1000;
  case interCodedStrip = 0x1100;
}

struct CinepakChunkId : OptionSet, CustomStringConvertible {
  let rawValue: UInt16;
  static let codebook = CinepakChunkId(rawValue:0x2000);
  static let vectors = CinepakChunkId(rawValue: 0x1000);
  static let eightBpp = CinepakChunkId(rawValue: 0x0400);
  static let v1 = CinepakChunkId(rawValue: 0x0200);
  static let update = CinepakChunkId(rawValue: 0x0100);
  
  var description: String {
    var result = String(format:"%X", arguments: [rawValue]);
    
    if contains(.vectors) {
      result += " Vectors";
      return result;
    }
      if contains(.codebook) {
        result += " Codebook";
      }
    
    if contains(.eightBpp) {
      result += " 8bpp";
    } else {
      result += " 12bpp";
    }
    if contains(.v1) {
      result += " v1";
    } else {
      result += " v4";
    }
    
    if contains(.update) {
      result += " Update";
    }
    return result;
    
  }
}

struct CinepakChunk {
  let chunkId : CinepakChunkId;
  let chunkData : Data;
  
  var size : Int {
    return chunkData.count;
  }
}

class CinepakStripHeader: CustomStringConvertible {
  
  init(stripId : CinepakStripId, stripSize : UInt16, stripFrame : QDRect) {
    self.stripId = stripId;
    self.stripSize = stripSize;
    self.stripFrame = stripFrame;
  }
  
  let stripId : CinepakStripId;
  let stripSize : UInt16;
  var stripFrame : QDRect;
  
  var description: String {
    return "Strip[id: \(stripId), size: \(stripSize), frame: \(stripFrame)";
  }
  
  func shiftVertical(dv: FixedPoint) {
    let delta = QDDelta(dv: dv, dh: FixedPoint.zero);
    self.stripFrame = self.stripFrame + delta;
  }
}

/// Codebook entry, basically stores a 2×2 square of pixels.
/// The entry can either by just intensity/palette entry (8 bpp) or intensity + common chroma.
struct CinepakCodeBookEntry {
  enum CodeBookPayload {
    case eight(y: SIMD4<UInt8>);
    case twelve(y: SIMD4<UInt8>, u: Int8, v: Int8);
  }
  
  init(y4 : [UInt8]) {
    assert(y4.count == 4);
    self.payload = .eight(y: SIMD4<UInt8>(y4[0], y4[1], y4[2], y4[3]))
  }
  
  init(y4 : [UInt8], u : Int8, v: Int8) {
    assert(y4.count == 4);
    let y = SIMD4<UInt8>(y4[0], y4[1], y4[2], y4[3]);
    self.payload = .twelve(y: y, u: u, v: v);
  }
  
  var y : [UInt8] {
    switch payload {
      case .eight(let y):
        return y.bytes;
      case .twelve(let y, _, _):
        return y.bytes;
    }
  }
  
  /// The four pixels in RGB8 format.
  var rgb : [[UInt8]] {
    switch payload {
      case .eight(let y):
        return y.bytes.map(){[$0, $0, $0]};
      case .twelve(let y, let u, let v):
        let u4 = SIMD4<Int16>.init(repeating: Int16(u));
        let v4 = SIMD4<Int16>.init(repeating: Int16(v));
        let one = SIMD4<Int16>.one;
        let y4 = SIMD4<Int16>.init(clamping: y);
        let r = SIMD4<UInt8>(clamping: y4 &+ (v4 &<< one));
        let g = SIMD4<UInt8>(clamping: y4 &- (u4 &>> one) &- v4);
        let b = SIMD4<UInt8>(clamping: y4 &+ (u4 &<< one));
        return [
          [r.x, g.x, b.x], [r.y, g.y, b.y], [r.z, g.z, b.z], [r.w, g.w, b.w]];
    }
  }

  let payload: CodeBookPayload;
  
  static let zero = CinepakCodeBookEntry(y4: [0x00, 0x00, 0x00, 0x00 ]);
}

class CinepakCodeBook {
  
  init(name: String) {
    self.name = name;
    entries = [CinepakCodeBookEntry].init(repeating: CinepakCodeBookEntry.zero, count: 256);
  }
  
  func readEntries(n: Int, chunkId: CinepakChunkId, reader : QuickDrawDataReader) throws {
    for i in 0..<n {
      let entry = try reader.readCinepakCodeBookEntry(chunkId: chunkId);
      entries[i] = entry;
    }
  }
  
  func updateEntries(chunkId: CinepakChunkId, reader : QuickDrawDataReader) throws {
    var pos = 0;
    while reader.remaining > 4 {
      var flag = try reader.readUInt32();
      for _ in 0..<32 {
        if flag & 0x80000000 != 0 {
          let entry = try reader.readCinepakCodeBookEntry(chunkId: chunkId);
          entries[pos] = entry;
        }
        pos += 1;
        flag = flag << 1;
      }
    }
  }
  
  func lookup(_ index : UInt8) throws -> CinepakCodeBookEntry {
    guard index < entries.count else {
      throw CinepakError.codeBookOutOfRange(index, max: entries.count, name: name);
    }
    return entries[Int(index)]
  }
  
  let name : String;
  var entries : [CinepakCodeBookEntry];
}

extension QuickDrawDataReader {
  func readCinepakStripHeader() throws -> CinepakStripHeader {
    let rawId = try readUInt16();
    guard let stripId = CinepakStripId(rawValue: rawId) else {
      throw CinepakError.invalidStripId(rawId);
    }
    let size = try readUInt16() - 12;
    let frame = try readRect();
    return CinepakStripHeader(stripId: stripId, stripSize: size, stripFrame: frame);
  }

  func readCinepakCodeBookEntry(chunkId: CinepakChunkId) throws -> CinepakCodeBookEntry{
    let y4 = try readUInt8(bytes: 4);
    if chunkId.contains(.eightBpp) {
      return CinepakCodeBookEntry(y4: y4);
    }
    let u = try readInt8();
    let v = try readInt8();
    return CinepakCodeBookEntry(y4: y4, u: u, v: v);
  }
}

enum CinepakComponents : Int {
  case index = 1;
  case rgb = 3;
}

class Cinepak : BlockPixMap {
  init(dimensions: QDDelta, clut: QDColorTable?) {
    components = clut != nil ? CinepakComponents.index : CinepakComponents.rgb;
    super.init(dimensions: dimensions, blockSize: 4, pixelSize: components.rawValue * 8, cmpSize: 8, clut: clut);
  }
  
  func apply(entry: CinepakCodeBookEntry, range: Range<Int>, offset: Int) throws {
    let max = offset + components.rawValue + range.upperBound;
    guard max < pixmap.count else {
      throw BlittingError.badPixMapIndex(index: max, pixMapSize: pixmap.count);
    }
    switch components {
      case .index:
        for i in range {
          pixmap[offset + i - range.lowerBound] = entry.y[i];
        }
      case .rgb:
        for i in range {
          let p = offset + i - range.lowerBound;
          for c in 0..<3 {
            pixmap[p + c] = entry.rgb[i][c];
          }
        }
    }
  }
  
  func applyDouble(entry: CinepakCodeBookEntry, subEntry: Int, offset: Int) throws {
    switch components {
      case .index:
        let y = entry.y[subEntry];
        pixmap[offset] = y;
        pixmap[offset + 1] = y;
        pixmap[offset + rowBytes] = y;
        pixmap[offset + rowBytes + 1] = y;
      case .rgb:
        let rgb = entry.rgb[subEntry];
        for c in 0..<3 {
          let v = rgb[c]
          pixmap[offset + c] = v;
          pixmap[offset + 3 + c] = v;
          pixmap[offset + rowBytes + c ] = v;
          pixmap[offset + rowBytes + 3 + c ] = v;
        }
    }
  }
  
  func applyV1(block: Int, v1: UInt8) throws {
    guard block < totalBlocks else {
      return;
    }
    let entry = try v1Codebook.lookup(v1);
    let offset0 = try getOffset(block: self.block, line: 0);
    try applyDouble(entry: entry, subEntry: 0, offset: offset0);
    try applyDouble(entry: entry, subEntry: 1, offset: offset0 + 2 * components.rawValue);
    let offset1 = try getOffset(block: self.block, line: 2);
    try applyDouble(entry: entry, subEntry: 2, offset: offset1);
    try applyDouble(entry: entry, subEntry :3, offset: offset1 + 2 * components.rawValue);
  }

  func applyV4(block: Int, v4: [UInt8]) throws {
    assert(v4.count == 4);
    guard block < totalBlocks else {
      return;
    }
    let entries = try v4.map(){try v4Codebook.lookup($0)};
    let lines = [0, 1, 2, 3];
    let offsets = try lines.map(){try getOffset(block: block, line: $0);}
    // First entry -> north-west
    try apply(entry: entries[0], range: 0..<2, offset: offsets[0])
    try apply(entry: entries[0], range: 2..<4, offset: offsets[1]);
    // Second entry -> north-east
    try apply(entry: entries[1], range: 0..<2, offset: offsets[0] + components.rawValue * 2)
    try apply(entry: entries[1], range: 2..<4, offset: offsets[1] + components.rawValue * 2);
    // Third entry -> south-west
    try apply(entry: entries[2], range: 0..<2, offset: offsets[2])
    try apply(entry: entries[2], range: 2..<4, offset: offsets[3]);
    // Fourth entry -> south-east
    try apply(entry: entries[3], range: 0..<2, offset: offsets[2] + components.rawValue * 2)
    try apply(entry: entries[3], range: 2..<4, offset: offsets[3] + components.rawValue * 2);
  }
    
  func applyVectors(strip: CinepakStripHeader, reader : QuickDrawDataReader) throws {
    while reader.remaining > 4 {
      var flag = Int(try reader.readUInt32());
      for _ in 0..<32 {
        if flag & 0x80000000 == 0 {
          guard reader.remaining > 0 else {
            return;
          }
          let v1 = try reader.readUInt8();
          try applyV1(block: self.block, v1: v1);
          self.block += 1;
        } else {
          guard reader.remaining >= 4 else {
            return;
          }
          let v4 = try reader.readUInt8(bytes: 4);
          try applyV4(block: self.block, v4: v4);
          self.block += 1;
        }
        flag = flag << 1;
      }
    }
  }
  
   
  func parseChunk(strip: CinepakStripHeader, chunk: CinepakChunk) throws {
    let reader = try QuickDrawDataReader(data: chunk.chunkData, position: 0);
    switch chunk.chunkId {
      case let c where c.contains(.vectors) && !c.contains(.v1):
        try applyVectors(strip: strip, reader: reader);
        
      case let c where c.contains(.codebook) && !c.contains(.update):
        let numEntries = c.contains(.eightBpp) ? (chunk.size / 4) : (chunk.size / 6);
        guard numEntries <= 256 else {
          throw CinepakError.tooManyCodebookEntries(number: numEntries);
        }
        if c.contains(.v1) {
          try v1Codebook.readEntries(n: numEntries, chunkId: chunk.chunkId, reader: reader);
        } else {
          try v4Codebook.readEntries(n: numEntries, chunkId: chunk.chunkId, reader: reader);
        }
      case let c where c.contains(.codebook) && c.contains(.update):
        if c.contains(.v1) {
          try v1Codebook.updateEntries(chunkId: chunk.chunkId, reader: reader);
        } else {
          try v1Codebook.updateEntries(chunkId: chunk.chunkId, reader: reader);
        }
      default:
        break;
    }
  }
    
  func loadStrip(strip: CinepakStripHeader, reader : QuickDrawDataReader) throws {
    assert (reader.data.count == strip.stripSize);
    while reader.remaining >= 16 {
      let rawId = try reader.readUInt16();
      let chunkId = CinepakChunkId(rawValue: rawId);
      let chunkSize = Int(try reader.readUInt16() - 4);
      let data = try reader.readData(bytes: chunkSize);
      let chunk = CinepakChunk(chunkId: chunkId, chunkData: data);
      try parseChunk(strip: strip, chunk: chunk);
    }
  }
  
  func load(data : consuming Data) throws {
    let reader = try QuickDrawDataReader(data: data, position: 0);
    self.flags = try reader.readUInt8();
    let sizeHigh = Int(try reader.readUInt8());
    let sizeLow = Int(try reader.readUInt16());
    let size = sizeLow & (sizeHigh << 16);
    guard size == 0 || size == reader.data.count else {
      throw CinepakError.inconsistentSize(container: reader.data.count, header: size);
    }
    let width = try reader.readUInt16();
    guard Int(width) == self.bufferDimensions.dh.rounded else {
      throw CinepakError.inconsistentWidth(frame:self.bufferDimensions, width:width);
    }
    let height = try reader.readUInt16();
    guard Int(height) == self.bufferDimensions.dv.rounded else {
      throw CinepakError.inconsistentHeight(frame:self.bufferDimensions, height:height);
    }
    let strips = try reader.readUInt16();
    guard strips <= 32 else {
      throw CinepakError.tooManyStrips(strips: strips);
    }
    var y = FixedPoint.zero;
    for s in 0..<strips {
      let stripHeader = try reader.readCinepakStripHeader();
      stripHeader.shiftVertical(dv:y);
      let stripReader = try reader.subReader(bytes: Int(stripHeader.stripSize));
      try loadStrip(strip: stripHeader, reader: stripReader);
      y += stripHeader.stripFrame.dimensions.dv;
    }
  }
  
  let components : CinepakComponents;
  var v1Codebook = CinepakCodeBook(name: "v1");
  var v4Codebook = CinepakCodeBook(name: "v4");
  var flags : UInt8 = 0;
  var block : Int = 0;
}
