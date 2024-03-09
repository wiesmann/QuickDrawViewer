//
//  Bits.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 09.03.2024.
//
// Various low level bit and memory manipulation utilities.

import Foundation

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}

func makeUInt24(bytes: (UInt8, UInt8, UInt8)) -> UInt32 {
  return UInt32(bytes.0) << 16 | UInt32(bytes.1) << 8 | UInt32(bytes.2);
}

func byteArrayLE<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
  withUnsafeBytes(of: value.littleEndian, Array.init)
}

func byteArrayBE<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
  withUnsafeBytes(of: value.bigEndian, Array.init)
}
