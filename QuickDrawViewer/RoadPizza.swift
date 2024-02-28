//
//  RoadPizza.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 24.01.2024.
//

import Foundation



/// Creates a ARGB555 color that is ⅔ color a and ⅓ color b.
/// - Parameters:
///   - a: color to mix ⅔ from
///   - b: color to mix ⅓ from
/// - Returns: a color which is on the line in RGB space between a and b.
func mix⅔(_ a: ARGB555, _ b: ARGB555) -> ARGB555 {
  return ARGB555(
    red: (a.red * 21 + b.red * 11) >> 5,
    green: (a.green * 21 + b.green * 11) >> 5,
    blue: (a.blue * 21 + b.blue * 11) >> 5);
}

extension QuickDrawDataReader {
  func ReadRGB555() throws -> ARGB555 {
    let raw = (try self.readUInt16()) | 0x8000;
    return ARGB555(rawValue: raw);
  }
}

enum RoadPizzaError : Error {
  case badMagic(magic: UInt8);
  case unknownOpcode(opcode: UInt8);
  case badPixMapIndex(index: Int);
}

/// Image compressed with the RPZA (RoadPizza) compression.
/// Decode the sequence of opcodes into a ARGB555 buffer.
/// Skipped blocks will have transparent pixels.
class RoadPizzaImage : PixMapMetadata {
  
  init(dimensions: QDDelta) {
    self.dimensions = dimensions;
    self.blocksPerLine = (dimensions.dh.rounded + 3) / 4
    self.totalBlocks = blocksPerLine * (dimensions.dv.rounded + 3) / 4
    self.pixmap = [UInt8].init(
      repeating: 0, count: totalBlocks * 16 * ARGB555.pixelBytes);
  }
  
  var rowBytes : Int {
    return blocksPerLine * RoadPizzaImage.blockSize * 2;
  }
  
  /// Function that writes a line of pixels from a block into the buffer.
  /// - Parameters:
  ///   - block: block number
  ///   - line: line number within the block
  ///   - color4: slice of 4 pixels
  private func writePixelLine(block: Int, line: Int, color4: ArraySlice<ARGB555>) throws {
    assert(color4.count == RoadPizzaImage.blockSize, "Invalid pixel line size");
    let row = (block / blocksPerLine) * 4 + line;
    let offset = (block % blocksPerLine);
    let p = (row * rowBytes) + (offset * RoadPizzaImage.blockSize * ARGB555.pixelBytes)
    guard 0..<pixmap.count ~= p else {
      throw RoadPizzaError.badPixMapIndex(index: p);
    }
    for (index, value) in color4.enumerated() {
      let rawValue = value.rawValue;
      pixmap[p + (index * 2)] =  UInt8(rawValue >> 8);
      pixmap[p + (index * 2) + 1] = UInt8(rawValue & 0xff);
    }
  }
  
  func execute1Color(block: Int, color: ARGB555) throws {
    let color4 = [ARGB555].init(repeating: color, count: RoadPizzaImage.blockSize);
    for line in 0..<RoadPizzaImage.blockSize {
      try writePixelLine(block: block, line: line, color4: color4[0..<4]);
    }
  }
  
  func executeIndexColor(block: Int, colorA: ARGB555, colorB: ARGB555, data: [UInt8]) throws {
    assert(data.count == RoadPizzaImage.blockSize, "Invalid index color data size");
    let colorTable : [ARGB555] = [
      colorB, mix⅔(colorB, colorA), mix⅔(colorA, colorB), colorA];
    for (line, value) in data.enumerated() {
      var color4 : [ARGB555] = [];
      var shiftedValue = value;
      for _ in 0..<RoadPizzaImage.blockSize {
        let index = Int((shiftedValue & 0xc0) >> 6);
        color4.append(colorTable[index]);
        shiftedValue = shiftedValue << 2;
      }
      try writePixelLine(block: block, line: line, color4: color4[0..<4]);
    }
  }
  
  func executeDirectColor(block: Int, data: [ARGB555]) throws {
    assert(data.count == RoadPizzaImage.blockSize * RoadPizzaImage.blockSize,
           "Invalid direct color data size");
    
    for line in 0..<RoadPizzaImage.blockSize {
      try writePixelLine(block: block, line: line, color4: data[line*4..<(line + 1)*4]);
    }
  }
  
  func load(data : Data) throws {
    let reader = try QuickDrawDataReader(data: data, position: 0);
    let magic = try reader.readUInt8();
    guard magic == 0xe1 else {
      throw RoadPizzaError.badMagic(magic: magic);
    }
    reader.skip(bytes: 3);  // Length
    var block = 0;
    var colorA = ARGB555.zero;
    var colorB = ARGB555.zero;
    
    while reader.remaining > 1 {
      let rawOpcode = try reader.readUInt8();
      let opcode = rawOpcode & 0xe0;
      let blockCount = Int(rawOpcode & 0x1f) + 1;
      switch opcode {
      case let lowbit  where lowbit & 0x80 == 0:
        /// Special case: colorA is encoded in rawOpcode + 1 byte
        let v = UInt16(rawOpcode) << 8 | UInt16(try reader.readUInt8()) | 0x8000;
        colorA = ARGB555(rawValue: v);
        if (try reader.peekUInt8() & 0x80) != 0 {
          /// Special case of palette block
          colorB = try reader.ReadRGB555();
          let data = try reader.readUInt8(bytes: RoadPizzaImage.blockSize);
          try executeIndexColor(block: block, colorA: colorA, colorB: colorB, data: data);
          block += 1;
        } else {
          /// Direct AGRB data, colorA is the first.
          var data : [ARGB555] = [colorA];
          for _ in 0..<15 {
            data.append(try reader.ReadRGB555());
          }
          try executeDirectColor(block: block, data: data);
          block += 1;
        }
      case 0x80:  /// Skip the block
        block += blockCount;
      case 0xa0:  /// Single color block(s)
        colorA = try reader.ReadRGB555();
        for i in block..<block + blockCount {
          try execute1Color(block: i, color: colorA);
        }
        block += blockCount;
      case 0xc0:  /// Index color blocks
        colorA = try reader.ReadRGB555();
        colorB = try reader.ReadRGB555();
        for i in block..<block + blockCount {
          let data = try reader.readUInt8(bytes: 4);
          try executeIndexColor(block: i, colorA: colorA, colorB: colorB, data: data);
        }
        block += blockCount;
      default:
        throw RoadPizzaError.unknownOpcode(opcode: opcode);
      }
    }
  }
  
  let dimensions : QDDelta;
  let blocksPerLine : Int;
  let totalBlocks : Int;
  let cmpSize : Int = 5;
  let pixelSize: Int = 16;
  var pixmap : [UInt8];
  var clut: QDColorTable? = nil;
  
  static let blockSize = 4;
  static let blockDimensions = QDDelta(dv: blockSize, dh: blockSize);
}
