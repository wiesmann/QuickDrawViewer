//
//  QuickDrawViewerTests.swift
//  QuickDrawViewerTests
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import XCTest


final class BitTests : XCTestCase {
  func testboolArray() throws {
    XCTAssertEqual(
      boolArray(UInt8(0xff)), [true, true, true, true, true, true, true, true]);
    XCTAssertEqual(
      boolArray(UInt8(0x00)), [false, false, false, false, false, false, false, false]);
    XCTAssertEqual(
      boolArray(UInt8(0xc0)), [true, true, false, false, false, false, false, false]);
  }
  
  func testmakeUInt24() throws {
    XCTAssertEqual(makeUInt24(bytes: (0xff, 0xff, 0xff)), 0xffffff);
    XCTAssertEqual(makeUInt24(bytes: (0x00, 0x00, 0x00)), 0x000000);
    XCTAssertEqual(makeUInt24(bytes: (0x10, 0x00, 0x00)), 0x100000);
    XCTAssertEqual(makeUInt24(bytes: (0xab, 0xcd, 0xef)), 0xabcdef);
  }
  
  func testRoundTo() throws {
    XCTAssertEqual(roundTo(FixedPoint.one, multipleOf: 4), 4);
    XCTAssertEqual(roundTo(FixedPoint(10), multipleOf: 4), 12);
    XCTAssertEqual(roundTo(FixedPoint(11), multipleOf: 4), 12);
  }
  
  func testToScalar() throws {
    let bytes : [UInt8] = [0xff, 0xf0, 0x00, 0x0f];
    let value : UInt32 = toScalar(bytes: bytes[...]);
    XCTAssertEqual(value, UInt32(0xfff0000f));
  }
}

final class FixedPointTests : XCTestCase {
  
  func testBasic() throws {
    XCTAssertEqual(FixedPoint.zero.rounded, 0);
    XCTAssertTrue(FixedPoint.zero.isRound);
    XCTAssertEqual(FixedPoint.zero, FixedPoint.zero);
    XCTAssertEqual(FixedPoint.one.rounded, 1);
    XCTAssertTrue(FixedPoint.one.isRound);
    XCTAssertEqual(FixedPoint.one, FixedPoint.one);
    XCTAssertLessThan(FixedPoint.zero, FixedPoint.one);
    
  }
  
  func testFloag() throws {
    let fzero = FixedPoint(0.0);
    XCTAssertEqual(fzero, FixedPoint.zero);
    XCTAssertTrue(fzero.isRound);
    let fone = FixedPoint(1.0);
    XCTAssertEqual(fone, FixedPoint.one);
    XCTAssertTrue(fone.isRound);
  }
  
  func testAdd() throws {
    let eight = FixedPoint(3) + FixedPoint(5);
    XCTAssertTrue(eight.isRound);
    XCTAssertEqual(eight, FixedPoint(8));
    XCTAssertEqual(eight - FixedPoint.one, FixedPoint(7));
    XCTAssertEqual(-eight, FixedPoint(-8));
  }
  
  func testShift() throws {
    let eight = FixedPoint(8);
    XCTAssertEqual((FixedPoint.one << 3), eight);
    XCTAssertEqual((FixedPoint(256) >> 4), FixedPoint(16));
    let half = FixedPoint(0.5);
    XCTAssertEqual(half, FixedPoint.one >> 1);
  }

  func testMultiply() throws {
    XCTAssertEqual(FixedPoint.one * FixedPoint.one, FixedPoint.one);
    XCTAssertEqual(FixedPoint.zero * FixedPoint.one, FixedPoint.zero);
    XCTAssertEqual(FixedPoint.one * FixedPoint.zero, FixedPoint.zero);
    XCTAssertEqual(FixedPoint.zero * FixedPoint.zero, FixedPoint.zero);
    XCTAssertEqual(FixedPoint(3) * FixedPoint(5), FixedPoint(15));
  }

  func testDivide() throws {
    let half = FixedPoint(0.5);
    XCTAssertEqual(half, FixedPoint.one / FixedPoint(2));
    XCTAssertEqual(half, FixedPoint(100) / FixedPoint(200));
  }
  
  func testFixedPointRaw() throws  {
    XCTAssertEqual(FixedPoint(rawValue: 0), FixedPoint.zero);
    XCTAssertEqual(FixedPoint(rawValue: 0x8000), FixedPoint(1) / FixedPoint(2));
    // Quarters
    XCTAssertEqual(FixedPoint(rawValue: 0x4000), FixedPoint(1) / FixedPoint(4));
    XCTAssertEqual(FixedPoint(rawValue: 0xc000), FixedPoint(3) / FixedPoint(4));
    // Eights
    XCTAssertEqual(FixedPoint(rawValue: 0x2000), FixedPoint(1) / FixedPoint(8));
    XCTAssertEqual(FixedPoint(rawValue: 0x6000), FixedPoint(3) / FixedPoint(8));
    XCTAssertEqual(FixedPoint(rawValue: 0xA000), FixedPoint(5) / FixedPoint(8));
    XCTAssertEqual(FixedPoint(rawValue: 0xE000), FixedPoint(7) / FixedPoint(8));
    // Sixteenths
    XCTAssertEqual(FixedPoint(rawValue: 0x1000), FixedPoint(1) / FixedPoint(16));
  }
}

final class QDGeometryTests: XCTestCase {
  
  func testDelta() throws {
    XCTAssertEqual(QDDelta.zero, QDDelta.zero);
    XCTAssertEqual(QDDelta.zero, -QDDelta.zero);
    XCTAssertEqual(QDDelta.zero, QDDelta.zero + QDDelta.zero);
    XCTAssertEqual(QDDelta.zero, QDDelta.zero - QDDelta.zero);
    let one = QDDelta(dv: FixedPoint.one, dh: FixedPoint.one);
    XCTAssertEqual(QDDelta.zero + one, one);
    XCTAssertEqual(one + QDDelta.zero, one);
    XCTAssertEqual(QDDelta.zero - one, -one);
    XCTAssertEqual(one - QDDelta.zero, one);
    XCTAssertEqual(one - one, QDDelta.zero);
    XCTAssertEqual(QDDelta(dv: FixedPoint(3), dh: FixedPoint(5)) + one,
                   QDDelta(dv: FixedPoint(4), dh: FixedPoint(6)));
  }
  
  func testPointAndDelta() throws {
    XCTAssertEqual(QDPoint.zero.vertical, FixedPoint.zero);
    XCTAssertEqual(QDPoint.zero.horizontal, FixedPoint.zero);
    let p = QDPoint(vertical: FixedPoint(5), horizontal: FixedPoint(7));
    XCTAssertEqual(p, p);
    XCTAssertEqual(p + QDDelta.zero, p);
    XCTAssertEqual(p - QDDelta.zero, p);
    let d = QDDelta(dv: FixedPoint(3), dh: FixedPoint(11));
    let s = p + d;
    XCTAssertEqual(s.vertical, FixedPoint(8));
    XCTAssertEqual(s.horizontal, FixedPoint(18));
    XCTAssertEqual(s - d, p);
  }
  
  func testRects() throws {
    let p1 = QDPoint(vertical: FixedPoint(16), horizontal: FixedPoint(32));
    let p2 = QDPoint(vertical: FixedPoint(256), horizontal: FixedPoint(512));
    let r = QDRect(topLeft: p1, bottomRight:  p2);
    XCTAssertEqual(r, r);
    XCTAssertNotEqual(r, QDRect.empty);
    XCTAssertFalse(r.isEmpty);
    XCTAssertNotEqual(r, QDRect.empty);
    XCTAssertTrue(QDRect.empty.isEmpty);
    // Dimensions
    XCTAssertEqual(r.dimensions.dh.value, 480, "\(r.dimensions)");
    XCTAssertEqual(r.dimensions.dv.value, 240, "\(r.dimensions)");
    XCTAssertEqual(QDRect.empty.dimensions, QDDelta.zero);
    // Center
    XCTAssertEqual(r.center.horizontal.value, 272, "\(r.center)");
    XCTAssertEqual(r.center.vertical.value, 136, "\(r.center)");
    XCTAssertEqual(QDRect.empty.center, QDPoint.zero);
  }
  
  func testRenderAngles() throws {
    XCTAssertEqual(deg2rad(0),  -0.5 *  .pi);
    XCTAssertEqual(deg2rad(90), -.pi);
    XCTAssertEqual(deg2rad(180),  -1.5 * .pi);
    XCTAssertEqual(deg2rad(270),  -0.0);
  }
  
}




