//
//  MacPaint.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 29.02.2024.
//
// Decoder for the MacPaint QuickTime codec.
// As well as support for loading MacPaint files by converting them to pictures.

import Foundation

/// MacPaint images are fixed size (720 × 576) PackBit compressed bitmaps.
class MacPaintImage : PixMapMetadata {
  
  func load(data : Data) throws {
    self.bitmap = try DecompressPackBit(data: Array(data), unpackedSize: 720 * 72);
  }
  
  /// Convert the MacPaint images into an opcode.
  /// This could be a QuickTime opcode that embeds the MacPaint data, but
  /// this is very involved, instead we just build a `BitRectOpcode`.
  func makeOpcode() -> some OpCode {
    let bitRect = BitRectOpcode(isPacked: true);
    bitRect.bitmapInfo.rowBytes = self.rowBytes;
    let frame = QDRect(topLeft: .zero, dimension: self.dimensions);
    bitRect.bitmapInfo.bounds = frame;
    bitRect.bitmapInfo.srcRect = frame;
    bitRect.bitmapInfo.dstRect = frame;
    bitRect.bitmapInfo.data = bitmap;
    return bitRect;
  }
  
  /// Convert a MacPaint images into a minimalistic picture.
  /// This is enough for this program, but a valid quickdraw file would have some header operations.
  func macPicture(filename: String?) -> QDPicture {
    let frame = QDRect(topLeft: .zero, dimension: self.dimensions);
    let picture = QDPicture(size: -1, frame: frame, filename: filename);
    picture.opcodes.append(makeOpcode());
    return picture;
  }
  
  let rowBytes: Int = 72; // 576 ÷ 8
  var cmpSize: Int = 1;
  var pixelSize: Int = 1;
  let dimensions = QDDelta(dv: FixedPoint(720), dh: FixedPoint(576));
  var clut: QDColorTable? = QDColorTable.palette1;
  var bitmap: [UInt8] = [];
  
  var description: String {
    let pm = describePixMap(self);
    return "MacPaint: \(pm)";
  }
  
}
