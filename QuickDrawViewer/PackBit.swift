//
//  PackBit.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 16.12.2023.
//
// Facilities to handle PackBit and PackBit like compression.

import Foundation

enum PackbitError: Error  {
  case mismatchedLength(expectedLength: Int, actualLength: Int);
  case emptySlice;
  case outOfBoundRunStart(start: Int, dataSize: Int);
  case outOfBoundRunEnd(end: Int, data: ArraySlice<UInt8>);
}

/// Copy a repeated pattern of length `length`× `byteNum`.
/// - Parameters:
///   - length: number of time pattern is repeated
///   - src: array where the pattern (`byteNum` bytes) is read.
///   - destination: where the pattern is written.
///   - byteNum: size of the pattern in bytes.
/// - Throws: outOfBoundRunEnd if pattern is larger than `src`.
/// - Returns: number of bytes read, always `byteNum`.
func copyRepeated(length: Int, src : ArraySlice<UInt8>, destination: inout [UInt8], byteNum: Int) throws -> Int {
  guard !src.isEmpty else {
    throw PackbitError.emptySlice;
  }
  let start = src.startIndex;
  let end = start + byteNum;
  guard end <= src.endIndex else {
    throw PackbitError.outOfBoundRunEnd(end: byteNum, data: src);
  }
  let element = src[start..<end];
  let repeated = repeatElement(element, count: length);
  destination.append(contentsOf: repeated.joined());
  return byteNum;
}

/// Copy a discrete pattern
/// - Parameters:
///   - length: number of pattern to copy
///   - src: where the patterns are read from
///   - destination: where the pattern is written to
///   - byteNum: size of the pattern in bytes
/// - Throws: outOfBoundRunEnd if length × byteNum > src
/// - Returns: number of bytes read,
func copyDiscrete(length: Int, src : ArraySlice<UInt8>, destination : inout [UInt8], byteNum: Int) throws -> Int {
  guard !src.isEmpty else {
    throw PackbitError.emptySlice;
  }
  let start = src.startIndex;
  let end = start + (length * byteNum);
  guard end <= src.endIndex else {
    throw PackbitError.outOfBoundRunEnd(end: end, data: src);
  }
  let slice = src[start..<end];
  destination.append(contentsOf: slice);
  return end - start;
}

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
    guard index < data.count else {
      throw PackbitError.outOfBoundRunStart(start: index, dataSize: data.count);
    }
    if (tag < 0) {
      let length = (Int(tag) * -1) + 1;
      index += try copyRepeated(length: length, src: data[index...], destination: &decompressed, byteNum: byteNum);
    } else {
      let length = Int(tag) + 1;
      index += try copyDiscrete(length: length, src: data[index...], destination: &decompressed, byteNum: byteNum);
    }
  }
  guard decompressed.count == unpackedSize else {
    throw PackbitError.mismatchedLength(expectedLength: unpackedSize, actualLength: decompressed.count );
  }
  return decompressed;
}
