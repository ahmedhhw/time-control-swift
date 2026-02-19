//
//  FloatingWindowDelegate.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI
import AppKit

class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    let taskId: UUID
    private var pauseConfirmationWindow: NSPanel?
    
    init(taskId: UUID) {
        self.taskId = taskId
        super.init()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let isTaskRunning = FloatingWindowManager.shared.currentTask?.isRunning ?? false
        
        if !isTaskRunning {
            return true
        }
        
        showPauseConfirmationPanel(parentWindow: sender)
        return false
    }
    
    private func showPauseConfirmationPanel(parentWindow: NSWindow) {
        if pauseConfirmationWindow != nil {
            pauseConfirmationWindow?.orderFrontRegardless()
            return
        }
        
        let confirmationView = PauseTaskConfirmationView(
            onPause: { [weak self] in
                guard let self = self else { return }
                NotificationCenter.default.post(
                    name: NSNotification.Name("PauseTaskFromFloatingWindow"),
                    object: nil,
                    userInfo: ["taskId": self.taskId, "keepWindowOpen": false]
                )
                self.pauseConfirmationWindow?.close()
                self.pauseConfirmationWindow = nil
                parentWindow.close()
            },
            onCancel: { [weak self] in
                guard let self = self else { return }
                self.pauseConfirmationWindow?.close()
                self.pauseConfirmationWindow = nil
            }
        )
        
        let hostingView = NSHostingView(rootView: confirmationView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 150)
        
        let parentFrame = parentWindow.frame
        let xPos = parentFrame.midX - 150
        let yPos = parentFrame.midY - 75
        
        let window = NSPanel(
            contentRect: NSRect(x: xPos, y: yPos, width: 300, height: 150),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Pause Task?"
        window.contentView = hostingView
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = false
        window.hidesOnDeactivate = false
        
        pauseConfirmationWindow = window
        window.orderFrontRegardless()
        window.makeKey()
    }
}
