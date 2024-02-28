//
//  QuickTime.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 04.02.2024.
//

/// Utility code to handle QuickTime related data.
/// This basically implements two basic functionalities:
/// * Handling of QuickTime opcodes in QuickDraw images.
/// * Handling of QuickTime image files `QTIF`

/// https://github.com/phracker/MacOSX-SDKs/blob/master/MacOSX10.8.sdk/System/Library/Frameworks/QuickTime.framework/Versions/A/Headers/ImageCompression.h
/// https://github.com/TheDiamondProject/Graphite/blob/aa6636a1fe09eb2439e4972c4501724b3282ac7c/libGraphite/quicktime/planar.cpp

/*
 (
     "public.jpeg",
     "public.png",
     "com.compuserve.gif",
     "com.canon.tif-raw-image",
     "com.adobe.raw-image",
     "com.dxo.raw-image",
     "com.canon.cr2-raw-image",
     "com.canon.cr3-raw-image",
     "com.leafamerica.raw-image",
     "com.hasselblad.fff-raw-image",
     "com.hasselblad.3fr-raw-image",
     "com.nikon.raw-image",
     "com.nikon.nrw-raw-image",
     "com.pentax.raw-image",
     "com.samsung.raw-image",
     "com.sony.raw-image",
     "com.sony.sr2-raw-image",
     "com.sony.arw-raw-image",
     "com.epson.raw-image",
     "com.kodak.raw-image",
     "public.tiff",
     "public.jpeg-2000",
     "com.apple.atx",
     "org.khronos.astc",
     "org.khronos.ktx",
     "public.avci",
     "public.heic",
     "public.heics",
     "public.heif",
     "com.canon.crw-raw-image",
     "com.fuji.raw-image",
     "com.panasonic.raw-image",
     "com.panasonic.rw2-raw-image",
     "com.leica.raw-image",
     "com.leica.rwl-raw-image",
     "com.konicaminolta.raw-image",
     "com.olympus.sr-raw-image",
     "com.olympus.or-raw-image",
     "com.olympus.raw-image",
     "com.phaseone.raw-image",
     "com.microsoft.ico",
     "com.microsoft.bmp",
     "com.apple.icns",
     "com.adobe.photoshop-image",
     "com.microsoft.cur",
     "com.truevision.tga-image",
     "com.ilm.openexr-image",
     "org.webmproject.webp",
     "com.sgi.sgi-image",
     "public.radiance",
     "public.pbm",
     "public.mpo-image",
     "public.pvr",
     "com.microsoft.dds",
     "com.apple.pict"
 )
 (
     "public.jpeg",
     "public.png",
     "com.compuserve.gif",
     "public.tiff",
     "public.jpeg-2000",
     "com.apple.atx",
     "org.khronos.ktx",
     "org.khronos.astc",
     "com.microsoft.dds",
     "public.heic",
     "public.heics",
     "com.microsoft.ico",
     "com.microsoft.bmp",
     "com.apple.icns",
     "com.adobe.photoshop-image",
     "com.adobe.pdf",
     "com.truevision.tga-image",
     "com.ilm.openexr-image",
     "public.pbm",
     "public.pvr"
 )

 
 */


import os
import Foundation

enum QuickTimeError: LocalizedError {
  case missingQuickTimePayload(quicktimeOpcode: QuickTimeOpcode);
  case missingQuickTimeData(quicktimeImage: QuickTimeIdsc);
  case corruptQuickTimeAtomLength(length: Int);
  case missingQuickTimePart(code: MacTypeCode);
}

// Representation of a converted image
struct ConvertedImageMeta : PixMapMetadata {
  let rowBytes: Int;
  let cmpSize: Int;
  let pixelSize: Int;
  let dimensions: QDDelta;
  let clut: QDColorTable?;
}

enum QuickTimePictureDataStatus {
  case unchanged;
  case patched;
  case decoded(decodedMetaData: PixMapMetadata);
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
  
  static let identityTransform = [
    [FixedPoint.one, FixedPoint.zero, FixedPoint.zero],
    [FixedPoint.zero, FixedPoint.one, FixedPoint.zero],
    [FixedPoint.zero, FixedPoint.zero, FixedPoint(16384)]];
}

func patchQuickTimeBMP(quicktimeImage : inout QuickTimeIdsc) throws {
  guard let data = quicktimeImage.data else {
    throw QuickTimeError.missingQuickTimeData(quicktimeImage: quicktimeImage);
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
    throw QuickTimeError.missingQuickTimeData(quicktimeImage: quicktimeImage);
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
      clut: nil);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata)
  case "rpza":
    let rpza = RoadPizzaImage(dimensions: quicktimeImage.dimensions);
    try rpza.load(data: data);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: rpza);
    quicktimeImage.data = Data(rpza.pixmap);
  case "yuv2":
    let rgb = convertYuv2Data(data: data);
    let metadata = ConvertedImageMeta(
      rowBytes: quicktimeImage.dimensions.dh.rounded * 3,
      cmpSize: 8,
      pixelSize: 24,
      dimensions: quicktimeImage.dimensions,
      clut: nil);
    quicktimeImage.dataStatus = .decoded(decodedMetaData: metadata);
    quicktimeImage.data = Data(rgb);
  case "8BPS":
    let planar = try PlanarImage(dimensions: quicktimeImage.dimensions, depth: quicktimeImage.depth, clut: quicktimeImage.clut);
    try planar.load(data: data);
    let rgb = planar.pixmap;
    quicktimeImage.dataStatus = .decoded(decodedMetaData: planar);
    quicktimeImage.data = Data(rgb);
    break;
  case "mjp2":
    // JPEG-2000 is a QuickTime node so we skip size + type.
    let skipped = data.subdata(in: 8..<data.count);
    quicktimeImage.dataStatus = .patched;
    quicktimeImage.data = skipped;
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
  case "mjp2":
    return "public.jpeg-2000";
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
    do {
      let atomReader = try subReader.subReader(bytes: quicktimePayload.idsc.idscSize - 86);
      try parseQuickTimeStream(reader: atomReader, quicktimePayload: &quicktimePayload);
    } catch {
      print("Failed atom parsing: \(error)");
    }
   
    quicktimePayload.idsc.data = try subReader.readData(bytes: subReader.remaining);
    try patchQuickTimeImage(quicktimeImage: &quicktimePayload.idsc);
  }
  
  var opcodeVersion : Int16 = 0;
  var dataSize : Int = 0;
  var matteSize : Int = 0;
  var maskSize : Int = 0;
  var quicktimePayload : QuickTimePayload = QuickTimePayload();
}

func parseQuickTimeStream(reader: QuickDrawDataReader, quicktimePayload: inout QuickTimePayload ) throws  {
  var quickTimeIdsc : QuickTimeIdsc?;
  var quickTimeIdat : Data?;
  
  while reader.remaining > 8 {
    let length = Int(try reader.readInt32()) - 8;
    guard length >= 0 else {
      throw QuickTimeError.corruptQuickTimeAtomLength(length: length);
    }
    let type = try reader.readType();
    let data = try reader.readData(bytes: length);
    switch type.description {
    case "idsc":
      let subReader = try QuickDrawDataReader(data: data, position: 0);
      quickTimeIdsc = try subReader.readQuickTimeIdsc();
    case "idat":
      quickTimeIdat = data
    default:
      print("Ignoring QuickTime atom \(type): \(length) bytes");
      break;
    }
  }
  if let idsc = quickTimeIdsc {
    quicktimePayload.idsc = idsc;
  }
  if let idat = quickTimeIdat {
    quicktimePayload.idsc.data = idat;
  }
}

/// Parse a QuickTime image into a QuickDraw picture.
/// This will fail if the QuickTime image does not have an `idsc` (image description) atom.
/// - Parameter reader: reader pointing to the data.
/// - Throws: if data is corrupt / unreadable
/// - Returns: a _fake_ QuickDraw image with a single QuickTime opcode.
func parseQuickTimeImage(reader: QuickDrawDataReader) throws -> QDPicture {
  let fileSize = reader.remaining;
  var payload = QuickTimePayload();
  payload.transform = QuickTimePayload.identityTransform;
  try parseQuickTimeStream(reader: reader, quicktimePayload: &payload);
  try patchQuickTimeImage(quicktimeImage: &payload.idsc);
  let frame = QDRect(topLeft: QDPoint.zero, dimension: payload.idsc.dimensions);
  let destination = QDRegion.forRect(rect: frame);
  payload.srcMask = destination;
  let picture = QDPicture(size: fileSize, frame: frame, filename: reader.filename);
  picture.version = 0xff;
  var opcode = QuickTimeOpcode();
  opcode.quicktimePayload = payload;
  picture.opcodes.append(opcode);
  return picture;
}
