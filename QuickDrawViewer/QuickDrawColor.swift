//
//  QuickDrawColor.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 27.02.2024.
//

import Foundation

/// Quickdraw stores RGB colours in 3 × 16 bit values.
struct QDColor : CustomStringConvertible, Hashable {
  
  public var description: String {
    var result = "Color: 0x";
    result += String(format: "%04X", red);
    result += "|";
    result += String(format: "%04X", green);
    result += "|";
    result += String(format: "%04X", green);
    return result;
  }
  
  let red : UInt16;
  let green: UInt16;
  let blue: UInt16;
  
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
  
  // Constants that represent the colours of QuickDraw 1.
  static let black = QDColor(red: 0x00, green: 0x00, blue: 0x00);
  static let white = QDColor(red: 0xffff, green: 0xffff, blue: 0xffff);
  static let red = QDColor(red: 0xffff, green: 0x00, blue: 0x00);
  static let green = QDColor(red: 0x00, green: 0xffff, blue: 0x00);
  static let blue = QDColor(red: 0x00, green: 0x00, blue: 0xffff);
  static let cyan = QDColor(red: 0x00, green: 0xffff, blue: 0xffff);
  static let magenta = QDColor(red: 0xffff, green: 0x00, blue: 0xffff);
  static let yellow = QDColor(red: 0xffff, green: 0xffff, blue: 0x00);
}

/// Convert pict 1 colour into RGB Quickdraw colors.
/// These colours are basically plotter bits, with one bit per pen-colour.
/// - Parameter code: binary code representation
/// - Throws: unsupported colour error for invalid bit combinations.
/// - Returns: one of the constants defined in QDColor.
func QD1Color(code: UInt32) throws -> QDColor {
  switch code {
    case 33: return QDColor.black;
    case 30: return QDColor.white;
    case 205: return QDColor.red;
    case 341: return QDColor.green;
    case 409: return QDColor.blue;
    case 273: return QDColor.cyan;
    case 137: return QDColor.magenta;
    case 69: return QDColor.yellow;
  default:
    throw QuickDrawError.unsupportedColor(colorCode: code);
  }
}

let clut8Raw : [UInt32] = [0x000000,0x0b0b0b,0x222222,0x444444,0x555555,0x777777,0x888888,0xaaaaaa,0xbbbbbb,0xdddddd,0xeeeeee,0x00000b,0x000022,0x000044,0x000055,0x000077,0x000088,0x0000aa,0x0000bb,0x0000dd,0x0000ee,0x000b00,0x002200,0x004400,0x005500,0x007700,0x008800,0x00aa00,0x00bb00,0x00dd00,0x00ee00,0x0b0000,0x220000,0x440000,0x550000,0x770000,0x880000,0xaa0000,0xbb0000,0xdd0000,0xee0000,0x000033,0x000066,0x000099,0x0000cc,0x0000ff,0x003300,0x003333,0x003366,0x003399,0x0033cc,0x0033ff,0x006600,0x006633,0x006666,0x006699,0x0066cc,0x0066ff,0x009900,0x009933,0x009966,0x009999,0x0099cc,0x0099ff,0x00cc00,0x00cc33,0x00cc66,0x00cc99,0x00cccc,0x00ccff,0x00ff00,0x00ff33,0x00ff66,0x00ff99,0x00ffcc,0x00ffff,0x330000,0x330033,0x330066,0x330099,0x3300cc,0x3300ff,0x333300,0x333333,0x333366,0x333399,0x3333cc,0x3333ff,0x336600,0x336633,0x336666,0x336699,0x3366cc,0x3366ff,0x339900,0x339933,0x339966,0x339999,0x3399cc,0x3399ff,0x33cc00,0x33cc33,0x33cc66,0x33cc99,0x33cccc,0x33ccff,0x33ff00,0x33ff33,0x33ff66,0x33ff99,0x33ffcc,0x33ffff,0x660000,0x660033,0x660066,0x660099,0x6600cc,0x6600ff,0x663300,0x663333,0x663366,0x663399,0x6633cc,0x6633ff,0x666600,0x666633,0x666666,0x666699,0x6666cc,0x6666ff,0x669900,0x669933,0x669966,0x669999,0x6699cc,0x6699ff,0x66cc00,0x66cc33,0x66cc66,0x66cc99,0x66cccc,0x66ccff,0x66ff00,0x66ff33,0x66ff66,0x66ff99,0x66ffcc,0x66ffff,0x990000,0x990033,0x990066,0x990099,0x9900cc,0x9900ff,0x993300,0x993333,0x993366,0x993399,0x9933cc,0x9933ff,0x996600,0x996633,0x996666,0x996699,0x9966cc,0x9966ff,0x999900,0x999933,0x999966,0x999999,0x9999cc,0x9999ff,0x99cc00,0x99cc33,0x99cc66,0x99cc99,0x99cccc,0x99ccff,0x99ff00,0x99ff33,0x99ff66,0x99ff99,0x99ffcc,0x99ffff,0xcc0000,0xcc0033,0xcc0066,0xcc0099,0xcc00cc,0xcc00ff,0xcc3300,0xcc3333,0xcc3366,0xcc3399,0xcc33cc,0xcc33ff,0xcc6600,0xcc6633,0xcc6666,0xcc6699,0xcc66cc,0xcc66ff,0xcc9900,0xcc9933,0xcc9966,0xcc9999,0xcc99cc,0xcc99ff,0xcccc00,0xcccc33,0xcccc66,0xcccc99,0xcccccc,0xccccff,0xccff00,0xccff33,0xccff66,0xccff99,0xccffcc,0xccffff,0xff0000,0xff0033,0xff0066,0xff0099,0xff00cc,0xff00ff,0xff3300,0xff3333,0xff3366,0xff3399,0xff33cc,0xff33ff,0xff6600,0xff6633,0xff6666,0xff6699,0xff66cc,0xff66ff,0xff9900,0xff9933,0xff9966,0xff9999,0xff99cc,0xff99ff,0xffcc00,0xffcc33,0xffcc66,0xffcc99,0xffcccc,0xffccff,0xffff00,0xffff33,0xffff66,0xffff99,0xffffcc,0xffffff];

/// ColorTable, typically called  `CLUT`.
class QDColorTable : CustomStringConvertible {
  public var description: String {
    let string_flag = String(format: "%0X ", clutFlags);
    var result = "flags: \(string_flag) "
    result += "size \(clut.count)";
    return result;
  }
  
  init(clutFlags: UInt16) {
    self.clutFlags = clutFlags;
  }
  
  init(clut : [QDColor]) {
    self.clutFlags = 0;
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
  
  static let blackWhite : QDColorTable = QDColorTable(clut:[QDColor.black, QDColor.white]);
  
  static func forClutId(clutId: Int) -> QDColorTable? {
    if (clutId == 8) {
      return QDColorTable(raw: clut8Raw.reversed(), id: 8);
    }
    return nil;
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
