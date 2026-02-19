//
//  ExportWindowManager.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

class ExportWindowManager: ObservableObject {
    static let shared = ExportWindowManager()
    private var exportWindow: NSWindow?
    
    func showExportWindow(with exportText: String) {
        closeExportWindow()
        
        let contentView = ExportAllTasksView(exportText: exportText)
        let hostingView = NSHostingView(rootView: contentView)
        
        guard let screen = NSScreen.main else { return }
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 600
        
        let xPos = screen.visibleFrame.midX - windowWidth / 2
        let yPos = screen.visibleFrame.midY - windowHeight / 2
        
        let window = NSWindow(
            contentRect: NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Export All Tasks"
        window.contentView = hostingView
        window.minSize = NSSize(width: 400, height: 300)
        
        exportWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    
    func closeExportWindow() {
        exportWindow?.close()
        exportWindow = nil
    }
}
