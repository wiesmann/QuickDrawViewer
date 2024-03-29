//
//  TypeCode.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 04.02.2024.
//

import Foundation

enum MacTypeError: Error {
  case notMacRoman(str: String);
  case invalidLength(length: Int);
}

struct MacTypeCode : RawRepresentable, CustomStringConvertible {
  init(rawValue: UInt32) {
    self.rawValue = rawValue;
  }
  
  init(fromString: String) throws {
    guard let data = fromString.cString(using: .macOSRoman) else {
      throw MacTypeError.notMacRoman(str: fromString);
    }
    guard data.count == 4 else {
      throw MacTypeError.invalidLength(length: data.count);
    }
    rawValue = 
        UInt32(data[0]) << 24 |
        UInt32(data[1]) << 16 | 
        UInt32(data[2]) << 8 |
    UInt32(data[3]);
  }
  
  var description: String {
    let data : [UInt8] = [
      UInt8(rawValue >> 24 & 0xff),
      UInt8(rawValue >> 16 & 0xff),
      UInt8(rawValue >> 8 & 0xff),
      UInt8(rawValue & 0xff)
    ];
    return String(bytes:data, encoding: String.Encoding.macOSRoman) ?? "\(rawValue)";
  }
  
  let rawValue: UInt32;
  static let zero = MacTypeCode(rawValue: 0);
}
