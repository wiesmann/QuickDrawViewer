//
//  main.swift
//  QuickDrawConverter
//
//  Created by Matthias Wiesmann on 12.08.2025.
//

import Foundation

func loadFileFromLocalPath(_ localFilePath: String) ->Data? {
  return try? Data(contentsOf: URL(fileURLWithPath: localFilePath))
}

func stdOutWrite(_ string: String) {
  try! FileHandle.standardOutput.write(contentsOf: Data(string.utf8))
}

func stdErrWrite(_ string: String) {
  try! FileHandle.standardError.write(contentsOf: Data(string.utf8))
}

for argument in CommandLine.arguments.dropFirst() {
  if let data = loadFileFromLocalPath(argument) {
    do {
      stdOutWrite("Reading \(argument)");
      let parser = try QDParser(data: data);
      parser.filename = argument;
      stdOutWrite("Converting \(argument) ");
      let picture = try parser.parse();
      try data.write(to: URL(fileURLWithPath: picture.pdfFilename), options: .atomic);
    } catch {
      stdErrWrite("Error \(error) while converting \(argument)");
    }
  }
}
