//
//  PackBit.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 16.12.2023.
//

import Foundation

/// PackBit run-length decompressor, by default works on 1 byte quantities.
/// - Parameters:
///   - data: compressed data
///   - byteNum: number of bytes in a chunk (default 1)
/// - Returns: decompressed data
func DecompressPackBit(data : [UInt8], byteNum : Int = 1) -> [UInt8] {
  var decompressed : [UInt8] = [];
  var index = 0;
  while index < data.count - 1 {
    let tag = Int8(bitPattern: data[index]);
    index += 1;
    if (tag < 0) {
      let run_len = (Int(tag) * -1) + 1;
      let v = data[index..<index + byteNum];
      index += byteNum
      for _ in 0 ..< run_len {
        decompressed.append(contentsOf: v);
      }
    } else {
      let discrete_len = Int(tag) + 1;
      for _ in 0 ..< discrete_len * byteNum {
        decompressed.append(data[index]);
        index += 1;
      }
    }
  }
  return decompressed;
}


