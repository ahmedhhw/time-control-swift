//
//  FloatingTooltip.swift
//  TimeControl
//
//  Created on 2/11/26.
//

import SwiftUI

struct FloatingTooltip: ViewModifier {
    let text: String
    @State private var isHovered = false
    @State private var showTooltip = false
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if isHovered {
                            showTooltip = true
                        }
                    }
                } else {
                    showTooltip = false
                    TooltipWindowManager.shared.hide()
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: showTooltip) { visible in
                            if visible {
                                TooltipWindowManager.shared.show(text: text)
                            } else {
                                TooltipWindowManager.shared.hide()
                            }
                        }
                }
            )
    }
}

extension View {
    func floatingTooltip(_ text: String) -> some View {
        self.modifier(FloatingTooltip(text: text))
    }
}
