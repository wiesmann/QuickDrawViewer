//
//  QuickDrawViewerApp.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import SwiftUI


struct HelpMenu: View {
  var body: some View {
    Group {
      Link("QuickDraw Viewer Project", destination: URL(
        string: "https://github.com/wiesmann/QuickDrawViewer")!)
    }
  }
}

@main
struct QuickDrawViewerApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: QuickDrawViewerDocument()) { file in
      ContentView(document: file.$document)
    }.commands {
      CommandGroup(replacing: .help) {
        HelpMenu()
      }
    }
  }
}
