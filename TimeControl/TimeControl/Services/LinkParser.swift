//
//  LinkParser.swift
//  TimeControl
//

import Foundation

enum LinkSegment: Equatable {
    case text(String)
    case link(URL)
}

enum LinkParser {
    static func parse(_ input: String) -> [LinkSegment] {
        guard !input.isEmpty else { return [] }

        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let nsInput = input as NSString
        let matches = detector.matches(in: input, range: NSRange(location: 0, length: nsInput.length))

        guard !matches.isEmpty else {
            return [.text(input)]
        }

        var segments: [LinkSegment] = []
        var cursor = input.startIndex

        for match in matches {
            guard let url = match.url,
                  let matchRange = Range(match.range, in: input) else { continue }

            if cursor < matchRange.lowerBound {
                segments.append(.text(String(input[cursor..<matchRange.lowerBound])))
            }
            segments.append(.link(url))
            cursor = matchRange.upperBound
        }

        if cursor < input.endIndex {
            segments.append(.text(String(input[cursor...])))
        }

        return segments
    }
}
