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

/// Convert YUV values to RGB bytes.
/// - Parameters:
///   - y: luminence in the 0-255 range
///   - u: u chrominance in the -127 - 128 range
///   - v: v chrominance in the -127 - 128 range
/// - Returns: rgb bytes
func yuv2Rgb(y : Double, u: Double, v: Double) -> [UInt8] {
  let r = Int(y + (1.370705 * v));
  let g = Int(y - (0.698001 * v) - 0.337633 * u);
  let b = Int(y + (1.732446 * u));
  return [UInt8(clamping: r), UInt8(clamping: g), UInt8(clamping: b)];
}

func yuv2Rgb(y: UInt8, u: UInt8, v: UInt8) -> [UInt8] {
  let nu = Double(u) - 128;
  let nv = Double(v) - 128;
  let ny = Double(y);
  return yuv2Rgb(y: ny, u: nu, v: nv);
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
    default:
      throw BlittingError.unsupportedDepth(depth: depth);
  }
}

/// Abstract view of a bitmap information
protocol PixMapMetadata : CustomStringConvertible {
  
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
class BlockPixMap : PixMapMetadata {

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
  
  func getBlock(_ point: QDPoint) -> Int {
    return 
        (point.vertical.rounded / blockSize * blocksPerLine) +
        (point.horizontal.rounded / blockSize);
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
