//
//  QuickDrawViewerTests.swift
//  QuickDrawViewerTests
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import XCTest

// @testable import QuickDrawViewer

final class QuickDrawTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFixedPoint() throws {
      XCTAssertEqual(FixedPoint.zero.rounded, 0);
      XCTAssertTrue(FixedPoint.zero.isRound);
      XCTAssertEqual(FixedPoint.zero, FixedPoint.zero);
      XCTAssertEqual(FixedPoint.one.rounded, 1);
      XCTAssertTrue(FixedPoint.one.isRound);
      XCTAssertEqual(FixedPoint.one, FixedPoint.one);
      XCTAssertLessThan(FixedPoint.zero, FixedPoint.one);
      let fzero = FixedPoint(0.0);
      XCTAssertEqual(fzero, FixedPoint.zero);
      XCTAssertTrue(fzero.isRound);
      let fone = FixedPoint(1.0);
      XCTAssertEqual(fone, FixedPoint.one);
      XCTAssertTrue(fone.isRound);
      let eight = FixedPoint(3) + FixedPoint(5);
      XCTAssertTrue(eight.isRound);
      XCTAssertEqual(eight, FixedPoint(8));
      XCTAssertEqual(eight - FixedPoint.one, FixedPoint(7));
      XCTAssertEqual(-eight, FixedPoint(-8));
      XCTAssertEqual((FixedPoint.one << 3), eight);
      XCTAssertEqual((FixedPoint(256) >> 4), FixedPoint(16));
      let half = FixedPoint(0.5);
      XCTAssertEqual(half, FixedPoint.one >> 1);
      
      XCTAssertEqual(half, FixedPoint.one / FixedPoint(2));
      XCTAssertEqual(half, FixedPoint(100) / FixedPoint(200));
    }
  
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
  }
  
  func testmakeUInt24() throws {
    XCTAssertEqual(makeUInt24(bytes: (0xff, 0xff, 0xff)), 0xffffff);
    XCTAssertEqual(makeUInt24(bytes: (0x00, 0x00, 0x00)), 0x000000);
    XCTAssertEqual(makeUInt24(bytes: (0x10, 0x00, 0x00)), 0x100000);
    XCTAssertEqual(makeUInt24(bytes: (0xab, 0xcd, 0xef)), 0xabcdef);
  }
  
  func testColor() throws {
    XCTAssertEqual(QDColor.black.rgb, [0x00, 0x00, 0x00]);
    XCTAssertEqual(QDColor.red.rgb, [0xff, 0x00, 0x00]);
    XCTAssertEqual(QDColor.green.rgb, [0x00, 0xff, 0x00]);
    XCTAssertEqual(QDColor.blue.rgb, [0x00, 0x00, 0xff]);
    XCTAssertEqual(
      QDColor.blend(a: QDColor.black, b: QDColor.white, aWeight: 0.5),
      QDColor(red: 0x7fff, green: 0x7fff, blue: 0x7fff));
    XCTAssertEqual(
      QDColor.blend(a: QDColor.black, b: QDColor.white, aWeight: 1.0),
      QDColor.black);
    XCTAssertEqual(
      QDColor.blend(a: QDColor.black, b: QDColor.white, aWeight: 0.0),
      QDColor.white);
    XCTAssertEqual(QDColor.cyan.rawValue, 0x0000ffffffff);
  }
  
  func testPackBit() throws {
    // Discrete run
    let discreteData : [UInt8] = [0x05, 0x01, 0x02, 0x03, 0x04, 0x5, 0x6];
    XCTAssertEqual(
        try DecompressPackBit(data: discreteData, unpackedSize: 6),
        [0x01, 0x02, 0x03, 0x04, 0x5, 0x6]);
    let repeatedData : [UInt8] = [UInt8(bitPattern: Int8(-6)), 0x10];
    XCTAssertEqual(
        try DecompressPackBit(data: repeatedData, unpackedSize: 7),
        [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10]);
  }

  func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
  }

}
