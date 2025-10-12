//
//  QuickTake.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 06.10.2025.
//
/// Class to handle QuickTake images
/// These are basically the raw camera data wrapped in QuickTime container in a PICT.

import Foundation

enum QuickTakeError: LocalizedError {
  case bitReadFailed;
}

private func sharpForDelta(_ v: Int) -> Int {
  switch v {
    case 0..<4: return 0
    case 4..<8: return 1
    case 8..<16: return 2
    case 16..<32: return 3
    case 32..<48: return 4
    default: return 5
  }
}

/// Decode the raw bit stream into an array of 10 bit values.
 func quickTake100Decode(bitStream: [UInt8], width: Int, height: Int) throws -> [Float] {
  // Lookup tables
  let gstep: [Int16] = [
    -89, -60, -44, -32, -22, -15, -8, -2,
     2, 8, 15, 22, 32, 44, 60, 89
  ]

  let rstep: [[Int16]] = [
    [-3, -1, 1, 3],
    [-5, -1, 1, 5],
    [-8, -2, 2, 8],
    [-13, -3, 3, 13],
    [-19, -4, 4, 19],
    [-28, -6, 6, 28]
  ]

  var reader = BitReader(data: bitStream)
  reader.skipBytes(12);

  // Work buffer with border to handle predictors.
  var pixel = Array(repeating: Array(repeating: UInt8(0x80), count: width + 4), count: height + 4)

  /// First data block: green pixels, disposition: ▚
  for row in 2..<(height + 2) {
    for col in stride(from: 2 + (row & 1), to: width + 2, by: 2) {
      guard let bits = reader.getbits(4) else { throw QuickTakeError.bitReadFailed }

      let pred = (
        Int(pixel[row - 1][col - 1]) +
        2 * Int(pixel[row - 1][col + 1]) +
        Int(pixel[row][col - 2])) / 4;
      let val = UInt8(clamping: pred + Int(gstep[bits]))
      pixel[row][col] = val;

      if col < 4 {
        pixel[row][col - 2] = val
        pixel[row + 1][~row & 1] = val
      }
      if row == 2 {
        pixel[row - 1][col + 1] = val
        pixel[row - 1][col + 3] = val
      }
    }
    pixel[row][width + 2] = pixel[row][width + 1]
  }

  /// Second data block: red/blue pixels, disposition:  ▞
  for redblue in 0..<2 {
    for row in stride(from: 2 + redblue, to: height + 2, by: 2) {
      for col in stride(from: 3 - (row & 1), to: width + 2, by: 2) {
        let sharp: Int
        if row < 4 || col < 4 {
          sharp = 2
        } else {
          let deltas =
          abs(Int(pixel[row - 2][col]) - Int(pixel[row][col - 2])) +
          abs(Int(pixel[row - 2][col]) - Int(pixel[row - 2][col - 2])) +
          abs(Int(pixel[row][col - 2]) - Int(pixel[row - 2][col - 2]))
          sharp = sharpForDelta(deltas);
        }

        guard let bits = reader.getbits(2) else { throw QuickTakeError.bitReadFailed }
        let pred = (Int(pixel[row - 2][col]) + Int(pixel[row][col - 2])) / 2;
        let val = UInt8(clamping: pred + Int(rstep[sharp][bits]));
        pixel[row][col] = val;
        if row < 4 {
          pixel[row - 2][col + 2] = val
        }
        if col < 4 {
          pixel[row + 2][col - 2] = val
        }
      }
    }
  }

  /// Green refinement
  for row in 2..<(height + 2) {
    for col in stride(from: 3 - (row & 1), to: width + 2, by: 2) {
      let left = Int(pixel[row][col - 1]);
      let center = Int(pixel[row][col]);
      let right = Int(pixel[row][col + 1]);

      // Weighted average without aggressive offset
      let val = (left + (center * 4) + right) / 2 - 0x100;
      pixel[row][col] = UInt8(clamping: val)
    }
  }

  let responseCurve: [UInt16] = [
    0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,
    28,29,30,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,53,
    54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,74,75,76,77,78,
    79,80,81,82,83,84,86,88,90,92,94,97,99,101,103,105,107,110,112,114,116,
    118,120,123,125,127,129,131,134,136,138,140,142,144,147,149,151,153,155,
    158,160,162,164,166,168,171,173,175,177,179,181,184,186,188,190,192,195,
    197,199,201,203,205,208,210,212,214,216,218,221,223,226,230,235,239,244,
    248,252,257,261,265,270,274,278,283,287,291,296,300,305,309,313,318,322,
    326,331,335,339,344,348,352,357,361,365,370,374,379,383,387,392,396,400,
    405,409,413,418,422,426,431,435,440,444,448,453,457,461,466,470,474,479,
    483,487,492,496,500,508,519,531,542,553,564,575,587,598,609,620,631,643,
    654,665,676,687,698,710,721,732,743,754,766,777,788,799,810,822,833,844,
    855,866,878,889,900,911,922,933,945,956,967,978,989,1001,1012,1023 ];

  /// Apply response curve and move into height × width buffer.
  var output = [Float](repeating: 0, count: width * height)
  for row in 0..<height {
    for col in 0..<width {
      let index = Int(pixel[row + 2][col + 2]);
      let v = Float(responseCurve[index]);
      output[row * width + col] = v / 1024;
    }
  }

  return output
}

func average(_ a: UInt8, _ b: UInt8) -> UInt8 {
  return UInt8(clamping: (Int(a) + Int(b)) / 2)
}


func convertCMYGToYuv(cmyg: [Float], width: Int, height: Int) -> YUV420Image {
  // let temperatureAdjutement = Float(0);
  let halfWidth = width / 2
  let halfHeight = height / 2
  var yPlane = Array<UInt8>(repeating: 0, count: width * height)
  var uPlane = Array<UInt8>(repeating: 0, count: halfWidth * halfHeight)
  var vPlane = Array<UInt8>(repeating: 0, count: halfWidth * halfHeight)

  for row in stride(from: 0, to: height, by: 2) {
    for col in stride(from: 0, to: width, by: 2) {
      let offset = (row * width) + col;
      let green = cmyg[offset];
      let magenta = cmyg[offset + 1];
      let cyan = cmyg[offset + width];
      let yellow = cmyg[offset + width + 1];

      let luma = (green + magenta + cyan + yellow) / 4;

      let r = (magenta + yellow - luma).clampToUnit;
      let g = (cyan + yellow - luma).clampToUnit;
      let b = (cyan + magenta - luma).clampToUnit;

      let average_green = (g + green) / 2;

      // Get U/V for the block
      let (_, u, v) = rgb2Yuv(
        r: r, g: average_green, b: b);
      // Use raw sensor values as luminance
      yPlane[offset] = green.normalizedByte;
      yPlane[offset + 1] = magenta.normalizedByte;
      yPlane[offset + width] = cyan.normalizedByte;
      yPlane[offset + width + 1] = yellow.normalizedByte;
      let halfOffset = (row / 2 * halfWidth) + (col / 2)
      uPlane[halfOffset] = u;
      vPlane[halfOffset] = v;
    }
  }
  let yCorrected = boostShadowsSelective(yPlane, strength: 1.5, threshold: 64);
  return YUV420Image(width: width, height: height, yPlane: yCorrected, uPlane: uPlane, vPlane: vPlane)
}

func decodeQTKND(dimensions: QDDelta, data : Data) throws -> YUV420Image {
  let width = dimensions.dh.rounded;
  let height = dimensions.dv.rounded;
  let raw = try quickTake100Decode(bitStream: data.bytes, width: width , height: height);
  return convertCMYGToYuv(cmyg: raw, width: width, height: height);
}






