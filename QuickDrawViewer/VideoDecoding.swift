//
//  VideoDecoding.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 14.10.2025.
//

import VideoToolbox
import CoreGraphics
import CoreVideo

func createCMBlockBuffer(from data: Data) throws -> CMBlockBuffer  {
  var blockBuffer: CMBlockBuffer?

  // Convert Data to a byte pointer
  let dataPointer = UnsafeMutableRawPointer(mutating: (data as NSData).bytes)
  let dataLength = data.count

  // Create a CMBlockBuffer
  let status = CMBlockBufferCreateWithMemoryBlock(
    allocator: kCFAllocatorDefault,
    memoryBlock: dataPointer,
    blockLength: dataLength,
    blockAllocator: kCFAllocatorNull,
    customBlockSource: nil,
    offsetToData: 0,
    dataLength: dataLength,
    flags: 0,
    blockBufferOut: &blockBuffer
  )

  guard status == kCMBlockBufferNoErr else {
    throw NSError(domain: "CMBlockBufferCreateWithMemoryBlock", code: Int(status), userInfo: nil);
  }
  return blockBuffer!
}

// MARK: - Yuv image to CG Image logic
extension YUV420Image {
  func toCGImage() -> CGImage? {
    // Create CVPixelBuffer from YUV planes
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_420YpCbCr8Planar,
      nil,
      &pixelBuffer
    )

    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    // Copy Y plane
    let yDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
    let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    yPlane.withUnsafeBytes { yPtr in
      for row in 0..<height {
        let srcOffset = row * width
        let dstOffset = row * yBytesPerRow
        memcpy(yDest!.advanced(by: dstOffset), yPtr.baseAddress!.advanced(by: srcOffset), width)
      }
    }

    // Copy U plane
    let uDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
    let uBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
    uPlane.withUnsafeBytes { uPtr in
      for row in 0..<(height / 2) {
        let srcOffset = row * (width / 2)
        let dstOffset = row * uBytesPerRow
        memcpy(uDest!.advanced(by: dstOffset), uPtr.baseAddress!.advanced(by: srcOffset), width / 2)
      }
    }

    // Copy V plane
    let vDest = CVPixelBufferGetBaseAddressOfPlane(buffer, 2)
    let vBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 2)
    vPlane.withUnsafeBytes { vPtr in
      for row in 0..<(height / 2) {
        let srcOffset = row * (width / 2)
        let dstOffset = row * vBytesPerRow
        memcpy(vDest!.advanced(by: dstOffset), vPtr.baseAddress!.advanced(by: srcOffset), width / 2)
      }
    }

    // Convert CVPixelBuffer to CGImage
    var cgImage: CGImage?
    VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)

    return cgImage
  }
}
