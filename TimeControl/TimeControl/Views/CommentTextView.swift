//
//  CommentTextView.swift
//  TimeControl
//

import SwiftUI

struct CommentTextView: View {
    let text: String

    var body: some View {
        let plain = Self.htmlToPlain(text)
        let segments = LinkParser.parse(plain)
        segments.reduce(Text("")) { result, segment in
            switch segment {
            case .text(let s):
                return result + Text(s)
            case .link(let url):
                return result + Text(.init("[\(url.absoluteString)](\(url.absoluteString))"))
            }
        }
    }

    static func htmlToPlain(_ html: String) -> String {
        var result = html
        // <p>...</p> → content + newline
        result = result.replacingOccurrences(of: #"<p[^>]*>"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n")
        // <br> variants → newline
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        // strip remaining tags
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        // trim trailing whitespace/newlines
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
