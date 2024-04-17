//
//  Yuv2.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 31.01.2024.
//
// Decoder for the QuickTime `yuv2` codec.

import Foundation
import CoreGraphics

/// It would be nice to use something like the accelerate framework to decode this.
/// Sadly this particular version uses _signed_ int8 for u and v, not a cut-off of 128.
/// So we code it explicitely. 
func signedYuv2Rgb(y: UInt8, u: UInt8, v: UInt8) -> RGB8 {
  let nu = Double(Int8(bitPattern: u));
  let nv = Double(Int8(bitPattern: v));
  let ny = Double(y);
  return yuv2Rgb(y: ny, u: nu, v: nv);
}

func convertYuv2Data(data: Data) -> [UInt8] {
  var rgb : [UInt8] = [];
  let pixelPairCount = data.count / 4;
  for i in 0..<pixelPairCount {
    let start = i * 4;
    let y1 = data[start];
    let u  = data[start + 1];
    let y2 = data[start + 2];
    let v  = data[start + 3];
    rgb.append(contentsOf: signedYuv2Rgb(y:y1, u:u, v:v));
    rgb.append(contentsOf: signedYuv2Rgb(y:y2, u:u, v:v));
  }
  return rgb;
}

