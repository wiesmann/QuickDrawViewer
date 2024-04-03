//
//  QuickDrawRegions.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 02.03.2024.
//

import Foundation

/// This file contains all the code related to region processing.

/// A single, raw line of the QuickDraw region.
/// bitmap is one _byte_ per pixel.
struct QDRegionLine {
  let lineNumber : Int;
  let bitmap : [UInt8];
}

let QDRegionEndMark = 0x7fff;
let QDRegionHeaderSize = UInt16(10);

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
func BitLineToRanges(line: [UInt8]) -> Set<Range<Int>> {
  var index = 0;
  var result = Set<Range<Int>>();
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
    result.insert(start..<index);
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
    var result = "Region \(boundingBox)";
    if rects.count > 0 {
      result += " \(rects.count) rects";
    }
    return result ;
  }
  
  var boundingBox: QDRect = QDRect.empty;
  var isRect : Bool {
    return rects.isEmpty;
  }
  
  static func forRect(rect: QDRect) -> QDRegion {
    return QDRegion(boundingBox: rect, rects:[], bitlines:[[]]);
  }
  
  static let empty = QDRegion(
    boundingBox: QDRect.empty, rects: [], bitlines: []);
   
  let rects : [QDRect];
  
  func getRects() ->  [QDRect] {
    if isRect {
      return [boundingBox];
    }
    return rects;
  }
  
  let bitlines: [[UInt8]];
}

extension QuickDrawDataReader {
  func readRegion() throws -> QDRegion {
    var len = UInt16(try readUInt16());
    if len < QDRegionHeaderSize {
      len += QDRegionHeaderSize;
    }
    let rgnDataSize = Data.Index(len - QDRegionHeaderSize);
    let box = try readRect();
    if rgnDataSize > 0 {
      let data = try readUInt16(bytes: rgnDataSize);
      let (rects, bitlines) = try DecodeRegionData(boundingBox: box, data: data);
      return QDRegion(boundingBox:box, rects:rects, bitlines: bitlines);
    }
    return QDRegion(boundingBox:box, rects: [], bitlines:[[]]);
  }
}
