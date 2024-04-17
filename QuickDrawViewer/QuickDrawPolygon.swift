//
//  QuickDrawPolygon.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 17.04.2024.
//

import Foundation

class QDPolygon {
  
  init(boundingBox: QDRect?, points: [QDPoint]) {
    self.boundingBox = boundingBox;
    self.points = points;
    self.closed = false;
    self.smooth = false;
  }
  
  convenience init() {
    self.init(boundingBox: nil, points: []);
  }
  
  var boundingBox : QDRect?;
  var points : [QDPoint];
  var closed : Bool;
  var smooth : Bool;
  
  func AddLine(line : [QDPoint]) {
    if points.isEmpty {
      self.points = line;
      return;
    }
    if line.first == points.last {
      points.removeLast();
    }
    points.append(contentsOf: line);
  }
}

extension QuickDrawDataReader {
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
}

