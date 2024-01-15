//
//  QuickDrawReader.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 20.12.2023.
//

import Foundation

/// Class that handles reading from the data object.
/// Handles deserialisation of various QuickDraw types.
class QuickDrawDataReader {
  
  ///  Initializes a reader from a data object.
  /// - Parameters:
  ///   - data: object containing the QuickDraw pict data.
  ///   - position: offset in the data object where reading should start, typically 512 as this is the standart offset.
  init(data: Data, position: Data.Index=512) throws {
    self.data = data;
    self.position = position;
  }
  
  func readUInt8() throws -> UInt8 {
    if position >= data.count {
      throw QuickDrawError.quickDrawIoError(message:"Read at \(position) beyond \(data.count)");
    }
    let value : UInt8? = data[position];
    if let v = value {
      position += 1;
      return v;
    }
    throw QuickDrawError.quickDrawIoError(message:"Read failure");
  }
  
  func readBool() throws -> Bool {
    let v = try readUInt8();
    return v > 0;
  }
  
  func readUInt8(bytes: Data.Index) throws -> [UInt8] {
    guard position + bytes < data.count else {
      throw QuickDrawError.quickDrawIoError(message:"Read at \(position) beyond \(data.count)");
    }
    var result : [UInt8] = [];
    for _ in position..<position + bytes {
      try result.append(readUInt8());
    }
    return result;
  }
  
  func readData(bytes: Data.Index) throws -> Data {
    guard position + bytes < data.count else {
      throw QuickDrawError.quickDrawIoError(message:"Read at \(position) beyond \(data.count)");
    }
    let result = data.subdata(in: position..<position + bytes);
    position += bytes;
    return result;
  }
  
  func readString(bytes: Data.Index) throws -> String {
    let data = try readUInt8(bytes: bytes);
    if let str = String(bytes:data, encoding: String.Encoding.macOSRoman) {
      return str;
    }
    throw QuickDrawError.quickDrawIoError(message: "Failed reading string");
  }
  
  func readType() throws -> String {
    let data = try readUInt8(bytes: 4);
    if let str = String(bytes:data, encoding: String.Encoding.macOSRoman) {
      return str;
    }
    throw QuickDrawError.quickDrawIoError(message: "Failed reading string");
  }
  
  
  /// Read a fixed length (31 bytes) pascal string
  /// - Returns: a string , with a maximum 31 characters.
  func readStr31() throws -> String {
    let length = Data.Index(try readUInt8());
    let tail = 31 - length ;
    if tail < 0 {
      throw QuickDrawError.invalidStr32(length: length);
    }
    let result = try readString(bytes:length);
    skip(bytes: tail);
    return result;
  }
  
  /// Read a Pascal string
  /// - Returns: a string, with a maximum of 255 characters.
  func readPascalString() throws -> String {
    let length = Data.Index(try readUInt8());
    return try readString(bytes:length);
  }
  
  func readInt8() throws -> Int8 {
    return try Int8(bitPattern: readUInt8());
  }

  func readUInt16() throws -> UInt16 {
    let high = try readUInt8();
    let low = try readUInt8();
    return UInt16(high) << 8 | UInt16(low);
  }
  
  func readUInt16(bytes: Data.Index) throws -> [UInt16] {
    var result :[UInt16] = [];
    for _ in 0..<(bytes / 2) {
      let v = try readUInt16();
      result.append(v);
    }
    return result;
  }
  
  func readInt16() throws -> Int16 {
    return Int16(bitPattern: try readUInt16());
  }

  func readUInt32() throws  -> UInt32 {
    let high = try readUInt16();
    let low = try readUInt16();
    return UInt32(high) << 16 | UInt32(low);
  }
  
  func readInt32() throws -> Int32 {
    return Int32(bitPattern: try readUInt32());
  }
  
  func readFixed() throws -> FixedPoint {
    let v = try readInt32();
    return FixedPoint(rawValue: Int(v));
  }

  func readPoint() throws -> QDPoint {
    let v = try readInt16();
    let h = try readInt16();
    return QDPoint(vertical: v, horizontal: h);
  }

  func readDelta() throws -> QDDelta {
    let h = try readInt16();
    let v = try readInt16();
    return QDDelta(dv:v, dh:h);
  }
  
  func readRect() throws -> QDRect  {
    let tl = try readPoint();
    let br = try readPoint();
    return QDRect(topLeft: tl, bottomRight: br);
  }
  
  func readPoly() throws -> QDPolygon {
    let raw_size = try readUInt16();
    let boundingBox = try readRect();
    
    let pointNumber = (raw_size - 10) / 4;
    var points : [QDPoint]  = [];
    if pointNumber > 0 {
      for  _ in 1...pointNumber {
        points.append(try readPoint());
      }
    }
    return QDPolygon(boundingBox: boundingBox, points: points);
  }
  
  func readColor() throws -> QDColor {
    let red = try readUInt16();
    let green = try readUInt16();
    let blue = try readUInt16();
    return QDColor(red: red, green: green, blue: blue);
  }
  

  func readRegion() throws -> QDRegion {
    var len = UInt16(try readUInt16());
    if len < 10 {
      len += 10;
    }
    let rgnDataSize = Data.Index(len - 10);
    let box = try readRect();
    if rgnDataSize > 0 {
      let data = try readUInt16(bytes: rgnDataSize);
      let rects = DecodeRegionData(boundingBox: box, data: data);
      return QDRegion(boundingBox:box, rects:rects);
    }
    return QDRegion(boundingBox:box, rects: []);
  }
  
  func readOpcode(version: UInt8) throws -> UInt16 {
    switch version {
    case 1:
      let opcode = try readUInt8()
      return UInt16(opcode);
    case 2:
      if (position % 2) == 1 {
        position+=1;
      }
      let opcode = try readUInt16()
      return opcode;
    default:
      throw QuickDrawError.unknownQuickDrawVersionError(version:version);
    }
  }
  
  func skip(bytes: Data.Index) -> Void {
    position += bytes;
  }
  
  var position: Data.Index;
  var data: Data;
}
