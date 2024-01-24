//
//  FixedPoint.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 18.01.2024.
//

import Foundation

///  Quickdraw uses integer coordinates, most of the time.
///  Some values can be fixed point (horizontal position in particular).
///  So we use a fixed point value to represent coordinates.
///  This type supports math operations that could be done quickly on a 68000 processor:
///  - addition, substraction
///  - shifts
public struct FixedPoint : CustomStringConvertible, Comparable, AdditiveArithmetic {
  
  public init (rawValue: Int) {
    self.fixedValue = rawValue;
  }
  
  public init (_ value: Double) {
    let m = value * Double(FixedPoint.multiplier);
    self.fixedValue = Int(m.rounded());
  }
  
  public init <T : BinaryInteger> (_ value: T) {
    self.fixedValue = Int(value) * FixedPoint.multiplier;
  }
  
  /// Return a compact, Unicode description.
  public var description: String {
    switch fixedValue {
      case 0 :
        return "0";
    case 0x8000:
      return "½";
    case 0x4000:
      return "¼";
    case 0xc000:
      return "¾";
    case let fixedValue where fixedValue & FixedPoint.fractionMask == 0:
        return "\(rounded)";
    default:
        return "\(value)";
    }
  }
  
  public var rounded : Int {
    return fixedValue / FixedPoint.multiplier;
  }
  
  public var value : Double {
    return Double(fixedValue) / Double(FixedPoint.multiplier);
  }
  
  public var isRound : Bool {
    return fixedValue & FixedPoint.fractionMask == 0;
  }
  
  private let fixedValue : Int;
  private static let multiplier : Int = 0x10000;
  private static let fractionMask : Int = multiplier - 1;
  
  public static let zero = FixedPoint(rawValue: 0);
  public static let one = FixedPoint(rawValue: multiplier);
  
  /// Addition
  /// - Parameters:
  ///   - a: left hand value to add
  ///   - b: right hand value to add
  /// - Returns: A fixed point with the sum of a + b.
  public static func + (a: FixedPoint, b: FixedPoint) -> FixedPoint {
    return FixedPoint(rawValue: a.fixedValue + b.fixedValue);
  }
  
  /// Substraction
  /// - Parameters:
  ///   - a: left hand value to add
  ///   - b: right hand value to add
  /// - Returns: A fixed point with the difference  a - b.
  public static func - (a: FixedPoint, b: FixedPoint) -> FixedPoint {
    return FixedPoint(rawValue: a.fixedValue - b.fixedValue);
  }
  
  /// Negation
  /// - Parameter v: value to negate
  /// - Returns: return the negative value of v.
  static prefix func -(v: FixedPoint) -> FixedPoint {
    return FixedPoint(rawValue: -v.fixedValue);
  }
  
  /// Shift right.
  /// - Parameters:
  ///   - v: fixed point value to shift
  ///   - s: number of right shifts
  /// - Returns: value shift to the right, Note that 1 >> 1 = 0.5
  static func >> (v: FixedPoint, s: Int) -> FixedPoint {
    let raw = v.fixedValue >> s;
    return FixedPoint(rawValue: raw);
  }
  
  /// Shift left
  /// - Parameters:
  ///   - v: fixed point value to shift
  ///   - s: number of left shifts
  /// - Returns: <#description#>
  static func << (v: FixedPoint, s: Int) -> FixedPoint {
    let raw = v.fixedValue << s;
    return FixedPoint(rawValue: raw);
  }
  
  public static func < (a: FixedPoint, b: FixedPoint) -> Bool {
    return a.fixedValue < b.fixedValue;
  }
  
  public static func / (a : FixedPoint, b: FixedPoint) -> FixedPoint {
    return FixedPoint(a.value / b.value);
  }
}
