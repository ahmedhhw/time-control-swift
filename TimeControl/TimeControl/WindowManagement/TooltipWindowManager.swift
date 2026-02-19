//
//  TooltipWindowManager.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import AppKit

class TooltipWindowManager {
    static let shared = TooltipWindowManager()
    private var tooltipWindow: NSPanel?
    
    func show(text: String) {
        hide()
        
        let mouseLocation = NSEvent.mouseLocation
        
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .white
        label.backgroundColor = .clear
        label.sizeToFit()
        
        let padding: CGFloat = 12
        let tooltipWidth = label.frame.width + padding
        let tooltipHeight = label.frame.height + padding
        
        let offsetX: CGFloat = 10
        let offsetY: CGFloat = -20
        let tooltipX = mouseLocation.x + offsetX
        let tooltipY = mouseLocation.y + offsetY
        
        let tooltipFrame = NSRect(x: tooltipX, y: tooltipY, width: tooltipWidth, height: tooltipHeight)
        
        let tipWindow = NSPanel(contentRect: tooltipFrame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        tipWindow.isOpaque = false
        tipWindow.backgroundColor = .clear
        tipWindow.level = .statusBar
        tipWindow.isFloatingPanel = true
        tipWindow.becomesKeyOnlyIfNeeded = false
        tipWindow.hidesOnDeactivate = false
        tipWindow.ignoresMouseEvents = true
        tipWindow.hasShadow = true
        tipWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: tooltipWidth, height: tooltipHeight))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        containerView.layer?.cornerRadius = 6
        
        label.frame = NSRect(x: padding / 2, y: padding / 2, width: label.frame.width, height: label.frame.height)
        containerView.addSubview(label)
        
        tipWindow.contentView = containerView
        tipWindow.orderFront(nil)
        tooltipWindow = tipWindow
    }
    
    func hide() {
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }
}
