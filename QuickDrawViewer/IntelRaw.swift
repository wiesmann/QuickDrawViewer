//
//  IntelRaw.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.04.2024.
//

import Foundation

func yuv2Rgb(y: UInt8, u: UInt8, v: UInt8) -> [UInt8] {
  let nu = Double(u) - 128;
  let nv = Double(v) - 128;
  let ny = Double(y);
  let r = Int(ny + (1.370705 * nv));
  let g = Int(ny - (0.698001 * nv) - 0.337633 * nu);
  let b = Int(ny + (1.732446 * nu));
  return [UInt8(clamping: r), UInt8(clamping: g), UInt8(clamping: b)];
}

/// The YVU9 is a planar format, in which U and V are sampled every 4 pixels horizontally
/// and vertically (sometimes referred to as 16:1:1). The V plane appears before the U plane.
class IntelRawImage : PixMapMetadata {
  
  init(dimensions : QDDelta) {
    let h = ((dimensions.dh.rounded + 3) / 4) * 4;
    let v = ((dimensions.dv.rounded + 3) / 4) * 4;
    self.dimensions = QDDelta(dv:v ,dh:h);
    self.rowBytes = 3 * h;
    self.pixmap = [];
  }
  
  func load(data : Data) throws {
    let lines = dimensions.dv.rounded;
    let columns = dimensions.dh.rounded;
    let ySize = lines * columns
    let yData = data[0..<ySize];
    let vuLines = (lines + 3) / 4;
    let vuColumns = (columns + 3) / 4;
    let vuSize = vuLines * vuColumns;
    let vData = data[ySize..<ySize+vuSize];
    let uData = data[ySize+vuSize..<ySize+vuSize*2];
    for l in 0..<lines {
      let vul = l / 4;
      for c in 0..<columns {
        let yOffset = l * columns + c + yData.startIndex;
        let y = yData[yOffset];
        let vuc = c / 4;
        let vuOffset = vul * vuColumns + vuc;
        let v = vData[vuOffset + vData.startIndex];
        let u = uData[vuOffset + uData.startIndex];
        let rgb =  yuv2Rgb(y: y, u: u, v: v)
        pixmap.append(contentsOf: rgb);
      }
    }
  }
  
  let dimensions: QDDelta;
  let rowBytes: Int;
  let cmpSize: Int = 8;
  let pixelSize: Int = 24;
  var clut: QDColorTable? = nil;
  var pixmap : [UInt8];
  
  var description: String {
    return "Intel Raw " + describePixMap(self);
  }
}
