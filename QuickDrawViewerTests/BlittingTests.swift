//
//  ColorTests.swift
//  QuickDrawViewerTests
//
//  Created by Matthias Wiesmann on 19.04.2024.
//

import XCTest

final class BlittingTests : XCTestCase {

  func testRGBFields() throws {
    XCTAssertEqual(RGBColor.black.rgb.bytes, [0x00, 0x00, 0x00]);
    XCTAssertEqual(RGBColor.red.rgb.bytes, [0xff, 0x00, 0x00]);
    XCTAssertEqual(RGBColor.green.rgb.bytes, [0x00, 0xff, 0x00]);
    XCTAssertEqual(RGBColor.blue.rgb.bytes, [0x00, 0x00, 0xff]);
    XCTAssertEqual(RGBColor.cyan.rawValue, 0x0000ffffffff);
  }
  
  func testRGB555() throws {
    let black = ARGB555(rawValue: 0x00);
    XCTAssertEqual(black.red, 0x00);
    XCTAssertEqual(black.green, 0x00);
    XCTAssertEqual(black.blue, 0x00);
    let white = ARGB555(red: 0x1f, green: 0x1f, blue: 0x1f);
    // Alpha bit will be set.
    XCTAssertEqual(white.rawValue, 0xffff);
    let red = ARGB555(red: 0x1f, green: 0x00, blue: 0x00);
    XCTAssertEqual(red.red, 0x1f);
    XCTAssertEqual(red.green, 0x00);
    XCTAssertEqual(red.blue, 0x00);
  }

  func testYuv() throws {
    let black = yuv2Rgb(y: 0.0, u: 0.0, v: 0.0);
    XCTAssertEqual(black.bytes, [0x00, 0x00, 0x00]);
    let white = yuv2Rgb(y: 255.0, u: 0.0, v: 0.0);
    XCTAssertEqual(white.bytes, [0xff, 0xff, 0xff]);
  }
}
