//
//  Planar.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 09.02.2024.
//

import Foundation

/// See https://wiki.multimedia.cx/index.php/8BPS
/// See https://github.com/TheDiamondProject/Graphite/blob/aa6636a1fe09eb2439e4972c4501724b3282ac7c/libGraphite/quicktime/planar.cpp

enum PlanarImageError : Error {
  case badDepth(depth: Int);
  case packbitError(line: Int, packbitError: PackbitError);
}

class PlanarImage {
  init(dimensions: QDDelta, depth: Int) throws {
    self.dimensions = dimensions;
    self.depth = depth;
    switch depth {
      case 8: self.channels = 1;
      case 24: self.channels = 3;
    default:
      throw PlanarImageError.badDepth(depth: depth);
    }
    
    self.pixmap = [];
  }
  
  func load(data : Data) throws {
    let reader = try QuickDrawDataReader(data: data, position:0);
    let lines = (dimensions.dv.rounded * channels);
    var lineLengths : [Int] = [];
    for _ in 0..<lines {
      lineLengths.append(Int(try reader.readUInt16()));
    }
    // Read raw data
    let width = dimensions.dh.rounded;
    var raw : [UInt8] = [];
    for (number, length) in lineLengths.enumerated() {
      do {
        let compressed = try reader.readUInt8(bytes: length);
        let decompressed = try DecompressPackBit(data: compressed, unpackedSize: width);
        raw.append(contentsOf: decompressed);
      } catch let error as PackbitError {
        throw PlanarImageError.packbitError(line: number, packbitError: error);
      }
    }
    if channels == 1 {
      pixmap = raw;
      return;
    }
    // Reorganize memory
    let planeSize = raw.count / channels;
    for i in 0..<planeSize {
      for p in 0..<channels {
        pixmap.append(raw[i + planeSize * p]);
      }
    }
    assert(pixmap.count == raw.count);
  }
  
  var rowBytes : Int {
    return dimensions.dh.rounded * pixelSize / 8;
  }
  
  let cmpSize : Int = 8;
  var pixelSize : Int {
    return cmpSize * channels;
  }
  
  let dimensions: QDDelta;
  let depth: Int;
  var channels : Int;
  var pixmap : [UInt8];
}

