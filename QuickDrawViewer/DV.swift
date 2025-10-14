//
//  DV.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 07.07.2025.
//

import Foundation
import CoreMedia
import VideoToolbox



// Generic decoder that uses Core Video to decode one video frame.
class DVImage : PixMapMetadata, @unchecked Sendable {

  init(codec: MacTypeCode, dimensions : QDDelta) throws {
    self.codec = codec;
    self.dimensions = dimensions;
    self.pixmap = [];
    let status = CMVideoFormatDescriptionCreate(
      allocator: nil, codecType: codec.rawValue,
        width: Int32(dimensions.dh.rounded), height: Int32(dimensions.dv.rounded),
      extensions: nil, formatDescriptionOut: &formatDescription);
    guard status == 0 else {
      throw NSError(domain: "CMVideoFormatDescriptionCreate", code: Int(status), userInfo: nil);
    }
  }

  let codec: MacTypeCode;
  let dimensions: QDDelta;
  var rowBytes: Int = 0;
  let cmpSize: Int = 8;
  let pixelSize: Int = 24;
  var clut: QDColorTable? = nil;
  var pixmap : [UInt8];
  var formatDescription : CMFormatDescription? = nil;

  var description: String {
    return "Video \(codec)} " + describePixMap(self);
  }

  func load(data : consuming Data) throws {
    var session : VTDecompressionSession?;
    let decoderSpec : [NSString: NSObject]  = [:];
    let imageSpec = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_24RGB];
    let sessionStatus = VTDecompressionSessionCreate(
      allocator: nil, formatDescription: formatDescription!,
      decoderSpecification: decoderSpec as CFDictionary,
      imageBufferAttributes: imageSpec as CFDictionary,
      outputCallback: nil, decompressionSessionOut: &session);
    guard sessionStatus == 0 else {
      throw NSError(domain: "VTDecompressionSessionCreate", code: Int(sessionStatus), userInfo: nil);
    }
    let sampleSizeArray = [data.count]
    let blockBuffer = try createCMBlockBuffer(from: data);
    var sampleBuffer: CMSampleBuffer?;
    let bufferStatus = CMSampleBufferCreateReady(
        allocator: kCFAllocatorDefault, dataBuffer: blockBuffer,
        formatDescription: formatDescription, sampleCount: 1,
        sampleTimingEntryCount: 0, sampleTimingArray: nil, 
        sampleSizeEntryCount: 1, sampleSizeArray: sampleSizeArray, sampleBufferOut: &sampleBuffer)
    guard bufferStatus == 0 else {
      throw NSError(domain: "CMSampleBufferCreateReady", code: Int(bufferStatus), userInfo: nil);
    }
    let decodeFlags = VTDecodeFrameFlags();
    var decodeInfoFlags = VTDecodeInfoFlags();
    let outputHandler : VTDecompressionOutputHandler = {_, _, buffer, _ , _ in
      guard let b = buffer else {
        return;
      }
      let pixelBuffer = b as CVPixelBuffer;
      self.rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
      let lockFlags = CVPixelBufferLockFlags(rawValue: 0);
      CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags);
      let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
      let size = CVPixelBufferGetDataSize(pixelBuffer);
      let bufferPtr = baseAddress!.bindMemory(to: UInt8.self, capacity: size);
      let buffer = UnsafeBufferPointer(start: bufferPtr, count: size);
      self.pixmap = Array(buffer);
      CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags);
    }
    let decodeStatus = VTDecompressionSessionDecodeFrame(session!, sampleBuffer: sampleBuffer!, flags:decodeFlags, infoFlagsOut: &decodeInfoFlags, outputHandler: outputHandler);
    guard decodeStatus == 0 else {
      throw NSError(domain: "VTDecompressionSessionDecodeFrame", code: Int(decodeStatus), userInfo: nil);
    }
  }
}
