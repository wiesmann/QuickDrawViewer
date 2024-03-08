//
//  QuickDrawColor.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 27.02.2024.
//

import Foundation

/// Quickdraw stores RGB colours in 3 × 16 bit values.
struct QDColor : CustomStringConvertible, Hashable, RawRepresentable {
  
  let rawValue : UInt64;
  
  init(rawValue: UInt64)  {
    self.rawValue = rawValue & 0xffffffffffff;
  }
  
  init (red: UInt16, green: UInt16, blue: UInt16) {
    let r = UInt64(red);
    let g = UInt64(green);
    let b = UInt64(blue);
    self.init(rawValue: r << 32 | g << 16 | b);
  }
  
  init (red8: UInt8, green8: UInt8, blue8: UInt8) {
    let r = QDColor.pad16(red8);
    let g = QDColor.pad16(green8);
    let b = QDColor.pad16(blue8);
    self.init(red: r, green: g, blue: b);
  }
  
  var red : UInt16 {
    return UInt16((rawValue >> 32) & 0xffff);
  }
  
  var green: UInt16 {
    return UInt16((rawValue >> 16) & 0xffff);
  }
  
  var blue: UInt16 {
    return UInt16((rawValue) & 0xffff);
  }
  
  public var description: String {
    var result = "Color: 0x";
    result += String(format: "%04X", red);
    result += "|";
    result += String(format: "%04X", green);
    result += "|";
    result += String(format: "%04X", green);
    return result;
  }
  
  /// Return classical 3 byte RGB representation.
  var rgb : [UInt8] {
    var data : [UInt8] = [];
    data.append(UInt8(red >> 8));
    data.append(UInt8(green >> 8));
    data.append(UInt8(blue >> 8));
    return data;
  }
  
  // Convert a 8 bit color value into a 16 bit one.
  static func pad16<T : BinaryInteger>(_ value: T) -> UInt16 {
    return UInt16(value & 0xff) << 8 | UInt16(value & 0xff);
  }
  
  static func blend(a: QDColor, b: QDColor, aWeight : Double) -> QDColor {
    let bWeight = 1.0 - aWeight;
    let red = UInt16(aWeight * Double(a.red) + bWeight * Double(b.red));
    let green = UInt16(aWeight * Double(a.green) + bWeight * Double(b.green));
    let blue = UInt16(aWeight * Double(a.blue) + bWeight * Double(b.blue));
    return QDColor(red: red, green: green, blue: blue);
  }
  
  // Constants that represent the colours of QuickDraw 1.
  static let black = QDColor(red8: 0x00, green8: 0x00, blue8: 0x00);
  static let white = QDColor(red8: 0xff, green8: 0xff, blue8: 0xff);
  static let red = QDColor(red8: 0xff, green8: 0x00, blue8: 0x00);
  static let green = QDColor(red8: 0x00, green8: 0xff, blue8: 0x00);
  static let blue = QDColor(red8: 0x00, green8: 0x00, blue8: 0xff);
  static let cyan = QDColor(red8: 0x00, green8: 0xff, blue8: 0xff);
  static let magenta = QDColor(red8: 0xff, green8: 0x00, blue8: 0xff);
  static let yellow = QDColor(red8: 0xff, green8: 0xff, blue8: 0x00);
}

/// Convert pict 1 colour into RGB Quickdraw colors.
/// These colours are basically plotter bits, with one bit per pen-colour.
/// - Parameter code: binary code representation
/// - Throws: unsupported colour error for invalid bit combinations.
/// - Returns: one of the constants defined in QDColor.
func QD1Color(code: UInt32) throws -> QDColor {
  switch code {
    case 0x21: return QDColor.black;
    case 0x1e: return QDColor.white;
    case 0xcd: return QDColor.red;
    case 0x155: return QDColor.green;
    case 0x199: return QDColor.blue;
    case 0x111: return QDColor.cyan;
    case 0x89: return QDColor.magenta;
    case 0x45: return QDColor.yellow;
  default:
    throw QuickDrawError.unsupportedColor(colorCode: code);
  }
}

/// Standard Apple colour tables.
let clut1Raw : [UInt16] = [0x0000, 0x0001, 0x8000, 0x0001, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000 ];
let clut2Raw : [UInt16] = [0x0000, 0x0002, 0x8000, 0x0003, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xACAC, 0xACAC, 0xACAC, 0x0000, 0x5555, 0x5555, 0x5555, 0x0000, 0x0000, 0x0000, 0x0000];
let clut4Raw : [UInt16] = [0x0000, 0x0004, 0x8000, 0x000F, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFC00, 0xF37D, 0x052F, 0x0000, 0xFFFF, 0x648A, 0x028C, 0x0000, 0xDD6B, 0x08C2, 0x06A2, 0x0000, 0xF2D7, 0x0856, 0x84EC, 0x0000, 0x46E3, 0x0000, 0xA53E, 0x0000, 0x0000, 0x0000, 0xD400, 0x0000, 0x0241, 0xAB54, 0xEAFF, 0x0000, 0x1F21, 0xB793, 0x1431, 0x0000, 0x0000, 0x64AF, 0x11B0, 0x0000, 0x5600, 0x2C9D, 0x0524, 0x0000, 0x90D7, 0x7160, 0x3A34, 0x0000, 0xC000, 0xC000, 0xC000, 0x0000, 0x8000, 0x8000, 0x8000, 0x0000, 0x4000, 0x4000, 0x4000, 0x0000, 0x0000, 0x0000, 0x0000];
let clut8Raw : [UInt16] = [0x0000, 0x0008, 0x8000, 0x00FF, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xFFFF, 0xCCCC, 0x0000, 0xFFFF, 0xFFFF, 0x9999, 0x0000, 0xFFFF, 0xFFFF, 0x6666, 0x0000, 0xFFFF, 0xFFFF, 0x3333, 0x0000, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0xCCCC, 0xFFFF, 0x0000, 0xFFFF, 0xCCCC, 0xCCCC, 0x0000, 0xFFFF, 0xCCCC, 0x9999, 0x0000, 0xFFFF, 0xCCCC, 0x6666, 0x0000, 0xFFFF, 0xCCCC, 0x3333, 0x0000, 0xFFFF, 0xCCCC, 0x0000, 0x0000, 0xFFFF, 0x9999, 0xFFFF, 0x0000, 0xFFFF, 0x9999, 0xCCCC, 0x0000, 0xFFFF, 0x9999, 0x9999, 0x0000, 0xFFFF, 0x9999, 0x6666, 0x0000, 0xFFFF, 0x9999, 0x3333, 0x0000, 0xFFFF, 0x9999, 0x0000, 0x0000, 0xFFFF, 0x6666, 0xFFFF, 0x0000, 0xFFFF, 0x6666, 0xCCCC, 0x0000, 0xFFFF, 0x6666, 0x9999, 0x0000, 0xFFFF, 0x6666, 0x6666, 0x0000, 0xFFFF, 0x6666, 0x3333, 0x0000, 0xFFFF, 0x6666, 0x0000, 0x0000, 0xFFFF, 0x3333, 0xFFFF, 0x0000, 0xFFFF, 0x3333, 0xCCCC, 0x0000, 0xFFFF, 0x3333, 0x9999, 0x0000, 0xFFFF, 0x3333, 0x6666, 0x0000, 0xFFFF, 0x3333, 0x3333, 0x0000, 0xFFFF, 0x3333, 0x0000, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xCCCC, 0x0000, 0xFFFF, 0x0000, 0x9999, 0x0000, 0xFFFF, 0x0000, 0x6666, 0x0000, 0xFFFF, 0x0000, 0x3333, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0xCCCC, 0xFFFF, 0xFFFF, 0x0000, 0xCCCC, 0xFFFF, 0xCCCC, 0x0000, 0xCCCC, 0xFFFF, 0x9999, 0x0000, 0xCCCC, 0xFFFF, 0x6666, 0x0000, 0xCCCC, 0xFFFF, 0x3333, 0x0000, 0xCCCC, 0xFFFF, 0x0000, 0x0000, 0xCCCC, 0xCCCC, 0xFFFF, 0x0000, 0xCCCC, 0xCCCC, 0xCCCC, 0x0000, 0xCCCC, 0xCCCC, 0x9999, 0x0000, 0xCCCC, 0xCCCC, 0x6666, 0x0000, 0xCCCC, 0xCCCC, 0x3333, 0x0000, 0xCCCC, 0xCCCC, 0x0000, 0x0000, 0xCCCC, 0x9999, 0xFFFF, 0x0000, 0xCCCC, 0x9999, 0xCCCC, 0x0000, 0xCCCC, 0x9999, 0x9999, 0x0000, 0xCCCC, 0x9999, 0x6666, 0x0000, 0xCCCC, 0x9999, 0x3333, 0x0000, 0xCCCC, 0x9999, 0x0000, 0x0000, 0xCCCC, 0x6666, 0xFFFF, 0x0000, 0xCCCC, 0x6666, 0xCCCC, 0x0000, 0xCCCC, 0x6666, 0x9999, 0x0000, 0xCCCC, 0x6666, 0x6666, 0x0000, 0xCCCC, 0x6666, 0x3333, 0x0000, 0xCCCC, 0x6666, 0x0000, 0x0000, 0xCCCC, 0x3333, 0xFFFF, 0x0000, 0xCCCC, 0x3333, 0xCCCC, 0x0000, 0xCCCC, 0x3333, 0x9999, 0x0000, 0xCCCC, 0x3333, 0x6666, 0x0000, 0xCCCC, 0x3333, 0x3333, 0x0000, 0xCCCC, 0x3333, 0x0000, 0x0000, 0xCCCC, 0x0000, 0xFFFF, 0x0000, 0xCCCC, 0x0000, 0xCCCC, 0x0000, 0xCCCC, 0x0000, 0x9999, 0x0000, 0xCCCC, 0x0000, 0x6666, 0x0000, 0xCCCC, 0x0000, 0x3333, 0x0000, 0xCCCC, 0x0000, 0x0000, 0x0000, 0x9999, 0xFFFF, 0xFFFF, 0x0000, 0x9999, 0xFFFF, 0xCCCC, 0x0000, 0x9999, 0xFFFF, 0x9999, 0x0000, 0x9999, 0xFFFF, 0x6666, 0x0000, 0x9999, 0xFFFF, 0x3333, 0x0000, 0x9999, 0xFFFF, 0x0000, 0x0000, 0x9999, 0xCCCC, 0xFFFF, 0x0000, 0x9999, 0xCCCC, 0xCCCC, 0x0000, 0x9999, 0xCCCC, 0x9999, 0x0000, 0x9999, 0xCCCC, 0x6666, 0x0000, 0x9999, 0xCCCC, 0x3333, 0x0000, 0x9999, 0xCCCC, 0x0000, 0x0000, 0x9999, 0x9999, 0xFFFF, 0x0000, 0x9999, 0x9999, 0xCCCC, 0x0000, 0x9999, 0x9999, 0x9999, 0x0000, 0x9999, 0x9999, 0x6666, 0x0000, 0x9999, 0x9999, 0x3333, 0x0000, 0x9999, 0x9999, 0x0000, 0x0000, 0x9999, 0x6666, 0xFFFF, 0x0000, 0x9999, 0x6666, 0xCCCC, 0x0000, 0x9999, 0x6666, 0x9999, 0x0000, 0x9999, 0x6666, 0x6666, 0x0000, 0x9999, 0x6666, 0x3333, 0x0000, 0x9999, 0x6666, 0x0000, 0x0000, 0x9999, 0x3333, 0xFFFF, 0x0000, 0x9999, 0x3333, 0xCCCC, 0x0000, 0x9999, 0x3333, 0x9999, 0x0000, 0x9999, 0x3333, 0x6666, 0x0000, 0x9999, 0x3333, 0x3333, 0x0000, 0x9999, 0x3333, 0x0000, 0x0000, 0x9999, 0x0000, 0xFFFF, 0x0000, 0x9999, 0x0000, 0xCCCC, 0x0000, 0x9999, 0x0000, 0x9999, 0x0000, 0x9999, 0x0000, 0x6666, 0x0000, 0x9999, 0x0000, 0x3333, 0x0000, 0x9999, 0x0000, 0x0000, 0x0000, 0x6666, 0xFFFF, 0xFFFF, 0x0000, 0x6666, 0xFFFF, 0xCCCC, 0x0000, 0x6666, 0xFFFF, 0x9999, 0x0000, 0x6666, 0xFFFF, 0x6666, 0x0000, 0x6666, 0xFFFF, 0x3333, 0x0000, 0x6666, 0xFFFF, 0x0000, 0x0000, 0x6666, 0xCCCC, 0xFFFF, 0x0000, 0x6666, 0xCCCC, 0xCCCC, 0x0000, 0x6666, 0xCCCC, 0x9999, 0x0000, 0x6666, 0xCCCC, 0x6666, 0x0000, 0x6666, 0xCCCC, 0x3333, 0x0000, 0x6666, 0xCCCC, 0x0000, 0x0000, 0x6666, 0x9999, 0xFFFF, 0x0000, 0x6666, 0x9999, 0xCCCC, 0x0000, 0x6666, 0x9999, 0x9999, 0x0000, 0x6666, 0x9999, 0x6666, 0x0000, 0x6666, 0x9999, 0x3333, 0x0000, 0x6666, 0x9999, 0x0000, 0x0000, 0x6666, 0x6666, 0xFFFF, 0x0000, 0x6666, 0x6666, 0xCCCC, 0x0000, 0x6666, 0x6666, 0x9999, 0x0000, 0x6666, 0x6666, 0x6666, 0x0000, 0x6666, 0x6666, 0x3333, 0x0000, 0x6666, 0x6666, 0x0000, 0x0000, 0x6666, 0x3333, 0xFFFF, 0x0000, 0x6666, 0x3333, 0xCCCC, 0x0000, 0x6666, 0x3333, 0x9999, 0x0000, 0x6666, 0x3333, 0x6666, 0x0000, 0x6666, 0x3333, 0x3333, 0x0000, 0x6666, 0x3333, 0x0000, 0x0000, 0x6666, 0x0000, 0xFFFF, 0x0000, 0x6666, 0x0000, 0xCCCC, 0x0000, 0x6666, 0x0000, 0x9999, 0x0000, 0x6666, 0x0000, 0x6666, 0x0000, 0x6666, 0x0000, 0x3333, 0x0000, 0x6666, 0x0000, 0x0000, 0x0000, 0x3333, 0xFFFF, 0xFFFF, 0x0000, 0x3333, 0xFFFF, 0xCCCC, 0x0000, 0x3333, 0xFFFF, 0x9999, 0x0000, 0x3333, 0xFFFF, 0x6666, 0x0000, 0x3333, 0xFFFF, 0x3333, 0x0000, 0x3333, 0xFFFF, 0x0000, 0x0000, 0x3333, 0xCCCC, 0xFFFF, 0x0000, 0x3333, 0xCCCC, 0xCCCC, 0x0000, 0x3333, 0xCCCC, 0x9999, 0x0000, 0x3333, 0xCCCC, 0x6666, 0x0000, 0x3333, 0xCCCC, 0x3333, 0x0000, 0x3333, 0xCCCC, 0x0000, 0x0000, 0x3333, 0x9999, 0xFFFF, 0x0000, 0x3333, 0x9999, 0xCCCC, 0x0000, 0x3333, 0x9999, 0x9999, 0x0000, 0x3333, 0x9999, 0x6666, 0x0000, 0x3333, 0x9999, 0x3333, 0x0000, 0x3333, 0x9999, 0x0000, 0x0000, 0x3333, 0x6666, 0xFFFF, 0x0000, 0x3333, 0x6666, 0xCCCC, 0x0000, 0x3333, 0x6666, 0x9999, 0x0000, 0x3333, 0x6666, 0x6666, 0x0000, 0x3333, 0x6666, 0x3333, 0x0000, 0x3333, 0x6666, 0x0000, 0x0000, 0x3333, 0x3333, 0xFFFF, 0x0000, 0x3333, 0x3333, 0xCCCC, 0x0000, 0x3333, 0x3333, 0x9999, 0x0000, 0x3333, 0x3333, 0x6666, 0x0000, 0x3333, 0x3333, 0x3333, 0x0000, 0x3333, 0x3333, 0x0000, 0x0000, 0x3333, 0x0000, 0xFFFF, 0x0000, 0x3333, 0x0000, 0xCCCC, 0x0000, 0x3333, 0x0000, 0x9999, 0x0000, 0x3333, 0x0000, 0x6666, 0x0000, 0x3333, 0x0000, 0x3333, 0x0000, 0x3333, 0x0000, 0x0000, 0x0000, 0x0000, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0xCCCC, 0x0000, 0x0000, 0xFFFF, 0x9999, 0x0000, 0x0000, 0xFFFF, 0x6666, 0x0000, 0x0000, 0xFFFF, 0x3333, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0xCCCC, 0xFFFF, 0x0000, 0x0000, 0xCCCC, 0xCCCC, 0x0000, 0x0000, 0xCCCC, 0x9999, 0x0000, 0x0000, 0xCCCC, 0x6666, 0x0000, 0x0000, 0xCCCC, 0x3333, 0x0000, 0x0000, 0xCCCC, 0x0000, 0x0000, 0x0000, 0x9999, 0xFFFF, 0x0000, 0x0000, 0x9999, 0xCCCC, 0x0000, 0x0000, 0x9999, 0x9999, 0x0000, 0x0000, 0x9999, 0x6666, 0x0000, 0x0000, 0x9999, 0x3333, 0x0000, 0x0000, 0x9999, 0x0000, 0x0000, 0x0000, 0x6666, 0xFFFF, 0x0000, 0x0000, 0x6666, 0xCCCC, 0x0000, 0x0000, 0x6666, 0x9999, 0x0000, 0x0000, 0x6666, 0x6666, 0x0000, 0x0000, 0x6666, 0x3333, 0x0000, 0x0000, 0x6666, 0x0000, 0x0000, 0x0000, 0x3333, 0xFFFF, 0x0000, 0x0000, 0x3333, 0xCCCC, 0x0000, 0x0000, 0x3333, 0x9999, 0x0000, 0x0000, 0x3333, 0x6666, 0x0000, 0x0000, 0x3333, 0x3333, 0x0000, 0x0000, 0x3333, 0x0000, 0x0000, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0xCCCC, 0x0000, 0x0000, 0x0000, 0x9999, 0x0000, 0x0000, 0x0000, 0x6666, 0x0000, 0x0000, 0x0000, 0x3333, 0x0000, 0xEEEE, 0x0000, 0x0000, 0x0000, 0xDDDD, 0x0000, 0x0000, 0x0000, 0xBBBB, 0x0000, 0x0000, 0x0000, 0xAAAA, 0x0000, 0x0000, 0x0000, 0x8888, 0x0000, 0x0000, 0x0000, 0x7777, 0x0000, 0x0000, 0x0000, 0x5555, 0x0000, 0x0000, 0x0000, 0x4444, 0x0000, 0x0000, 0x0000, 0x2222, 0x0000, 0x0000, 0x0000, 0x1111, 0x0000, 0x0000, 0x0000, 0x0000, 0xEEEE, 0x0000, 0x0000, 0x0000, 0xDDDD, 0x0000, 0x0000, 0x0000, 0xBBBB, 0x0000, 0x0000, 0x0000, 0xAAAA, 0x0000, 0x0000, 0x0000, 0x8888, 0x0000, 0x0000, 0x0000, 0x7777, 0x0000, 0x0000, 0x0000, 0x5555, 0x0000, 0x0000, 0x0000, 0x4444, 0x0000, 0x0000, 0x0000, 0x2222, 0x0000, 0x0000, 0x0000, 0x1111, 0x0000, 0x0000, 0x0000, 0x0000, 0xEEEE, 0x0000, 0x0000, 0x0000, 0xDDDD, 0x0000, 0x0000, 0x0000, 0xBBBB, 0x0000, 0x0000, 0x0000, 0xAAAA, 0x0000, 0x0000, 0x0000, 0x8888, 0x0000, 0x0000, 0x0000, 0x7777, 0x0000, 0x0000, 0x0000, 0x5555, 0x0000, 0x0000, 0x0000, 0x4444, 0x0000, 0x0000, 0x0000, 0x2222, 0x0000, 0x0000, 0x0000, 0x1111, 0x0000, 0xEEEE, 0xEEEE, 0xEEEE, 0x0000, 0xDDDD, 0xDDDD, 0xDDDD, 0x0000, 0xBBBB, 0xBBBB, 0xBBBB, 0x0000, 0xAAAA, 0xAAAA, 0xAAAA, 0x0000, 0x8888, 0x8888, 0x8888, 0x0000, 0x7777, 0x7777, 0x7777, 0x0000, 0x5555, 0x5555, 0x5555, 0x0000, 0x4444, 0x4444, 0x4444, 0x0000, 0x2222, 0x2222, 0x2222, 0x0000, 0x1111, 0x1111, 0x1111, 0x0000, 0x0000, 0x0000, 0x0000 ];

/// Create a Color Table from it's raw value.
/// - Parameter raw: raw color table data as an array of UInt16
/// - Returns: a color table.
func clutFromRaw(raw: [UInt16]) -> QDColorTable {
  let id = Int(raw[1]);
  let clutFlags = raw[2];
  let size = raw[3];
  var p = 4;
  var clut : [QDColor] = [];
  for _ in 0...size {
    let red = raw[p+1];
    let green = raw[p+2];
    let blue = raw[p+3];
    clut.append(QDColor(red: red, green: green, blue: blue));
    p += 4;
  }
  return QDColorTable(clut: clut, id: id, clutFlags:clutFlags);
}

/// ColorTable, typically called  `CLUT`.
class QDColorTable : CustomStringConvertible {
  public var description: String {
    let string_flag = String(format: "%0X ", clutFlags);
    var result = "flags: \(string_flag) "
    result += "clut \(clut)";
    return result;
  }
  
  init(clutFlags: UInt16) {
    self.clutFlags = clutFlags;
  }
  
  init(clut : [QDColor], id: Int, clutFlags : UInt16) {
    self.id = id;
    self.clutFlags = clutFlags;
    self.clut = clut;
  }
  
  init(raw: [UInt32], id: Int) {
    self.id = id;
    self.clutFlags = 0;
    for v in raw {
      let r = QDColor.pad16(v >> 16)
      let g = QDColor.pad16(v >> 8);
      let b = QDColor.pad16(v);
      let color = QDColor(red: r, green: g, blue: b);
      clut.append(color)
    }
  }
  
  let clutFlags : UInt16;
  var clut : [QDColor] = [];
  var id : Int = 0;
  
  // Standard Apple color tables.
  static let palette1 = clutFromRaw(raw: clut1Raw);
  static let palette2 = clutFromRaw(raw: clut2Raw);
  static let palette4 = clutFromRaw(raw: clut4Raw);
  static let palette8 = clutFromRaw(raw: clut8Raw);
  
  static func forClutId(clutId: Int) -> QDColorTable? {
    switch clutId {
    case 1: return palette1;
    case 2: return palette2;
    case 4: return palette4;
    case 8: return palette8;
    default:
      return nil;
    }
  }
}

/// Pixel in ARGB555 format with the alpha in the first bit.
/// Mostly used by the RoadPizza decompressor.
struct ARGB555: RawRepresentable {
  
  init(rawValue: UInt16) {
    self.rawValue = rawValue
  }
  
  init(red: UInt16, green: UInt16, blue: UInt16) {
    rawValue = UInt16(blue & 0x1F) | UInt16(green & 0x1F) << 5 | UInt16(red & 0x1F) << 15 | 0x8000;
  }
  
  var red : UInt16 {
    return UInt16(rawValue >> 10) & 0x1F;
  }
  
  var green : UInt16 {
    return UInt16(rawValue >> 5) & 0x1F;
  }
  
  var blue : UInt16 {
    return UInt16(rawValue) & 0x1F;
  }
  
  let rawValue : UInt16;
  
  static let zero = ARGB555(rawValue: 0);
  static let pixelBytes = 2;
}

extension QuickDrawDataReader {
  func readColor() throws -> QDColor {
    let red = try readUInt16();
    let green = try readUInt16();
    let blue = try readUInt16();
    return QDColor(red: red, green: green, blue: blue);
  }
  
  func readClut() throws -> QDColorTable {
    skip(bytes: 4);
    let clutFlags = try readUInt16();
    let colorTable = QDColorTable(clutFlags: clutFlags);
    let clutSize = try readUInt16();
    for index in 0...clutSize {
      let r_index = try readUInt16();
      // DeskDraw produces index with value 0x8000
      if r_index != index && r_index != 0x8000 {
        print("Inconsistent index: \(r_index)≠\(index)");
      }
      let color = try readColor();
      colorTable.clut.append(color)
    }
    return colorTable;
  }
}
