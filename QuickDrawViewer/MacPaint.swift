//
//  MacPaint.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 29.02.2024.
//

import Foundation

// MacPaint images are fixed size (720 × 576) PackBit compressed bitmaps.
class MacPaintImage : PixMapMetadata {
  
  func load(data : Data) throws {
    self.bitmap = try DecompressPackBit(data: Array(data), unpackedSize: 720 * 72);
  }
  
  let rowBytes: Int = 72; // 576 ÷ 8
  var cmpSize: Int = 1;
  var pixelSize: Int = 1;
  let dimensions = QDDelta(dv: FixedPoint(720), dh: FixedPoint(576));
  var clut: QDColorTable? = QDColorTable.whiteBlack;
  var bitmap: [UInt8] = [];
  
}
