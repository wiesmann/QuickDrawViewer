//
//  QuickTime.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 04.02.2024.
//

/// Utility code to handle QuickTime images embedded inside QuickDraw pictures.

/// https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.8.sdk/System/Library/Frameworks/QuickTime.framework/Versions/A/Headers/ImageCompression.h
/// https://github.com/TheDiamondProject/Graphite/blob/aa6636a1fe09eb2439e4972c4501724b3282ac7c/libGraphite/quicktime/planar.cpp

import Foundation

struct ConvertedImageMeta : PixMapMetadata {
  let rowBytes: Int;
  let cmpSize: Int;
  let pixelSize: Int;
  let dimensions: QDDelta;
  let colorTable: QDColorTable?;
}

enum QuickTimePictureDataStatus {
  case unchanged;
  case patched;
  case decoded(decodedMetaData: ConvertedImageMeta);
}

class QuickTimeIdsc : CustomStringConvertible {
  var description: String {
    var result = "codec: '\(codecType)': compressor: '\(compressorDevelopper)'";
    result += " compressionName: '\(compressionName)'";
    result += " version \(imageVersion).\(imageRevision)";
    result += " dimensions: \(dimensions), resolution: \(resolution)";
    result += " frameCount: \(frameCount), depth: \(depth)";
    result += " temporalQuality: \(temporalQuality) spatialQuality: \(spatialQuality)"
    result += " clutId: \(clutId) dataSize: \(dataSize) idscSize: \(idscSize)";
    result += " data status: \(dataStatus)";
    if let d = data {
      let subdata = d.subdata(in: 0..<16);
      result += " Magic: "
      result += subdata.map{ String(format:"%02x", $0) }.joined()
      result += " (\(d.count) bytes)"
    }
    return result;
  }
  
  var codecType : MacTypeCode = MacTypeCode.zero;
  var imageVersion : Int = 0;
  var imageRevision : Int = 0;
  var compressorDevelopper : MacTypeCode = MacTypeCode.zero;
  var temporalQuality : UInt32 = 0;
  var spatialQuality : UInt32 = 0;
  var dimensions : QDDelta = QDDelta.zero;
  var resolution : QDResolution = QDResolution.defaultResolution;
  var dataSize : Int = 0;
  var frameCount : Int = 0;
  var compressionName : String = "";
  var depth : Int = 0;
  var clutId : Int = 0;
  var idscSize : Int = 0;
  var data : Data?;
  var dataStatus : QuickTimePictureDataStatus = QuickTimePictureDataStatus.unchanged;
  
  var clut : QDColorTable? {
    return QDColorTable.forClutId(clutId: clutId);
  }
}

extension QuickDrawDataReader {
  func readQuickTimeIdsc() throws -> QuickTimeIdsc {
    let idsc = QuickTimeIdsc();
    idsc.idscSize = Int(try readUInt32());
    idsc.codecType = try readType();
    skip(bytes: 8);
    idsc.imageVersion = Int(try readUInt16());
    idsc.imageRevision = Int(try readUInt16());
    idsc.compressorDevelopper = try readType();
    idsc.temporalQuality = try readUInt32();  // 4
    idsc.spatialQuality = try readUInt32(); // 4
    idsc.dimensions = try readDelta();
    idsc.resolution = try readResolution();
    idsc.dataSize = Int(try readInt32());
    idsc.frameCount = Int(try readInt16());
    idsc.compressionName = try readStr31();
    idsc.depth = Int(try readInt16());
    idsc.clutId = Int(try readInt16());
    return idsc;
  }
}

class QuickTimePayload : CustomStringConvertible {
  
  public var description: String {
    var result = "QT Payload mode: \(mode)";
    if let mask = srcMask {
      result += " dstMask: \(mask)"
    }
    result += " transform: \(transform)";
    result += " matte: \(matte)"
    result += " idsc: \(idsc)";
    return result;
  }
  
  var transform : [[FixedPoint]] = [];
  var matte : QDRect = QDRect.empty;
  var mode : QuickDrawMode = QuickDrawMode.defaultMode;
  var srcMask : QDRegion?;
  var accuracy : Int = 0;
  
  var idsc : QuickTimeIdsc = QuickTimeIdsc();
}

func patchQuickTimeBMP(quicktimeImage : inout QuickTimeIdsc) throws {
  guard let data = quicktimeImage.data else {
    throw QuickDrawError.missingQuickTimeData(quicktimeImage: quicktimeImage);
  }
  var patched = Data();
  patched.append(contentsOf: [0x42, 0x4D]);
  let bmpHeaderSize : Int32 = 14;
  let dibHeaderSize : Int32 = 12;
  let headerSize = bmpHeaderSize + dibHeaderSize;
  let totalSize = headerSize + Int32(data.count);
  patched.append(contentsOf: byteArrayLE(from: totalSize));
  patched.append(contentsOf: [0x00, 0x00, 0x00, 0x00]);
  patched.append(contentsOf: byteArrayLE(from: headerSize));
  patched.append(contentsOf: byteArrayLE(from: dibHeaderSize));
  let width = Int16(quicktimeImage.dimensions.dh.rounded);
  let height = Int16(quicktimeImage.dimensions.dv.rounded);
  patched.append(contentsOf: byteArrayLE(from: width));
  patched.append(contentsOf: byteArrayLE(from: height));
  let planes = Int16(1);
  patched.append(contentsOf: byteArrayLE(from: planes));
  let depth = Int16(quicktimeImage.depth);
  patched.append(contentsOf: byteArrayLE(from: depth));
  assert(patched.count == headerSize);
  patched.append(data);
  quicktimeImage.data = patched;
  quicktimeImage.dataStatus = .patched;
}

/// Prepare the data in a QuickTime image for downstream processing.
/// * If the codec of the image can be handled by the system dowstream (core-image).
///   The data is just passed along, except in the case of Windows BMP where the headers need to be
///   reconstructed.
/// * If the codec of the image cannot be handled, this function will try to decode the image.
///   and replace the `data` field with the raw, decoded image.
/// The `dataStatus` field of the image describe in which case we are.
/// If the data was decoded, a header for rendering is populated within dataStatus.
/// If the data was in the `raw ` codec, the code sets the header as if were decoded, but the
/// raw data is left in place (it is technically already decoded). 
/// - Parameter quicktimeImage: <#quicktimeImage description#>
/// - Throws: <#description#>
func patchQuickTimeImage(quicktimeImage : inout QuickTimeIdsc) throws {
  guard let data = quicktimeImage.data else {
    throw QuickDrawError.missingQuickTimeData(quicktimeImage: quicktimeImage);
  }
  switch quicktimeImage.codecType.description {
  case "WRLE": 
    try patchQuickTimeBMP(quicktimeImage: &quicktimeImage);
  case "raw ":
    let metadata = ConvertedImageMeta(
      rowBytes: quicktimeImage.dimensions.dh.rounded * 4,
      cmpSize: 8,
      pixelSize: 32,
      dimensions: quicktimeImage.dimensions,
      colorTable: nil);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata)
  case "rpza":
    let rpza = RoadPizzaImage(dimensions: quicktimeImage.dimensions);
    try rpza.load(data: data);
    let metadata = ConvertedImageMeta(
      rowBytes: rpza.rowBytes,
      cmpSize: 5,
      pixelSize: 16,
      dimensions: quicktimeImage.dimensions,
      colorTable: nil);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata);
    quicktimeImage.data = Data(rpza.pixmap);
  case "yuv2":
    let rgb = convertYuv2Data(data: data);
    let metadata = ConvertedImageMeta(
      rowBytes: quicktimeImage.dimensions.dh.rounded * 3,
      cmpSize: 8,
      pixelSize: 24,
      dimensions: quicktimeImage.dimensions,
      colorTable: nil);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata);
    quicktimeImage.data = Data(rgb);
  case "8BPS":
    let planar = try PlanarImage(dimensions: quicktimeImage.dimensions, depth: quicktimeImage.depth);
    try planar.load(data: data);
    let rgb = planar.pixmap;
    let metadata = ConvertedImageMeta(
      rowBytes: planar.rowBytes,
      cmpSize: planar.cmpSize,
      pixelSize: planar.pixelSize,
      dimensions: planar.dimensions,
      colorTable: quicktimeImage.clut);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata);
    quicktimeImage.data = Data(rgb);
    break;
  default:
    break;
  }
}

/// Convert the codec of a QuickTime image into a type description.
/// Not strictly needed, as core-image seems to be able to guess types fines, but we have the data so.
///  Despite the fact that Preview can handle Targa files, CoreImage cannot.
/// - Parameter qtImage: image whose codec will be translated.
/// - Returns: a type description as used on OS X.
func codecToContentType(qtImage : QuickTimeIdsc) -> String {
  switch qtImage.codecType.description {
  case "tga ":
    return "com.truevision.tga-image";
  case "8BPS":
    return "com.adobe.photoshop-image";
  default:
    return "public." + qtImage.codecType.description.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}


struct QuickTimeOpcode : OpCode {
  mutating func load(reader: QuickDrawDataReader) throws {
    dataSize = Int(try reader.readInt32());
    let subReader = try reader.subReader(bytes: dataSize);
    opcodeVersion = try subReader.readInt16();
    for _ in 0..<3 {
      var line : [FixedPoint] = [];
      for _ in 0..<3 {
        line.append(try subReader.readFixed());
      }
      quicktimePayload.transform.append(line);
    }
    matteSize = Int(try subReader.readInt32());
    quicktimePayload.matte = try subReader.readRect();
    quicktimePayload.mode = QuickDrawMode(rawValue: try subReader.readUInt16());
    let srcRect = try subReader.readRect();
    quicktimePayload.accuracy = Int(try subReader.readUInt32());
    maskSize = Int(try subReader.readUInt32());
    // variable length parts
    reader.skip(bytes: matteSize);
    let maskData = try subReader.readUInt16(bytes: maskSize);
    let (rects, bitlines) = try DecodeRegionData(boundingBox: srcRect, data: maskData);
    quicktimePayload.srcMask = QDRegion(boundingBox: srcRect, rects: rects, bitlines: bitlines);
    quicktimePayload.idsc = try subReader.readQuickTimeIdsc();
    subReader.skip(bytes: quicktimePayload.idsc.idscSize - 86);
    quicktimePayload.idsc.data = try subReader.readData(bytes: subReader.remaining);
    try patchQuickTimeImage(quicktimeImage: &quicktimePayload.idsc);
  }
  
  var opcodeVersion : Int16 = 0;
  var dataSize : Int = 0;
  var matteSize : Int = 0;
  var maskSize : Int = 0;
  var quicktimePayload : QuickTimePayload = QuickTimePayload();
  
}
