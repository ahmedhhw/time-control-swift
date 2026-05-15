//
//  CommandPaletteView.swift
//  TimeControl
//

import SwiftUI
import KeyboardShortcuts

struct CommandPaletteView: View {
    let actions: [AppAction]
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var selectedId: String? = nil
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any? = nil

    private var filtered: [AppAction] {
        CommandPaletteFilter.filter(actions: actions, searchText: searchText)
    }

    private var selectedAction: AppAction? {
        if let id = selectedId, let match = filtered.first(where: { $0.id == id }) {
            return match
        }
        return filtered.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                TextField("Search actions…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($searchFocused)
                    .onSubmit { commitSelection() }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if filtered.isEmpty {
                Spacer()
                Text("No matching actions")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filtered, id: \.id) { action in
                                actionRow(
                                    action: action,
                                    isSelected: action.id == selectedAction?.id,
                                    shortcutLabel: action.shortcutName.flatMap {
                                        CommandPaletteWindowManager.formatShortcut(for: $0)
                                    }
                                ) {
                                    execute(action)
                                }
                                .id(action.id)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: selectedId) { id in
                        let scrollTarget = id ?? filtered.first?.id
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(scrollTarget, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 420)
        .onAppear {
            searchFocused = true
            selectedId = filtered.first?.id
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                switch event.keyCode {
                case 125: // down arrow
                    moveSelection(by: +1)
                    return nil
                case 126: // up arrow
                    moveSelection(by: -1)
                    return nil
                case 53: // Escape
                    onDismiss()
                    return nil
                default:
                    return event
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onExitCommand { onDismiss() }
        .onChange(of: searchText) { _ in selectedId = filtered.first?.id }
    }

    private func moveSelection(by delta: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        let currentIndex = list.firstIndex(where: { $0.id == selectedId }) ?? 0
        let next = (currentIndex + delta).clamped(to: 0...(list.count - 1))
        selectedId = list[next].id
    }

    private func commitSelection() {
        guard let action = selectedAction else { return }
        execute(action)
    }

    private func execute(_ action: AppAction) {
        onDismiss()
        action.handler()
    }

    @ViewBuilder
    private func actionRow(
        action: AppAction,
        isSelected: Bool,
        shortcutLabel: String?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(action.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let label = shortcutLabel {
                    Text(label)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
