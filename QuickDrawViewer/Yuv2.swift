//
//  Yuv2.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 31.01.2024.
//

import Foundation
import CoreGraphics
import Accelerate
import VideoToolbox

// Use Core video to decode yuv2 format.
func ToCvPixelBuffer(_ data: Data, width: Int, height: Int) -> CVPixelBuffer {
  data.withUnsafeBytes { buffer in
    var pixelBuffer: CVPixelBuffer!
    // kCVPixelFormatType_422YpCbCr8_yuvs gets the image Y right, but UV are off.
    let pixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
    let result = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &pixelBuffer)
    guard result == kCVReturnSuccess else { fatalError() }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    
    let destRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
    let srcRowBytes = width * 2;
    
    let sourceStart = buffer.baseAddress!
    let destStart = CVPixelBufferGetBaseAddress(pixelBuffer)!;
    // Destination buffer is padded, copy each line to the right place.
    for line in 0..<height {
      let src = sourceStart + (srcRowBytes * line);
      let dest = destStart + (destRowBytes * line);
      memcpy(dest, src, srcRowBytes);
    }
    return pixelBuffer
  }
}

func convertYuv2(dimensions: QDDelta, data: Data) throws -> CGImage {
  let pixelBuffer = ToCvPixelBuffer(
      data, width: dimensions.dh.rounded, height: dimensions.dv.rounded);
  var cgImage: CGImage?;
  VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage);
  return cgImage!;
}
