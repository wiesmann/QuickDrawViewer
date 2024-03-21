//
//  QuickDrawRender.swift
//  QuickDrawKit
//
//  Created by Matthias Wiesmann on 03.12.2023.
//
// Renderer based on Core Graphics, Image-IO and Core-Text.

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import os


enum CoreGraphicRenderError : LocalizedError {
  case noContext(message: String);
  case noPdfContext(rect: CGRect);
  case notRgbColor(color: CGColor);
  case imageCreationFailed(message: String, quicktimeOpcode: QuickTimeOpcode);
  case imageSourceFailure(status: CGImageSourceStatus);
  case imageFailure(message: String, metadata: PixMapMetadata);
  case unsupportedOpcode(opcode: OpCode);
  case inconsistentPoly(message: String);
  case unsupportedMode(mode: QuickDrawTransferMode);
}

extension CGImageSourceStatus : CustomStringConvertible {
  public var description: String {
    switch self {
    case .statusUnexpectedEOF: return String(localized: "Unexpected end-of-file");
    case .statusInvalidData: return String(localized: "Invalid data");
    case .statusUnknownType: return String(localized: "Unknown image type");
    case .statusIncomplete: return String(localized: "Incomplete");
    case .statusReadingHeader: return String(localized: "Reading header");
    case .statusComplete: return String(localized: "Complete");
    default:
      return String(localized: "Unknown");
    }
  }
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
  /// Construct a CoreGraphics rectangle from a QuickDraw one
  /// - Parameter qdrect: QuickDraw rectangle.
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

extension CGAffineTransform {
  init(qdTransform: [[FixedPoint]]) {
    self.init(
      qdTransform[0][0].value, qdTransform[0][1].value,
      qdTransform[1][0].value, qdTransform[1][1].value,
      qdTransform[2][0].value, qdTransform[2][1].value);
  }
}

/// Convert a QuickDraw RGB color into a CoreGraphic one.
/// - Parameter qdcolor: color to convert
/// - Returns: corresponding Core Graphics Colour.
func ToCGColor(qdcolor: QDColor) -> CGColor {
  let red = CGFloat(qdcolor.red) / 0x10000;
  let green = CGFloat(qdcolor.green) / 0x10000;
  let blue = CGFloat(qdcolor.blue) / 0x10000;
  return CGColor(red: red, green: green, blue: blue, alpha: 1.0);
}

/// Convenience function to convert a float in the 0..1 range to a UInt16.
/// - Parameter value: float value in the 0..1 range.
/// - Returns: corresponding UInt16 value
func FloatToUInt16(_ value: CGFloat) -> UInt16 {
  return UInt16(value * 0x10000);
}

/// Convert a CoreGraphics colour back into a QuickDraw one
/// - Parameter color: Core Graphics color to
/// - Throws: notRgbColor if the colour is not in the RGB format.
/// - Returns:a QuickDraw color.
func ToQDColor(color: CGColor) throws -> QDColor  {
  guard color.numberOfComponents == 3 else {
    throw CoreGraphicRenderError.notRgbColor(color: color);
  }
  guard let components = color.components else {
    throw CoreGraphicRenderError.notRgbColor(color: color);
  }
  let red = FloatToUInt16(components[0]);
  let green = FloatToUInt16(components[1]);
  let blue = FloatToUInt16(components[2]);
  return QDColor(red: red, green: green, blue: blue);
}

/// Convert a font name from the classic mac universe ino a corresponding one on Mac OS X.
/// - Parameter fontName: Font name
/// - Returns: A font-name that probably exists on Mac OS X.
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

let tau = 2.0 * .pi;

/// Convert degrees as used in QuickDraw to radians as used by CoreGraphics
/// - Parameter number: angle in degrees, 0° is vertical.
/// - Returns: radians, from the X axis
///
///
func deg2rad<T: BinaryInteger>(_ angle: T) -> Double {
  return -Double(angle + 90) * tau / 360;
}


/// Renderer that wraps a core-graphics context.
/// All QuickDraw operations are translated into Core Graphics, Core Text, or Core Image ones.
/// Ideally, most of the rendering logic should be decoupled from the rendering implementation.
/// We are not there yet (and we only have one rendered anyway).
class QuickdrawCGRenderer : QuickDrawRenderer, QuickDrawPort {
  
  
  init(context : CGContext?) {
    self.context = context;
    penState = PenState();
    fontState = QDFontState();
    rgbSpace = CGColorSpaceCreateDeviceRGB();
  }
  
  /// Convert a QuickDraw CLUT (color-table) to a Core-Graphic Color-Space
  /// - Parameter clut: A Quickdraw color-table with a most 256 entries.
  /// - Returns: A Core Graphics color-space
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
  
  /// Build a color space to paint using the a 1 bit pattern.
  /// - Returns: A 1 bit color-space with the background color (0) and the foreground color (1).
  func paintColorSpace() -> CGColorSpace {
    var data : [UInt8] = [];
    data.append(contentsOf: penState.bgColor.rgb);
    data.append(contentsOf: penState.fgColor.rgb);
    return CGColorSpace(indexedBaseSpace: rgbSpace, last: 1, colorTable: &data)!;
  }
  
  /// Paint the current path using the current pattern.
  func paintPath() throws {
    // Check if the pattern can be replaced with a color.
    if penState.drawPattern.isShade {
      let color = penState.drawColor;
      context!.setFillColor(ToCGColor(qdcolor: color));
      context!.fillPath();
      return;
    }
    
    let area = CGRect(x: 0, y: 0, width: 8, height: 8);
    context!.saveGState();
    context!.clip();
    let data = penState.drawPattern.bytes;
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    let bitmapInfo = CGBitmapInfo();
    let patternImage = CGImage(
      width: penState.drawPattern.dimensions.dh.rounded,
      height: penState.drawPattern.dimensions.dv.rounded,
      bitsPerComponent: penState.drawPattern.cmpSize,
      bitsPerPixel: penState.drawPattern.pixelSize,
      bytesPerRow: penState.drawPattern.rowBytes,
      space: paintColorSpace(),
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: CGColorRenderingIntent.defaultIntent)!;
    context!.drawFlipped(patternImage, in: area, byTiling: true);
    context!.restoreGState();
  }
  
  func applyMode(mode: QuickDrawTransferMode) throws {
    switch mode {
    case .copyMode:
      context!.setBlendMode(.normal);
    case .orMode:
      context!.setBlendMode(.darken);
    case .xorMode:
      context!.setBlendMode(.xor);
    case .notOrMode:
      context!.setBlendMode(.destinationAtop);
    case .notBic:
      context!.setBlendMode(.normal);
    case .notCopyMode:
      context!.setBlendMode(.darken);
    default:
      throw CoreGraphicRenderError.unsupportedMode(mode: mode);
    }
  }
  
  /// Main _painting_ function, renders the current path using a defined Quickdraw verb.
  ///
  /// - Parameter verb: type of rendering (paint, draw)
  func applyVerbToPath(verb: QDVerb) throws {
    try applyMode(mode: penState.mode.mode);
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
    case QDVerb.ignore:
      break;
    }
  }
  
  func executeOrigin(originOp: OriginOp) {
    context!.translateBy(x: -originOp.delta.dh.value, y: -originOp.delta.dv.value);
  }
  
  func stdLine(points: [QDPoint]) throws {
    guard portBits.contains(.lineEnable) else {
      return;
    }
    if let poly = polyAccumulator {
      poly.AddLine(line: points);
    } else {
      let cg_points = points.map({ CGPoint(qd_point:$0)});
      context!.addLines(between: cg_points);
      try applyVerbToPath(verb: .frame);
    }
    if let last = points.last {
      penState.location = last;
    }
  }
  
  func stdPoly(polygon: QDPolygon, verb: QDVerb) throws {
    guard portBits.contains(.polyEnable) else {
      return;
    }
    if polygon.points.count > 0 {
      let cg_points = polygon.points.map({ CGPoint(qd_point:$0)});
      context!.beginPath();
      context!.addLines(between: cg_points);
      if polygon.closed {
        context!.closePath();
      }
      try applyVerbToPath(verb: verb);
    }
    lastPoly = polygon;
  }
  
  /// Bottleneck function for rectangle rendering.
  /// - Parameters:
  ///   - rect: rectangle to draw
  ///   - verb: QuickDraw verb to use for drawing.
  func stdRect(rect : QDRect, verb: QDVerb) throws {
    guard portBits.contains(.rectEnable) else {
      return;
    }
    context!.beginPath();
    context!.addRect(CGRect(qdrect: rect));
    context!.closePath();
    try applyVerbToPath(verb: verb);
    lastRect = rect;
  }
  
  func stdRoundRect(rect : QDRect, verb: QDVerb) throws {
    guard portBits.contains(.rRectEnable) else {
      return;
    }
    context!.beginPath();
    let path = CGMutablePath();
    // Core graphics dies if the corners are too big
    let cornerWidth = min(penState.ovalSize.dh, rect.dimensions.dh >> 1).value;
    let cornerHeight = min(penState.ovalSize.dv, rect.dimensions.dv >> 1).value;
    path.addRoundedRect(in: CGRect(qdrect: rect), cornerWidth: cornerWidth, cornerHeight: cornerHeight);
    context!.addPath(path);
    context!.closePath();
    try applyVerbToPath(verb: verb);
  }
  
  func stdOval(rect : QDRect, verb : QDVerb) throws {
    guard portBits.contains(.ovalEnable) else {
      return;
    }
    context!.beginPath();
    context!.addEllipse(in: CGRect(qdrect: rect));
    context!.closePath();
    try applyVerbToPath(verb: verb);
    lastRect = rect;
  }
  
  func stdAngle(rect: QDRect, startAngle : Int16, angle: Int16, verb: QDVerb) throws {
    guard portBits.contains(.arcEnable) else {
      return;
    }
    /// Compute stuff
    let width = rect.dimensions.dh.value;
    let height = rect.dimensions.dv.value;
    let radStartAngle = deg2rad(startAngle);
    let radEndAngle = deg2rad(startAngle + angle);
    let clockwise = angle > 0;
    /// Core graphics can only do angles in a circle, so do it on the unit circle, and scale it.
    context!.saveGState();
    context!.beginPath();
    context!.translateBy(x: rect.center.horizontal.value, y: rect.center.vertical.value);
    context!.scaleBy(x: -width * 0.5, y: height * 0.5);
    
    /// startAngle The angle to the starting point of the arc, measured in radians from the positive x-axis.
    /// endAngle The angle to the end point of the arc, measured in radians from the positive x-axis.
    context!.move(to: CGPoint(x: 0, y: 0));
    context!.addArc(
        center: CGPoint(x:0, y:0),
        radius: 1.0,
        startAngle: radStartAngle, endAngle: radEndAngle, clockwise: clockwise);
    context!.move(to: CGPoint(x: 0, y: 0));
    try applyVerbToPath(verb: verb);
    // context!.fillPath();
    context!.restoreGState();
  }
  
  func stdRegion(region: QDRegion, verb: QDVerb) throws {
    guard portBits.contains(.rgnEnable) else {
      return;
    }
    let qdRects = region.getRects().map({CGRect(qdrect: $0)});
    context!.beginPath();
    context!.addRects(qdRects);
    context!.closePath();
    try applyVerbToPath(verb: verb);
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
  
  func stdText(text : String) throws {
    guard portBits.contains(QDPortBits.textEnable) else {
      return;
    }
    
    let fontName = SubstituteFontName(fontName: fontState.getFontName()) as CFString;
    let fontSize = CGFloat(fontState.fontSize.value);
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
    try applyMode(mode: fontState.fontMode.mode);
    // Use the ratios, but invert the y axis
    context!.textMatrix = CGAffineTransform(scaleX: fontState.xRatio.value, y: -fontState.yRatio.value);
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
    
    let position = CGPoint(qd_point: fontState.location);
    
    // TODO: use fontState.textCenter to adjust the width of strings.
    if let pictRect = fontState.textPictRecord {
      if pictRect.angle != FixedPoint.zero {
        let x = position.x + (fontState.textCenter?.dh ?? FixedPoint.zero).value;
        let y = position.y + (fontState.textCenter?.dv ?? FixedPoint.zero).value;
        let angle = deg2rad(pictRect.angle.rounded);
        context!.translateBy(x: x, y: y);
        context!.rotate(by: angle);
        context!.translateBy(x: -x, y: -y)
      }
    }
    
    let lineToDraw: CTLine = CTLineCreateWithAttributedString(lineText);
    
    context!.textPosition = position
    CTLineDraw(lineToDraw, context!);
    context!.restoreGState();
    fontState.textCenter = nil;
  }
  
  func executeComment(commentOp: CommentOp) throws {
    switch (commentOp.kind, commentOp.payload) {
    case (.textBegin, .fontStatePayload(let fontOp)):
      fontOp.execute(fontState: &fontState);
      portBits = [.textEnable];
    case (.textEnd, _):
      portBits = QDPortBits.defaultState;
    case (.polyBegin, _):
      polyAccumulator = QDPolygon();
    case (.polyClose, _):
      guard let poly = polyAccumulator else {
        throw CoreGraphicRenderError.inconsistentPoly(
            message: String(localized: "Closing non existing polygon."));
      }
      poly.closed = true;
    case (.polySmooth, .polySmoothPayload(let polyVerb)):
      guard let poly = polyAccumulator else {
        throw CoreGraphicRenderError.inconsistentPoly(
          message: String(localized: "Ending non existing polygon."));
      }
      poly.smooth = true;
      if polyVerb.contains(.polyClose) {
        poly.closed = true;
      }
      self.polyVerb = polyVerb;
    case (.polyIgnore, _):
      // Disabling the poly operations and executing it later (with polyClose)
      // Causes problems with patterns, which are converted to shades.
      break;
    case (.polyEnd, _):
      guard let poly = polyAccumulator else {
        throw CoreGraphicRenderError.inconsistentPoly(
          message: String(localized: "Ending non existing polygon."));
      }
      portBits = QDPortBits.defaultState;
      // Do something with polyverb?
      try stdPoly(polygon: poly, verb: QDVerb.frame);
      polyAccumulator = nil;
      polyVerb = nil;
    case (_, .penStatePayload(let penOp)):
      penOp.execute(penState: &penState);
    case (_, .fontStatePayload(let fontOp)):
      fontOp.execute(fontState: &fontState);
    default:
      break;
    }
  }
  
  /// Draw an indirect (palette) color image.
  /// - Parameters:
  ///   - metadata: description of the image
  ///   - destination: destination rectangle
  ///   - mode: quickdraw mode for painting
  ///   - data: pixel data
  ///   - clut: color table to use for lookups
  func executePaletteImage(metadata: PixMapMetadata, destination: QDRect, mode: QuickDrawTransferMode, data: [UInt8], clut: QDColorTable) throws {
    let colorSpace = try ToColorSpace(clut: clut);
    let bitmapInfo = CGBitmapInfo();
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    guard let image = CGImage(
      width: metadata.dimensions.dh.rounded,
      height: metadata.dimensions.dv.rounded,
      bitsPerComponent: metadata.cmpSize,
      bitsPerPixel: metadata.pixelSize,
      bytesPerRow: metadata.rowBytes,
      space: colorSpace, bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: CGColorRenderingIntent.defaultIntent) else {
      throw CoreGraphicRenderError.imageFailure(
          message: String(localized:"Could not create palette image."),
          metadata: metadata);
    }
    try applyMode(mode: mode);
    context!.drawFlipped(
      image,
      in: CGRect(qdrect: destination));
  }
  
  /// Execute palette bitmap operations
  /// - Parameter bitRectOp: the opcode to execute
  func executeBitRect(bitRectOp: BitRectOpcode) throws {
    guard let clut = bitRectOp.bitmapInfo.clut else {
      throw QuickDrawError.missingColorTableError;
    }
    guard portBits.contains(.bitsEnable) else {
      return;
    }
    return try executePaletteImage(
      metadata: bitRectOp.bitmapInfo,
      destination: bitRectOp.bitmapInfo.destinationRect,
      mode: bitRectOp.bitmapInfo.mode.mode,
      data: bitRectOp.bitmapInfo.data,
      clut: clut);
  }

  func getBitmapInfo(metadata: PixMapMetadata) -> CGBitmapInfo {
    switch metadata.pixelSize {
    case 16:
      return CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue);
    case 32:
      return CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue);
    default:
      return CGBitmapInfo();
    }
  }
  
  /// Render an RGB (direct) image
  /// - Parameters:
  ///   - metadata: header information with the dimension, rowBytees, depth etc.
  ///   - destination: QuickDraw destination rectangle.
  ///   - mode: QuickDraw rendering mode.
  ///   - data: raw data to render.
  func executeRGBImage(metadata: PixMapMetadata, destination: QDRect, mode: QuickDrawTransferMode, data: [UInt8]) throws {
    let bitmapInfo = getBitmapInfo(metadata: metadata);
    let cfData = CFDataCreate(nil, data, data.count)!;
    let provider = CGDataProvider(data: cfData)!;
    guard let image = CGImage(
      width: metadata.dimensions.dh.rounded,
      height: metadata.dimensions.dv.rounded,
      bitsPerComponent: metadata.cmpSize,
      bitsPerPixel: metadata.pixelSize,
      bytesPerRow: metadata.rowBytes,
      space: rgbSpace, bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: CGColorRenderingIntent.defaultIntent) else {
      throw CoreGraphicRenderError.imageFailure(
        message: String(localized:"Could not create RGB bitmap."),
        metadata: metadata);
    }
    try applyMode(mode: mode);
    context!.drawFlipped(
      image,
      in: CGRect(qdrect: destination));
  }
  
  func executeDirectBitOp(directBitOp: DirectBitOpcode) throws {
    guard portBits.contains(.bitsEnable) else {
      return;
    }
    return try executeRGBImage(
      metadata: directBitOp.bitmapInfo,
      destination: directBitOp.bitmapInfo.destinationRect,
      mode: directBitOp.bitmapInfo.mode.mode,
      data: directBitOp.bitmapInfo.data);
  }
  
  func executeQuickTime(quicktimeOp : QuickTimeOpcode) throws {
    let mode = quicktimeOp.quicktimePayload.mode.mode;
    // TODO: use QuickTime transform.
    guard let payload = quicktimeOp.quicktimePayload.idsc.data else {
      throw QuickTimeError.missingQuickTimePayload(quicktimeOpcode: quicktimeOp);
    }
    guard let destRec = quicktimeOp.quicktimePayload.srcMask?.boundingBox else {
      throw QuickDrawError.missingDestinationRect(message: "No destination for \(quicktimeOp)")
    }
    
    let qtImage = quicktimeOp.quicktimePayload.idsc;
    /// First option, the image data was decoded.
    switch qtImage.dataStatus {
    case let  .decoded(metadata):
      if let clut = metadata.clut {
        try executePaletteImage(metadata: metadata, destination: destRec, mode: mode, data: Array(payload), clut: clut);
      } else {
        try executeRGBImage(
          metadata: metadata, destination: destRec, mode: mode, data: Array(payload));
      }
      /// Prevent error message by disabling other procs.
      portBits = [.quickTimeEnable];
      return;
    default:
      break;
    }
    /// Second option, the image is something CoreGraphics can handle, like JPEG.
    let options : NSDictionary = [ kCGImageSourceTypeIdentifierHint: codecToContentType(qtImage:qtImage)];
    guard let imageSource = CGImageSourceCreateWithData(payload as CFData, options) else {
      throw CoreGraphicRenderError.imageCreationFailed(message: "CGImageSourceCreateWithData", quicktimeOpcode: quicktimeOp);
    }
    let status = CGImageSourceGetStatus(imageSource);
    guard status == .statusComplete else {
      throw CoreGraphicRenderError.imageSourceFailure(status: status);
    }
    let count = CGImageSourceGetCount(imageSource);
    guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
      throw CoreGraphicRenderError.imageCreationFailed(message: "CGImageSourceCreateImageAtIndex \(imageSource): \(count)", quicktimeOpcode: quicktimeOp);
    }
    context!.drawFlipped(
        image,
        in: CGRect(qdrect: quicktimeOp.quicktimePayload.srcMask!.boundingBox));
    /// Prevent error message by disabling other procs.
    portBits = [.quickTimeEnable];
  }
  
  func executeDefHighlight() throws {
    if let cgColor = highlightColor {
      penState.highlightColor = try ToQDColor(color: cgColor);
    }
  }
  
  /// Opcode dispatching function
  /// - Parameter opcode: opcode to dispatch
  func execute(opcode: OpCode) throws {
    switch opcode {
    case let penOp as PenStateOperation:
      penOp.execute(penState: &penState);
    case let fontOp as FontStateOperation:
      fontOp.execute(fontState: &fontState);
    case let portOp as PortOperation:
      var port : QuickDrawPort = self;
      try portOp.execute(port: &port);
    case let originOp as OriginOp:
      executeOrigin(originOp:originOp);
    case let bitRectOp as BitRectOpcode:
      try executeBitRect(bitRectOp: bitRectOp);
    case let directBitOp as DirectBitOpcode:
      try executeDirectBitOp(directBitOp: directBitOp);
    case let quicktimeOp as QuickTimeOpcode:
      try executeQuickTime(quicktimeOp: quicktimeOp);
    case let commentOp as CommentOp:
      try executeComment(commentOp:commentOp);
    case is DefHiliteOp:
      try executeDefHighlight();
    case is PictureOperation:
      break;
    default:
      throw CoreGraphicRenderError.unsupportedOpcode(opcode: opcode);
    }
  }
  
  /// Executes the picture into the graphical context.
  /// - Parameter picture: the quickdraw picture to render
  public func execute(picture: QDPicture, zoom: Double) throws {
    guard context != nil else {
      throw CoreGraphicRenderError.noContext(message: "No context associated with renderer.");
    }
    self.picture = picture;
    let origin = CGPoint(qd_point: picture.frame.topLeft);
    context!.translateBy(x: -origin.x, y: -origin.y);

    // TODO: figure out when this should be turned on.
    // Scaling causes regressions on old pictures.
    /*let vScale = QDResolution.defaultResolution.vRes.value / picture.resolution.vRes.value;
    let hScale = QDResolution.defaultResolution.hRes.value / picture.resolution.hRes.value;
    context!.scaleBy(x: hScale, y: vScale);*/
    context!.scaleBy(x: zoom, y: zoom);
    
    for opcode in picture.opcodes {
      do {
        try execute(opcode:opcode);
      } catch {
        logger.log(level: .error, "Failed rendering: \(error)");
      }
    }
  }
  
  // Target context.
  var context : CGContext?;
  // Picture being rendered.
  var picture : QDPicture?;
  // All QuickDraw operations are RGB space.
  let rgbSpace : CGColorSpace;
  // Native highlight color, get converted into QuickDraw
  // by DefHilite opcode.
  var highlightColor : CGColor?;
  // Quickdraw state
  var penState : PenState;
  var fontState : QDFontState;
  var portBits = QDPortBits.defaultState ;
  // Last shapes, used by the SameXXX operations.
  var lastPoly : QDPolygon = QDPolygon();
  var lastRect : QDRect = QDRect.empty;
  var lastRegion :QDRegion = QDRegion.empty;
  // Polygon for reconstruction.
  var polyAccumulator : QDPolygon?;
  var polyVerb : PolySmoothVerb?;
  
  // Logger
  let logger : Logger = Logger(subsystem: "net.codiferes.wiesmann.QuickDraw", category: "render");
}

/// Render the picture inside a PDF context.
class PDFRenderer : QuickdrawCGRenderer {
  
  init(url : CFURL)  {
    self.consumer = CGDataConsumer(url: url)!;
    super.init(context: nil);
  }
  
  init(data: CFMutableData) {
    self.consumer = CGDataConsumer(data: data)!;
    super.init(context: nil);
  }
  
  override func execute(picture: QDPicture, zoom: Double) throws {
    var mediabox = CGRect(qdrect: picture.frame);
    var meta  = [kCGPDFContextCreator: "QuickDrawCFRenderer"];
    if let filename = picture.filename {
      meta[kCGPDFContextTitle] = filename;
    }
    guard let context = CGContext(consumer: consumer, mediaBox: &mediabox, meta as CFDictionary) else {
      throw CoreGraphicRenderError.noPdfContext(rect: mediabox);
    }
    self.context = context;
    context.beginPDFPage(nil);
    // Flip for old-school PDF coordinates
    let height = picture.frame.dimensions.dv.value;
    context.scaleBy(x: 1.0, y: -1.0);
    context.translateBy(x: 0.0, y: -height);
    let origin = CGPoint(qd_point: picture.frame.topLeft);
    context.translateBy(x: origin.x, y: -origin.y);
    try super.execute(picture: picture, zoom: zoom);
    context.endPDFPage();
    context.closePDF();
  }
  
  let consumer : CGDataConsumer;
}
