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
      Link(String(localized: "QuickDraw Viewer Project"), destination: URL(
        string: "https://github.com/wiesmann/QuickDrawViewer")!);
      Link(String(localized: "License"), destination: URL(
        string: "https://www.apache.org/licenses/LICENSE-2.0")!);
    }
  }
}

@main
struct QuickDrawViewerApp: App {
  var body: some Scene {
    DocumentGroup(viewing: QuickDrawViewerDocument.self) { file in
      ContentView(document: file.document)}
    .commands {
      CommandGroup(replacing: .help) {
        HelpMenu()
      }
    }
  }
}
