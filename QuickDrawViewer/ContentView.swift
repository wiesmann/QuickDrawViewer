//
//  ContentView.swift
//  QuickDrawViewer
//
//  Created by Matthias Wiesmann on 01.01.2024.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: QuickDrawViewerDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(QuickDrawViewerDocument()))
}
