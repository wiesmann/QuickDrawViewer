//
//  PackBitTests.swift
//  QuickDrawViewerTests
//
//  Created by Matthias Wiesmann on 19.04.2024.
//

import XCTest

final class PackBitTests: XCTestCase {

  func testDecode() throws {
    // Discrete run
    let discreteData : [UInt8] = [0x05, 0x01, 0x02, 0x03, 0x04, 0x5, 0x6];
    XCTAssertEqual(
      try decompressPackBit(data: discreteData[...], unpackedSize: 6),
      [0x01, 0x02, 0x03, 0x04, 0x5, 0x6]);
    let repeatedData : [UInt8] = [UInt8(bitPattern: Int8(-6)), 0x10];
    XCTAssertEqual(
      try decompressPackBit(data: repeatedData[...], unpackedSize: 7),
      [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10]);
  }

  func testPerformance() throws {
    var repeatedData : [UInt8] = [];
    for _ in 0..<10 {
      repeatedData.append(UInt8(bitPattern: Int8(-99)));
      repeatedData.append(0x10);
    }
    self.measure {
      do {
        for _ in 0..<1000 {
          _ = try decompressPackBit(data: repeatedData[...], unpackedSize: 1000);
        }
      }
      catch {
        print("Should probably not happen: \(error)")
      }
    }
  }
}
