//
//  Blitting.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 10.03.2024.
//
// Various image processing utilities.

import Foundation

enum BlittingError : Error {
  case invalidBlockNumber(blockNumber: Int, totalBlockNumber: Int);
  case invalidBlockLine(lineNumber: Int, blockSize: Int);
  case badPixMapIndex(index: Int, pixMapSize: Int);
  case unsupportedDepth(depth : Int);
}

func roundTo(_ value: FixedPoint, multipleOf: Int) -> Int {
  return (value.rounded + (multipleOf - 1)) / multipleOf * multipleOf;
}

/// Struct to hold an classical RGB8 value
struct RGB8 : Hashable {
  init(r: UInt8, g: UInt8, b: UInt8) {
    self.r = r;
    self.g = g;
    self.b = b;
  }

  init(simd: SIMD3<UInt8>) {
    self.r = simd.x;
    self.g = simd.y;
    self.b = simd.z;
  }

  var bytes : [UInt8] {
    return [r, g, b];
  }

  let r : UInt8;
  let g : UInt8;
  let b : UInt8;
}

/// Convert 3 SIMD arrays of 4 pixel components into 4 RGB8 values.
/// - Parameters:
///   - r: red value for 4 pixels.
///   - g: green value for 4 pixels.
///   - b: blue value for 4 pixels.
/// - Returns: 4 RGB8 pixels.
func toRGB8(r: SIMD4<UInt8>, g: SIMD4<UInt8>, b: SIMD4<UInt8>) -> [RGB8] {
  return [
    RGB8(r: r.x, g: g.x, b: b.x),
    RGB8(r: r.y, g: g.y, b: b.y),
    RGB8(r: r.z, g: g.z, b: b.z),
    RGB8(r: r.w, g: g.w, b: b.w)
  ];
}

/// Convert a 8 bit color value into a 16 bit one.
/// - Parameter value: a 8 bit color components
/// - Returns: a 16 bit color component.
func padComponentTo16<T : BinaryInteger>(_ value: T) -> UInt16 {
  return UInt16(value & 0xff) << 8 | UInt16(value & 0xff);
}

/// Pixel in ARGB555 format with the alpha in the first bit.
/// Mostly used by the RoadPizza decompressor.
struct ARGB555: RawRepresentable {
  init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  init(red: UInt8, green: UInt8, blue: UInt8) {
    rawValue = UInt16(blue & 0x1F) | UInt16(green & 0x1F) << 5 | UInt16(red & 0x1F) << 10 | 0x8000;
  }

  init(simd: SIMD3<UInt8>) {
    self.init(red: simd.x, green: simd.y, blue: simd.z);
  }

  var red : UInt8 {
    return UInt8((rawValue >> 10) & 0x1F);
  }

  var green : UInt8 {
    return UInt8((rawValue >> 5) & 0x1F);
  }

  var blue : UInt8 {
    return UInt8((rawValue) & 0x1F);
  }

  let rawValue : UInt16;

  var simdValue : SIMD3<UInt8> {
    return SIMD3<UInt8>(x: red, y: green, z:blue);
  }

  static let zero = ARGB555(rawValue: 0);
  static let pixelSize = 16;
  static let componentSize = 5;
}

/// Convert YUV floating point values to RGB bytes.
/// - Parameters:
///   - y: luminence in the 0-255 range
///   - u: u chrominance in the -127 - 128 range
///   - v: v chrominance in the -127 - 128 range
/// - Returns: rgb bytes
func yuv2Rgb(y : Double, u: Double, v: Double) -> RGB8 {
  let r = Int(y + (1.370705 * v));
  let g = Int(y - (0.698001 * v) - 0.337633 * u);
  let b = Int(y + (1.732446 * u));
  return RGB8(r: UInt8(clamping: r), g: UInt8(clamping: g), b: UInt8(clamping: b));
}

func yuv2Rgb(y: UInt8, u: UInt8, v: UInt8) -> RGB8 {
  let nu = Double(u) - 128;
  let nv = Double(v) - 128;
  let ny = Double(y);
  return yuv2Rgb(y: ny, u: nu, v: nv);
}

/// Interleave a buffer of the form AAAABBBBCCCC to ABCABCABCABC
func interleave(planar : ArraySlice<UInt8>, components: Int) -> [UInt8] {
  var result : [UInt8] = [];
  let w = planar.count / components;
  for i in 0..<w {
    let index = i + planar.startIndex;
    for j in 0..<components {
      result.append(planar[index + w * j]);
    }
  }
  return result;
}

func makeAlphaOpaque(argb : [UInt8]) -> [UInt8] {
  var result : [UInt8] = argb;
  for i in 0..<result.count {
    if (i % 4) == 0 {
      result[i] = 0xff;
    }
  }
  return result;
}

/// Get the number of channels and component size (int bits) associated with a color depth.
/// - Parameter depth: color depth (in bits)
/// - Throws: Error in case of unsupported depth.
/// - Returns: a pair of the form (component numbers, component size in bits).
func expandDepth(_ depth : Int) throws -> (Int, Int) {
  switch depth {
    case let d where d <= 8:
      return (1, d);
    case 16:
      return (3, 5);
    case 24:
      return (3, 8);
    case 32:
      return (3, 8);
    default:
      throw BlittingError.unsupportedDepth(depth: depth);
  }
}

/// Abstract view of a bitmap information
protocol PixMapMetadata : CustomStringConvertible, Sendable {

  var dimensions : QDDelta {get};
  var rowBytes : Int {get};
  var cmpSize : Int {get};
  var pixelSize : Int {get};
  
  var clut: QDColorTable? {get};
}

func describePixMap(_ pm: PixMapMetadata) -> String {
  return "\(pm.dimensions) rowBytes: \(pm.rowBytes) pixelSize: \(pm.pixelSize)"
}

/// Parent class for block based pixmap formats.
class BlockPixMap : PixMapMetadata, @unchecked Sendable {

  init(dimensions: QDDelta, blockSize: Int, pixelSize: Int, cmpSize: Int, clut: QDColorTable?) {
    self.dimensions = dimensions;
    self.blockSize = blockSize;
    self.pixelSize = pixelSize;
    self.cmpSize = cmpSize;
    self.clut = clut;
    let blockOffset = blockSize - 1;
    self.blocksPerLine = (dimensions.dh.rounded + blockOffset) / blockSize;
    let blockLines = (dimensions.dv.rounded + blockOffset) / blockSize;
    self.totalBlocks = blocksPerLine * blockLines;
    self.bufferDimensions = QDDelta(dv: FixedPoint(blockLines * blockSize), dh: FixedPoint(blocksPerLine * blockSize));
    let blockBytes = blockSize * blockSize * pixelSize / 8;
    // Add one safety block because rounding up happens.
    self.pixmap = [UInt8].init(repeating: 0, count: (totalBlocks + 1) * blockBytes);
  }
  
  var description: String {
    let desc = describePixMap(self);
    return "BlockImage \(desc) \(blockSize)×\(blockSize)";
  }
  
  var rowBytes: Int {
    return blocksPerLine * blockSize * pixelSize / 8;
  }
  
  func getOffset(block: Int, line: Int) throws -> Int {
    guard (0..<totalBlocks).contains(block) else {
      throw BlittingError.invalidBlockNumber(blockNumber: block, totalBlockNumber: totalBlocks);
    }
    guard (0..<blockSize).contains(line) else {
      throw BlittingError.invalidBlockLine(lineNumber: line, blockSize: blockSize);
    }
    let row = (block / blocksPerLine) * blockSize + line;
    let offset = (block % blocksPerLine);
    let p = (row * rowBytes) + (offset * blockSize * pixelSize / 8);
    guard (0..<pixmap.count).contains(p) else {
      throw BlittingError.badPixMapIndex(index: p, pixMapSize: pixmap.count);
    }
    return p;
  }
  
  let dimensions : QDDelta;
  let bufferDimensions : QDDelta;
  let blockSize : Int;
  let pixelSize : Int;
  let cmpSize : Int;
  let clut: QDColorTable?
  let blocksPerLine : Int;
  let totalBlocks : Int;
  
  var pixmap : [UInt8];
}
