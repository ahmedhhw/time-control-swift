//
//  SubtitleText.swift
//  TimeControl
//
//  Renders text with a white halo behind it (subtitle-style) so it stays legible
//  when the window background is translucent.
//

import SwiftUI

/// Broadcasts a window's current opacity to any SwiftUI view that wants to react
/// (e.g. for the subtitle halo). One instance per window.
final class WindowOpacityBroadcaster: ObservableObject {
    @Published var opacity: Double
    init(initial: Double) { self.opacity = initial }
}

/// Pure math for the stroke effect. Pulled out so it's directly unit-testable.
enum SubtitleTextStroke {
    /// Maximum halo width (in points) when the window is at minimum opacity.
    static let maxWidth: CGFloat = 2.5

    /// Halo stroke width in points for a given window opacity.
    /// At full opacity (1.0): 0pt (no halo). At minimum: `maxWidth`. Linear.
    static func width(forWindowOpacity opacity: Double) -> CGFloat {
        let t = transparencyFactor(forWindowOpacity: opacity)
        return maxWidth * CGFloat(t)
    }

    /// Halo opacity in [0, 1] for a given window opacity.
    /// At full opacity: 0 (invisible). At minimum: 1 (fully visible).
    static func haloOpacity(forWindowOpacity opacity: Double) -> Double {
        transparencyFactor(forWindowOpacity: opacity)
    }

    /// 0.0 when window is fully opaque, 1.0 when at the configured minimum.
    private static func transparencyFactor(forWindowOpacity opacity: Double) -> Double {
        let minOp = WindowOpacityStore.minimum
        let clamped = min(max(opacity, minOp), 1.0)
        let range = 1.0 - minOp
        guard range > 0 else { return 0 }
        return (1.0 - clamped) / range
    }
}

// MARK: - SwiftUI modifier

extension View {
    /// Draws white "subtitle-style" stroke behind this view's text, sized to the
    /// given window opacity. At full opacity the stroke is invisible (zero cost).
    func subtitleHalo(windowOpacity: Double) -> some View {
        modifier(SubtitleHaloModifier(windowOpacity: windowOpacity))
    }
}

private struct SubtitleHaloModifier: ViewModifier {
    let windowOpacity: Double

    func body(content: Content) -> some View {
        let width = SubtitleTextStroke.width(forWindowOpacity: windowOpacity)
        let alpha = SubtitleTextStroke.haloOpacity(forWindowOpacity: windowOpacity)

        if width <= 0.001 {
            content
        } else {
            content
                .shadow(color: Color.white.opacity(alpha), radius: 0, x:  width, y:  0)
                .shadow(color: Color.white.opacity(alpha), radius: 0, x: -width, y:  0)
                .shadow(color: Color.white.opacity(alpha), radius: 0, x:  0,     y:  width)
                .shadow(color: Color.white.opacity(alpha), radius: 0, x:  0,     y: -width)
                .shadow(color: Color.white.opacity(alpha * 0.6), radius: width, x: 0, y: 0)
        }
    }
}
