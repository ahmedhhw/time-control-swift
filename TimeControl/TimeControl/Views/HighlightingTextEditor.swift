//
//  HighlightingTextEditor.swift
//  TimeControl
//

import SwiftUI
import AppKit

struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var searchQuery: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        HighlightingTextEditor.applyHighlights(to: textView, query: searchQuery)
    }

    // MARK: - Static highlight logic (also used by tests)

    static func applyHighlights(to textView: NSTextView, query: String) {
        guard let storage = textView.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.removeAttribute(.backgroundColor, range: fullRange)
        storage.removeAttribute(.foregroundColor, range: fullRange)

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let body = storage.string
        let nsBody = body as NSString
        var searchRange = NSRange(location: 0, length: nsBody.length)
        var firstMatch: NSRange? = nil

        while searchRange.location < nsBody.length {
            let found = nsBody.range(of: trimmed, options: .caseInsensitive, range: searchRange)
            guard found.location != NSNotFound else { break }
            storage.addAttribute(.backgroundColor, value: NSColor.yellow, range: found)
            storage.addAttribute(.foregroundColor, value: NSColor.black, range: found)
            if firstMatch == nil { firstMatch = found }
            searchRange = NSRange(location: found.location + found.length,
                                  length: nsBody.length - found.location - found.length)
        }

        if let first = firstMatch {
            textView.scrollRangeToVisible(first)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if text != tv.string {
                text = tv.string
            }
        }
    }
}
