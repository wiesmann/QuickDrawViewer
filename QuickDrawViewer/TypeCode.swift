//
//  TypeCode.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 04.02.2024.
//

import Foundation

struct MacTypeCode : RawRepresentable, CustomStringConvertible {
  init(rawValue: UInt32) {
    self.rawValue = rawValue;
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
