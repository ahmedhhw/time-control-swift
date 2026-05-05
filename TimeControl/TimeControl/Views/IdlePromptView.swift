//
//  IdlePromptView.swift
//  TimeControl
//

import SwiftUI

struct IdlePromptView: View {
    let onStartTask: () -> Void
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var slideOffset: CGFloat = -80
    @State private var opacity: Double = 0
    @State private var showSnoozeMenu: Bool = false

    private let snoozeOptions: [(label: String, minutes: Int)] = [
        ("Snooze 15 min", 15),
        ("Snooze 30 min", 30),
        ("Snooze 1 hour", 60),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "timer")
                        .foregroundColor(.accentColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No task is running")
                            .font(.headline)
                        Text("You've been active. Want to track what you're working on?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss")
                }

                // Action buttons
                HStack(spacing: 8) {
                    Button(action: onStartTask) {
                        Text("Start a Task")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button(action: onDismiss) {
                        Text("Not Now")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                // Snooze menu
                HStack {
                    Spacer()
                    Menu {
                        ForEach(snoozeOptions, id: \.minutes) { option in
                            Button(option.label) {
                                onSnooze(option.minutes)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Snooze")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(14)
        }
        .frame(width: 360)
        .offset(y: slideOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                slideOffset = 0
                opacity = 1
            }
        }
    }
}

#Preview {
    IdlePromptView(
        onStartTask: {},
        onDismiss: {},
        onSnooze: { _ in }
    )
    .padding()
    .frame(width: 380, height: 200)
}
