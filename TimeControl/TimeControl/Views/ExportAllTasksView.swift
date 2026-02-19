//
//  ExportAllTasksView.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

struct ExportAllTasksView: View {
    let exportText: String
    @State private var isCopied: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Export All Tasks")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportText, forType: .string)
                    isCopied = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    HStack {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.body)
                        Text(isCopied ? "Copied!" : "Copy All")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                TextEditor(text: .constant(exportText))
                    .font(.system(.title3, design: .monospaced))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
