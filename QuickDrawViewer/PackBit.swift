//
//  PackBit.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 16.12.2023.
//

enum PackbitError: Error  {
  case mismatchedLength(expectedLength: Int, actualLength: Int);
}

import Foundation

/// PackBit run-length decompressor, by default works on 1 byte quantities.
/// - Parameters:
///   - data: compressed data
///   - unpackedSize: size of the unpacked data
///   - byteNum: number of bytes in a chunk (default 1)
/// - Returns: decompressed data
func DecompressPackBit(data : [UInt8], unpackedSize: Int, byteNum : Int = 1) throws -> [UInt8] {
  var decompressed : [UInt8] = [];
  decompressed.reserveCapacity(unpackedSize);
  var index = 0;
  while index < data.count - 1 {
    let tag = Int8(bitPattern: data[index]);
    index += 1;
    if (tag < 0) {
      let run_len = (Int(tag) * -1) + 1;
      let element = data[index..<index + byteNum];
      let repeated = repeatElement(element, count: run_len);
      decompressed.append(contentsOf: repeated.joined());
      index += byteNum
    } else {
      let discrete_len = Int(tag) + 1;
      let offset = discrete_len * byteNum;
      let slice = data[index..<index + offset];
      decompressed.append(contentsOf: slice);
      index += offset;
    }
  }
  guard decompressed.count == unpackedSize else {
    throw PackbitError.mismatchedLength(expectedLength: unpackedSize, actualLength: decompressed.count );
  }
  return decompressed;
}

func DecompressUnsignedPackbit(data: [UInt8], unpackedSize: Int) throws -> [UInt8] {
  var decompressed : [UInt8] = [];
  decompressed.reserveCapacity(unpackedSize);
  var index = 0;
  while index < data.count - 1 {
    let tag = data[index];
    index += 1;
    if (tag > 127) {
      let runLength = 257 - Int(tag);
      let repeated = [UInt8].init(repeating: data[index], count: runLength);
      decompressed.append(contentsOf: repeated);
      index += 1;
    } else {
      let offset = Int(tag);
      let slice = data[index..<index + offset];
      decompressed.append(contentsOf: slice);
      index += offset;
    }
  }
  guard decompressed.count == unpackedSize else {
    throw PackbitError.mismatchedLength(expectedLength: unpackedSize, actualLength: decompressed.count );
  }
  return decompressed;
}
