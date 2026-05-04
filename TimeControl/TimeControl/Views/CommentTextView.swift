//
//  CommentTextView.swift
//  TimeControl
//

import SwiftUI

struct CommentTextView: View {
    let text: String

    var body: some View {
        let segments = LinkParser.parse(text)
        segments.reduce(Text("")) { result, segment in
            switch segment {
            case .text(let s):
                return result + Text(s)
            case .link(let url):
                return result + Text(.init("[\(url.absoluteString)](\(url.absoluteString))"))
            }
        }
    }
}
