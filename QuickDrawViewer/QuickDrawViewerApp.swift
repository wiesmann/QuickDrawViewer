//
//  QuickDrawViewerApp.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import SwiftUI

@main
struct QuickDrawViewerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: QuickDrawViewerDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
