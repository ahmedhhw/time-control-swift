//
//  OpacityPopoverView.swift
//  TimeControl
//

import SwiftUI

struct OpacityPopoverView: View {
    @State private var opacity: Double
    let onChange: (Double) -> Void

    init(initialOpacity: Double, onChange: @escaping (Double) -> Void) {
        self._opacity = State(initialValue: initialOpacity)
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Window Opacity")
                    .font(.headline)
                Spacer()
                Text("\(Int(opacity * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: $opacity,
                in: WindowOpacityStore.minimum...WindowOpacityStore.maximum
            )
            .onChange(of: opacity) { newValue in
                onChange(newValue)
            }

            HStack {
                Text("\(Int(WindowOpacityStore.minimum * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset") {
                    opacity = WindowOpacityStore.maximum
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Spacer()
                Text("\(Int(WindowOpacityStore.maximum * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
