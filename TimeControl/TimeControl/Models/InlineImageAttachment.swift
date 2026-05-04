//
//  InlineImageAttachment.swift
//  TimeControl
//

import AppKit

/// Inline image in the ADO comment editor; `pastedImageId` ties the attachment to `PastedImage` for upload and HTML output.
final class InlineImageAttachment: NSTextAttachment {
    let pastedImageId: UUID

    init(imageData: Data, pastedImageId: UUID) {
        self.pastedImageId = pastedImageId
        super.init(data: nil, ofType: nil)
        guard let nsImage = NSImage(data: imageData) else { return }
        image = nsImage
        let w = max(nsImage.size.width, 1)
        let h = max(nsImage.size.height, 1)
        let maxW: CGFloat = 280
        let scale = min(1, maxW / w)
        bounds = CGRect(x: 0, y: -4, width: w * scale, height: h * scale)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
