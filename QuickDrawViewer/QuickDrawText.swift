//
//  QuickDrawText.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 17.04.2024.
//

import Foundation

/// Text rendering options
struct QDGlyphState : OptionSet {
  let rawValue: UInt8;
  static let outlinePreferred = QDGlyphState(rawValue: 1 << 0);
  static let preserveGlyphs = QDGlyphState(rawValue: 1 << 1);
  static let fractionalWidths = QDGlyphState(rawValue: 1 << 2);
  static let scalingDisabled = QDGlyphState(rawValue: 1 << 3);
  static let defaultState = QDGlyphState([]);
}

/// Various text related properties.
class QDFontState {
  func getFontName() -> String? {
    if let name = self.fontName {
      return name;
    }
    /// List of classic fonts with their canonical IDs.
    switch fontId {
      case 2: return "New York";
      case 3: return "Geneva";
      case 4: return "Monaco";
      case 5: return "Venice";
      case 6: return "Venice";
      case 7: return "Athens";
      case 8: return "San Francisco";
      case 9: return "Toronto";
      case 11: return "Cairo";
      case 12: return "Los Angeles";
      case 20: return "Times";
      case 21: return "Helvetica";
      case 22: return "Courrier";
      case 23: return "Symbol";
      case 24: return "Mobile";
      default:
        return nil;
    }  // Switch
  }
  var fontId : Int = 0;
  var fontName : String?;
  var fontSize = FixedPoint(12);
  var fontMode : QuickDrawMode = QuickDrawMode.defaultMode;
  var location : QDPoint = QDPoint.zero;
  var fontStyle : QDFontStyle = QDFontStyle.defaultStyle;
  var glyphState : QDGlyphState = QDGlyphState.defaultState;
  var xRatio : FixedPoint = FixedPoint.one;
  var yRatio : FixedPoint = FixedPoint.one;
  var textCenter: QDDelta?;
  var textPictRecord : QDTextPictRecord?;
  var extraSpace : FixedPoint = FixedPoint.zero;
}

enum QDTextJustification : UInt8 {
  case justificationNone = 0;
  case justificationLeft = 1;
  case justificationCenter = 2;
  case justificationRight = 3;
  case justificationFull = 4;
  case justification5 = 5;  // Found in MacDraw 1
  case justification6 = 6;  // Found in MacDraw 1
}

enum QDTextFlip : UInt8 {
  case textFlipNone = 0;
  case textFlipHorizontal = 1;
  case textFlipVertical = 2;
}

enum QDTextLineHeight : UInt8 {
  case unknown = 0;
  case single = 1;
  case oneAndHalf = 2;
  case double = 3;
  case double2 = 4;
}

// Text annotation for text comments
struct QDTextPictRecord {
  let justification : QDTextJustification;
  let flip : QDTextFlip;
  let angle : FixedPoint;
  let lineHeight : QDTextLineHeight;
}

struct QDFontStyle : OptionSet {
  let rawValue: UInt8;
  static let boldBit = QDFontStyle(rawValue: 1 << 0);
  static let italicBit = QDFontStyle(rawValue: 1 << 1);
  static let ulineBit = QDFontStyle(rawValue: 1 << 2);
  static let outlineBit = QDFontStyle(rawValue: 1 << 3);
  static let shadowBit = QDFontStyle(rawValue: 1 << 4);
  static let condenseBit = QDFontStyle(rawValue: 1 << 5);
  static let extendBit = QDFontStyle(rawValue: 1 << 6);
  
  static let defaultStyle = QDFontStyle([]);
}
