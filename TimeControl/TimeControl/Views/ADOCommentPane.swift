//
//  ADOCommentPane.swift
//  TimeControl
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ADOCommentPane: View {
    @ObservedObject var vm: ADOCommentViewModel

    var body: some View {
        switch vm.phase {
        case .idle:
            idleButton
        case .open, .sending:
            composeView
        case .sent:
            sentBanner
        case .queued:
            queuedBanner
        case .error:
            errorBanner
        }
    }

    // MARK: - Idle

    private var idleButton: some View {
        Button(action: vm.open) {
            Label("Add comment", systemImage: "bubble.left")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pasted image strip

    private var pastedImageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.pastedImages) { img in
                    PastedImageThumbnail(img: img) {
                        vm.removeImage(id: img.id)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Compose

    private var hasContent: Bool {
        !vm.commentText.trimmingCharacters(in: .whitespaces).isEmpty || !vm.pastedImages.isEmpty
    }

    private var composeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            MentionAwareEditor(text: $vm.commentText, vm: vm)
                .frame(minHeight: 48, maxHeight: 100)
                .disabled(vm.phase == .sending)
                .opacity(vm.phase == .sending ? 0.6 : 1)

            if !vm.pastedImages.isEmpty {
                pastedImageStrip
            }

            if vm.mentionQuery != nil {
                MentionDropdown(vm: vm)
            }

            HStack {
                Button("Cancel", action: vm.cancel)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .disabled(vm.phase == .sending)

                Spacer()

                Button(action: { Task { await vm.send() } }) {
                    if vm.phase == .sending {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text("Sending…")
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Send")
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
                .fontWeight(.medium)
                .disabled(!hasContent || vm.phase == .sending || vm.mentionQuery != nil)
                .opacity((!hasContent || vm.phase == .sending || vm.mentionQuery != nil) ? 0.4 : 1)
            }
        }
    }

    // MARK: - Sent

    private var sentBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)
            Text("Comment sent")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Queued

    private var queuedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
                .font(.subheadline)
            Text("Queued — offline")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Error

    private var errorBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
            Text("Failed to send")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button("Retry") { Task { await vm.retry() } }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.subheadline)
            Button(action: vm.dismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - NSViewRepresentable text editor with mention key interception

private struct MentionAwareEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var vm: ADOCommentViewModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MentionTextView()
        textView.mentionKeyHandler = context.coordinator.handleKey(event:)
        textView.imagePasteHandler = context.coordinator.handleImagePaste(data:rawFilename:)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderWidth = 0.5
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MentionTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = !context.coordinator.parent.vm.phase.isSending
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MentionAwareEditor

        init(_ parent: MentionAwareEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let newText = tv.string
            parent.text = newText
            parent.vm.handleTextChange(newText)
        }

        func handleImagePaste(data: Data, rawFilename: String) {
            MainActor.assumeIsolated {
                let n = parent.vm.pastedImages.count + 1
                let filename = "pasted-image-\(n).png"
                parent.vm.pasteImage(data, filename: filename)
            }
        }

        // keyDown is always called on the main thread, so MainActor.assumeIsolated is safe here.
        func handleKey(event: NSEvent) -> Bool {
            MainActor.assumeIsolated {
                guard parent.vm.mentionQuery != nil else { return false }
                switch event.keyCode {
                case 125: // down arrow
                    parent.vm.mentionMoveDown()
                    return true
                case 126: // up arrow
                    parent.vm.mentionMoveUp()
                    return true
                case 36, 76: // return / numpad enter
                    let idx = parent.vm.mentionSelectedIndex
                    guard idx < parent.vm.mentionResults.count else { return false }
                    parent.vm.selectMention(parent.vm.mentionResults[idx])
                    return true
                default:
                    return false
                }
            }
        }
    }
}

private class MentionTextView: NSTextView {
    var mentionKeyHandler: ((NSEvent) -> Bool)?
    var imagePasteHandler: ((Data, String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if mentionKeyHandler?(event) == true { return }
        super.keyDown(with: event)
    }

    /// Prefer handling ⌘V here so image paste works even when `paste(_:)` is not routed to this view.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           Self.eventIsPasteShortcut(event),
           tryConsumeImagePaste() {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Matches Edit ▸ Paste (⌘V) including layouts where the key does not produce `"v"`.
    private static func eventIsPasteShortcut(_ event: NSEvent) -> Bool {
        if event.charactersIgnoringModifiers?.lowercased() == "v" { return true }
        return event.keyCode == 9 // physical V key on ANSI / similar keyboards
    }

    // ⌘V / Edit ▸ Paste — intercept image pastes before plain-text insertion.
    override func paste(_ sender: Any?) {
        if tryConsumeImagePaste() { return }
        super.paste(sender)
    }

    /// Returns true if the pasteboard held an image and it was passed to the handler.
    private func tryConsumeImagePaste() -> Bool {
        guard let handler = imagePasteHandler,
              let data = Self.extractImagePNG(from: NSPasteboard.general) else { return false }
        handler(data, "")
        return true
    }

    private static func extractImagePNG(from pboard: NSPasteboard) -> Data? {
        if let objects = pboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = objects.first as? NSImage,
           let png = pngData(from: image) {
            return png
        }

        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where url.isFileURL {
                if let image = NSImage(contentsOf: url), let png = pngData(from: image) {
                    return png
                }
            }
        }

        let rawTypes: [NSPasteboard.PasteboardType] = [
            .png,
            NSPasteboard.PasteboardType(UTType.png.identifier),
            .tiff,
            NSPasteboard.PasteboardType(UTType.tiff.identifier),
            NSPasteboard.PasteboardType(UTType.gif.identifier),
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            NSPasteboard.PasteboardType(UTType.webP.identifier),
        ]
        for pbType in rawTypes {
            if let data = pboard.data(forType: pbType) {
                if pbType == .png || pbType.rawValue == UTType.png.identifier { return data }
                if let png = pngFromBitmapOrImage(data: data) { return png }
            }
        }

        if let item = pboard.pasteboardItems?.first {
            for type in item.types {
                guard let ut = UTType(type.rawValue), ut.conforms(to: .image),
                      let data = item.data(forType: type) else { continue }
                if ut == .png || ut.preferredMIMEType == "image/png" { return data }
                if let png = pngFromBitmapOrImage(data: data) { return png }
            }
        }

        if let image = NSImage(pasteboard: pboard), let png = pngData(from: image) {
            return png
        }
        return nil
    }

    private static func pngFromBitmapOrImage(data: Data) -> Data? {
        if let bitmap = NSBitmapImageRep(data: data),
           let png = bitmap.representation(using: .png, properties: [:]) {
            return png
        }
        if let image = NSImage(data: data), let png = pngData(from: image) {
            return png
        }
        return nil
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

// MARK: - Pasted image thumbnail

private struct PastedImageThumbnail: View {
    let img: PastedImage
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailImage
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            overlayBadge
        }
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let nsImage = NSImage(data: img.data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
        }
    }

    @ViewBuilder
    private var overlayBadge: some View {
        switch img.uploadState {
        case .pending:
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        case .uploading:
            ProgressView()
                .controlSize(.mini)
                .padding(4)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
                .offset(x: 4, y: -4)
        case .uploaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .shadow(radius: 1)
                .offset(x: 4, y: -4)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
                .shadow(radius: 1)
                .offset(x: 4, y: -4)
        }
    }
}

private extension ADOCommentViewModel.Phase {
    var isSending: Bool { self == .sending }
}
