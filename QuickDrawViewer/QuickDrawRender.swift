//
//  QuickDrawRender.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 03.12.2023.
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO

enum CoreGraphicRenderError : Error {
  case NotRgbColor(color: CGColor);
}

protocol QuickDrawRenderer {
  func execute(opcode: OpCode) throws -> Void;
  func execute(picture: QDPicture) throws -> Void;
}

extension CGPoint {
  init(qd_point : QDPoint) {
    self.init(x: qd_point.horizontal.value, y: qd_point.vertical.value)
  }
}

extension CGSize {
  init(delta : QDDelta) {
    self.init(width: delta.dh.value, height: delta.dv.value);
  }
}

extension CGRect {
  init(qdrect: QDRect) {
    let origin = CGPoint(qd_point: qdrect.topLeft);
    let size = CGSize(delta: qdrect.dimensions);
    self.init(origin:origin, size:size);
  }

}

extension CGContext {
  /// Draw `image` flipped vertically, positioned and scaled inside `rect`.
  public func drawFlipped(_ image: CGImage, in rect: CGRect, byTiling : Bool = false) {
    self.saveGState()
    self.translateBy(x: 0, y: rect.origin.y + rect.height)
    self.scaleBy(x: 1.0, y: -1.0)
    self.draw(image, in: CGRect(origin: CGPoint(x: rect.origin.x, y: 0), size: rect.size), byTiling: byTiling)
    self.restoreGState()
  }
}

func ToCGColor(qdcolor: QDColor) -> CGColor {
  let red = CGFloat(qdcolor.red) / 0x10000;
  let green = CGFloat(qdcolor.green) / 0x10000;
  let blue = CGFloat(qdcolor.blue) / 0x10000;
  return CGColor(red: red, green: green, blue: blue, alpha: 1.0);
}

func FloatToUInt16(_ value: CGFloat) -> UInt16 {
  return UInt16(value * 0x10000);
}

func ToQDColor(color: CGColor) throws -> QDColor  {
  if color.numberOfComponents == 3 {
    if let components = color.components {
      let red = FloatToUInt16(components[0]);
      let green = FloatToUInt16(components[1]);
      let blue = FloatToUInt16(components[2]);
      return QDColor(red: red, green: green, blue: blue);
    }
  }
  throw CoreGraphicRenderError.NotRgbColor(color: color);
}

func SubstituteFontName(fontName : String?) -> String {
  if let name = fontName {
    switch name {
    case "Geneva" : return "Verdana";
    default:
      return name;
    }
  }
  return "Helvetica";
}

func deg2rad(_ number: Int16) -> Double {
    return Double(number) * .pi / 180
}

/// Renderer that wraps a core-graphics context.
/// All QuickDraw operations are translated into Core Graphics, Core Text, or Core Image ones.
class QuickdrawCGRenderer : QuickDrawRenderer {
  
  init(context : CGContext?) {
    self.context = context;
    penState = PenState();
    fontState = QDFontState();
    rgbSpace = CGColorSpaceCreateDeviceRGB();
  }
  
  func GetColorSpace(bit_opcode: BitRectOpcode) throws -> CGColorSpace {
    let clut = bit_opcode.bitmapInfo.clut;
    return try ToColorSpace(clut: clut);
  }
  
  func ToColorSpace(clut: QDColorTable) throws -> CGColorSpace {
    var data : [UInt8] = [];
    for color in clut.clut {
      data.append(contentsOf: color.rgb);
    }
    guard data.count <= 256 * 8 else {
      throw QuickDrawError.invalidClutError(clut:clut);
    }
    let result = CGColorSpace(indexedBaseSpace: rgbSpace, last: clut.clut.count - 1, colorTable: &data);
    guard result != nil else {
      throw QuickDrawError.renderingError(message: "CGColorSpace creation failed");
    }
    return result!;
  }
  
  func paintColorSpace() -> CGColorSpace {
    var data : [UInt8] = [];
    data.append(contentsOf: penState.bgColor.rgb);
    data.append(contentsOf: penState.fgColor.rgb);
    return CGColorSpace(indexedBaseSpace: rgbSpace, last: 1, colorTable: &data)!;
  }
  
  func paintPath() throws {
    let area = CGRect(x: 0, y: 0, width: 8, height: 8);
    context!.saveGState();
    context!.clip();
    let data = penState.drawPattern.bytes;
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    let bitmapInfo = CGBitmapInfo();
    let patternImage = CGImage(
          width: 8,
          height: 8,
          bitsPerComponent: 1,
          bitsPerPixel: 1,
          bytesPerRow: 1,
          space: paintColorSpace(),
          bitmapInfo: bitmapInfo,
          provider: provider,
          decode: nil,
          shouldInterpolate: false,
          intent: CGColorRenderingIntent.defaultIntent)!;
    context!.drawFlipped(patternImage, in: area, byTiling: true);
    context!.restoreGState();
  }
  
  func applyVerbToPath(verb: QDVerb) throws {
    switch verb {
      // The difference between paint and fill verbs is that paint uses the
      // pen (frame) color.
    case QDVerb.paint:
      try paintPath();
    case QDVerb.fill:
      context!.setFillColor(ToCGColor(qdcolor: penState.fillColor));
      context!.fillPath();
    case QDVerb.frame:
      context!.setLineWidth(penState.penWidth.value);
      context!.setStrokeColor(ToCGColor(qdcolor: penState.drawColor));
      context!.strokePath();
    case QDVerb.erase:
      context!.setFillColor(ToCGColor(qdcolor: penState.bgColor));
      context!.fillPath();
    case QDVerb.clip:
      /// Quickdraw clip operation replace the existing clip, where CoreGraphic ones are cumulative (intersection).
      context!.resetClip();
      context!.clip();
    case QDVerb.invert:
      context!.saveGState();
      context!.setBlendMode(CGBlendMode.difference);
      context!.setFillColor(ToCGColor(qdcolor: penState.fillColor));
      context!.fillPath();
      context!.restoreGState();
    }
  }
  
  func executeOrigin(originOp: OriginOp) {
    context!.translateBy(x: -originOp.delta.dh.value, y: -originOp.delta.dv.value);
  }
  
  func executeLine(lineop : LineOp) {
    let qd_points = lineop.getPoints(current: penState.location);
    let cg_points = qd_points.map({ CGPoint(qd_point:$0)});
    context!.setStrokeColor(ToCGColor(qdcolor: penState.drawColor));
    context!.setLineWidth(penState.penWidth.value);
    context!.strokeLineSegments(between: cg_points);
    if let last = qd_points.last {
      penState.location = last;
    }
  }

  func executePoly(polyop: PolygonOp) throws {
    let poly = polyop.GetPolygon(last: lastPoly);
    if poly.points.count > 0 {
      let cg_points = poly.points.map({ CGPoint(qd_point:$0)});
      context!.beginPath();
      context!.addLines(between: cg_points);
      // context!.closePath();
      try applyVerbToPath(verb: polyop.verb);
    }
  }
  
  func executeRect(rect : QDRect, verb: QDVerb) throws {
    context!.beginPath();
    context!.addRect(CGRect(qdrect: rect));
    context!.closePath();
    try applyVerbToPath(verb: verb);
  }
  
  func executeRect(rectop : RectOp) throws {
    let rect = rectop.rect ?? lastRect!;
    try executeRect(rect : rect, verb: rectop.verb);
    lastRect = rect;
  }
  
  func executeRoundRect(roundRectOp : RoundRectOp) throws {
    let rect = roundRectOp.rect ?? lastRoundRect!;
    context!.beginPath();
    let path = CGMutablePath();
    let cornerWidth = penState.ovalSize.dh.value;
    let cornerHeight = penState.ovalSize.dv.value;
    path.addRoundedRect(in: CGRect(qdrect: rect), cornerWidth: cornerWidth, cornerHeight: cornerHeight);
    context!.addPath(path);
    context!.closePath();
    try applyVerbToPath(verb: roundRectOp.verb);
  }
  
  func executeOval(ovalOp: OvalOp) throws {
    let rect = ovalOp.rect ?? lastOval!;
    context!.beginPath();
    context!.addEllipse(in: CGRect(qdrect: rect));
    context!.closePath();
    try applyVerbToPath(verb: ovalOp.verb);
    lastOval = rect;
  }
  

  func executeArc(arcOp: ArcOp) throws {
    let rect = arcOp.rect!;
    try executeRect(rect: rect, verb: QDVerb.frame);
    let width = rect.dimensions.dh.value;
    let height = rect.dimensions.dv.value;
    let startAngle = deg2rad(arcOp.startAngle);
    let endAngle = deg2rad(arcOp.angle);
    print("Arc: \(rect)")
  
    context!.saveGState();
    context!.beginPath();
    context!.translateBy(x: rect.center.horizontal.value, y: rect.center.vertical.value);
    context!.scaleBy(x: width * 0.5, y: height * 0.5);
    /*context!.addRect(CGRect(origin: CGPoint(x: -0.5, y: -0.5), size: CGSize(width: 1.0, height: 1.0)));
    context!.strokePath();*/
    
    /// startAngle The angle to the starting point of the arc, measured in radians from the positive x-axis.
    /// endAngle The angle to the end point of the arc, measured in radians from the positive x-axis.
    context!.addArc(center: CGPoint(x:0, y:0), radius: 1.0, startAngle: startAngle, endAngle: endAngle, clockwise: true);
    // try applyVerbToPath(verb: arcOp.verb);
    context!.fillPath();
    context!.restoreGState();
  }
  
  func executeRegion(regionOp: RegionOp) throws {
    let region = regionOp.region ?? lastRegion!;
    if region.isRect {
      try executeRect(rect: region.boundingBox, verb: regionOp.verb);
    } else {
      let qdRects = region.rects.map({CGRect(qdrect: $0)});
      context!.beginPath();
      context!.addRects(qdRects);
      context!.closePath();
      try applyVerbToPath(verb: regionOp.verb);
    }
    lastRegion = region;
  }
  
  func getTraits() -> CTFontSymbolicTraits {
    var traits : CTFontSymbolicTraits = [];
    if fontState.fontStyle.contains(.italicBit) {
      traits.insert(.traitItalic);
    }
    if fontState.fontStyle.contains(.boldBit) {
      traits.insert(.traitBold);
    }
    if fontState.fontStyle.contains(.condenseBit) {
      traits.insert(.traitCondensed);
    }
    if fontState.fontStyle.contains(.extendBit) {
      traits.insert(.traitExpanded);
    }
    return traits;
  }
  
  func renderString(text : String) {
    let fontName = SubstituteFontName(fontName: fontState.getFontName()) as CFString;
    let fontSize = CGFloat(fontState.fontSize);
    let fgColor = ToCGColor(qdcolor: penState.fgColor);
    let bgColor = ToCGColor(qdcolor: penState.bgColor);
    let parentFont = CTFontCreateWithName(fontName, fontSize, nil);
    let mask : CTFontSymbolicTraits = [.traitItalic, .traitBold];
    let font = CTFontCreateCopyWithSymbolicTraits(
        parentFont, fontSize, nil, getTraits(), mask) ?? parentFont ;
    let lineText = NSMutableAttributedString(string: text);
    let range = NSMakeRange(0, lineText.length);
    lineText.addAttribute(
      kCTFontAttributeName as NSAttributedString.Key, value: font, range: range);
    if fontState.fontStyle.contains(.ulineBit) {
      lineText.addAttribute(
        kCTUnderlineStyleAttributeName as NSAttributedString.Key , value: CTUnderlineStyle.single.rawValue, range: range);
    }
    // Start work
    context!.saveGState();
    context!.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0);
    if fontState.fontStyle.contains(.outlineBit) {
      lineText.addAttribute(
        kCTForegroundColorAttributeName as NSAttributedString.Key, value: bgColor, range: range);
      lineText.addAttribute(
        kCTStrokeColorAttributeName as NSAttributedString.Key, value: fgColor, range: range);
      context!.setTextDrawingMode(.fillStroke);
    } else {
      lineText.addAttribute(
        kCTForegroundColorAttributeName as NSAttributedString.Key, value: fgColor, range: range);
      context!.setTextDrawingMode(.fill);
    }
    let lineToDraw: CTLine = CTLineCreateWithAttributedString(lineText);
    context!.textPosition = CGPoint(qd_point: fontState.location);
    CTLineDraw(lineToDraw, context!);
    context!.restoreGState();
  }
  
  func executeText(textOp: LongTextOp) {
    fontState.location = textOp.position;
    renderString(text: textOp.text);
  }
  
  func executeText(textOp: DHDVTextOp) {
    fontState.location = fontState.location + textOp.delta;
    renderString(text: textOp.text);
  }
  
  func executeComment(commentOp: CommentOp) {
    // Do something
  }
  
  // Bitmap op
  // https://gist.github.com/josephlord/e69d196cccc09b43769b
  
  func executeBitRect(bitRectOp: BitRectOpcode) throws {
    let colorSpace = try GetColorSpace(bit_opcode: bitRectOp);
    let bitmapInfo = CGBitmapInfo();
    let data = bitRectOp.bitmapInfo.data;
    let bounds = bitRectOp.bitmapInfo.bounds;
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    let image = CGImage(
      width: bounds.dimensions.dh.intValue,
      height: bounds.dimensions.dv.intValue,
      bitsPerComponent: bitRectOp.bitmapInfo.cmpSize,
      bitsPerPixel: bitRectOp.bitmapInfo.pixelSize,
      bytesPerRow: bitRectOp.bitmapInfo.rowBytes,
      space: colorSpace, bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: CGColorRenderingIntent.defaultIntent);
    context!.drawFlipped(
        image!,
        in: CGRect(qdrect: bitRectOp.bitmapInfo.dstRect!));
  }
  
  func executeDirectBitOp(directBitOp: DirectBitOpcode) {
    var  bitmapInfo : CGBitmapInfo;
    if directBitOp.bitmapInfo.pixMapInfo?.pixelSize == 16 {
      bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue);
    } else {
      bitmapInfo = CGBitmapInfo();
    }
      
    let data = directBitOp.bitmapInfo.data;
    let bounds = directBitOp.bitmapInfo.bounds;
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    let image = CGImage(
      width: bounds.dimensions.dh.intValue,
      height: bounds.dimensions.dv.intValue,
      bitsPerComponent: directBitOp.bitmapInfo.cmpSize,
      bitsPerPixel: directBitOp.bitmapInfo.pixelSize,
      bytesPerRow: directBitOp.bitmapInfo.rowBytes,
      space: rgbSpace, bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: CGColorRenderingIntent.defaultIntent);
    context!.drawFlipped(
        image!,
        in: CGRect(qdrect: directBitOp.bitmapInfo.dstRect!));
  }
  
  func executeQuickTime(quicktimeOp : QuickTimeOpcode) {
    let imageSource = CGImageSourceCreateWithData(quicktimeOp.quicktimePayload.data! as CFData, nil);
    let image = CGImageSourceCreateImageAtIndex(imageSource!, 0, nil);
    context!.drawFlipped(
        image!,
        in: CGRect(qdrect: quicktimeOp.quicktimePayload.dstRect));
  }
  
  func executeDefHighlight() throws {
    if let cgColor = highlightColor {
      penState.highlightColor = try ToQDColor(color: cgColor);
    }
  }
  
  func execute(opcode: OpCode) throws {
    switch opcode {
    case let penOp as PenStateOperation:
      penOp.execute(penState: &penState);
    case let fontOp as FontStateOperation:
      fontOp.execute(fontState: &fontState);
    case let textOp as LongTextOp:
      executeText(textOp: textOp);
    case is PictureOperation:
      break;
    case let originOp as OriginOp:
      executeOrigin(originOp:originOp);
    case let textOp as DHDVTextOp:
      executeText(textOp : textOp);
    case let lienOp as LineOp:
      executeLine(lineop: lienOp);
    case let rectop as RectOp:
      try executeRect(rectop: rectop);
    case let roundRectOp as RoundRectOp:
      try executeRoundRect(roundRectOp: roundRectOp)
    case let polyop as PolygonOp:
      try executePoly(polyop: polyop);
    case let arcOp as ArcOp:
      try executeArc(arcOp: arcOp);
    case let bitRectOp as BitRectOpcode:
      try executeBitRect(bitRectOp: bitRectOp);
    case let directBitOp as DirectBitOpcode:
      executeDirectBitOp(directBitOp: directBitOp);
    case let ovalOp as OvalOp:
      try executeOval(ovalOp: ovalOp);
    case let regionOp as RegionOp:
      try executeRegion(regionOp: regionOp);
    case let quicktimeOp as QuickTimeOpcode:
      executeQuickTime(quicktimeOp: quicktimeOp);
   case let commentOp as CommentOp:
      executeComment(commentOp:commentOp);
    case is DefHiliteOp:
      try executeDefHighlight();
    default:
      print("     Ignoring \(opcode)");
      break;
    }
  }
  
  // https://developer.apple.com/documentation/coregraphics/cgpdfcontext/auxiliary_dictionary_keys?language=objc
  func execute(picture: QDPicture) throws {
    
    for opcode in picture.opcodes {
      try execute(opcode:opcode);
    }
  }
  
  var context : CGContext?;
  
  var penState : PenState;
  var fontState : QDFontState;
  var lastPoly : QDPolygon?;
  var lastRect : QDRect?;
  var lastRoundRect: QDRect?;
  var lastOval : QDRect?;
  var lastRegion :QDRegion?;
  let rgbSpace : CGColorSpace;
  var highlightColor : CGColor?;
  
}

class PDFRenderer : QuickdrawCGRenderer {
   init(url : CFURL)  {
     self.url = url;
    super.init(context: nil);
  }
  
  override func execute(picture: QDPicture) throws {
    var mediabox = CGRect(qdrect: picture.frame);
    context = CGContext(url, mediaBox: &mediabox, nil);
    context!.beginPDFPage(nil);
    context!.scaleBy(x: 1.0, y: -1.0);
    let height = picture.frame.dimensions.dv.value;
    context!.translateBy(x: 0.0, y: -height);
    context!.translateBy(x: 0 , y: 2.0 * -picture.frame.topLeft.vertical.value);
    try super.execute(picture: picture);
    context!.endPDFPage();
    context!.closePDF();
  }
  
  let url : CFURL;
}
