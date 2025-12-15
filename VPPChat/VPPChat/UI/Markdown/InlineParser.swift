//
//  InlineParser.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

// MARK: - Inline parsing (supports multi-backtick code spans + basic emphasis/strong)

extension MarkdownParser {

    func parseInlines(_ input: String) -> [MarkdownInline] {
        // Preserve explicit newlines as soft breaks
        // (Paragraphs pass in multi-line strings)
        let parts = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var all: [MarkdownInline] = []
        for (idx, line) in parts.enumerated() {
            all.append(contentsOf: parseInlineLine(line))
            if idx != parts.count - 1 {
                all.append(.softBreak)
            }
        }
        return all
    }

    private func parseInlineLine(_ line: String) -> [MarkdownInline] {
        // Pass 1: code spans (CommonMark-ish)
        let segments = splitByCodeSpans(line)

        // Pass 2: emphasis/strong on non-code text segments
        var out: [MarkdownInline] = []
        for seg in segments {
            switch seg {
            case .code(let s):
                out.append(.code(s))
            case .text(let s):
                out.append(contentsOf: parseEmphasis(s))
            }
        }
        return coalesceText(out)
    }

    private enum InlineSegment {
        case text(String)
        case code(String)
    }

    private func splitByCodeSpans(_ s: String) -> [InlineSegment] {
        var result: [InlineSegment] = []
        var i = s.startIndex
        var buffer = ""

        func flushText() {
            if !buffer.isEmpty {
                result.append(.text(buffer))
                buffer = ""
            }
        }

        while i < s.endIndex {
            let ch = s[i]
            if ch == "`" {
                // opening run
                let runLen = runLength(in: s, from: i, char: "`")
                let openStart = i
                let openEnd = s.index(i, offsetBy: runLen)

                // search for closing run of same length
                var j = openEnd
                var foundClose: Range<String.Index>? = nil
                while j < s.endIndex {
                    if s[j] == "`" {
                        let closeLen = runLength(in: s, from: j, char: "`")
                        if closeLen == runLen {
                            let closeStart = j
                            let closeEnd = s.index(j, offsetBy: runLen)
                            foundClose = closeStart..<closeEnd
                            break
                        }
                        j = s.index(j, offsetBy: max(1, closeLen))
                        continue
                    }
                    j = s.index(after: j)
                }

                if let close = foundClose {
                    flushText()

                    let contentRange = openEnd..<close.lowerBound
                    var content = String(s[contentRange])

                    // CommonMark-ish normalization
                    content = content.replacingOccurrences(of: "\n", with: " ")
                    if content.count >= 2,
                       content.first == " ",
                       content.last == " " {
                        content.removeFirst()
                        content.removeLast()
                    }

                    result.append(.code(content))
                    i = close.upperBound
                    continue
                } else {
                    // No close: treat the backticks literally
                    buffer.append(contentsOf: String(s[openStart..<openEnd]))
                    i = openEnd
                    continue
                }
            } else {
                buffer.append(ch)
                i = s.index(after: i)
            }
        }

        flushText()
        return result
    }

    private func runLength(in s: String, from idx: String.Index, char: Character) -> Int {
        var n = 0
        var j = idx
        while j < s.endIndex, s[j] == char {
            n += 1
            j = s.index(after: j)
        }
        return n
    }

    private func parseEmphasis(_ s: String) -> [MarkdownInline] {
        // Minimal parser:
        // - **strong**
        // - *em*
        // - __strong__
        // - _em_
        // This is intentionally conservative and won’t try to match all CommonMark edge cases.
        var out: [MarkdownInline] = []

        var i = s.startIndex
        var buffer = ""

        func flushText() {
            if !buffer.isEmpty {
                out.append(.text(buffer))
                buffer = ""
            }
        }

        while i < s.endIndex {
            let ch = s[i]

            // Strong: ** or __
            if ch == "*" || ch == "_" {
                let isUnderscore = (ch == "_")
                let runLen = runLength(in: s, from: i, char: ch)

                if runLen >= 2 {
                    let delim = String(repeating: String(ch), count: 2)
                    let open = i
                    let openEnd = s.index(i, offsetBy: 2)
                    if let closeRange = findClosingDelimiter(in: s, from: openEnd, delim: delim) {
                        flushText()
                        let inner = String(s[openEnd..<closeRange.lowerBound])
                        out.append(.strong(parseEmphasis(inner)))
                        i = closeRange.upperBound
                        continue
                    } else {
                        buffer.append(contentsOf: delim)
                        i = openEnd
                        continue
                    }
                }

                // Emphasis: * or _
                if runLen == 1 {
                    let delim = String(ch)
                    let openEnd = s.index(after: i)
                    if let closeRange = findClosingDelimiter(in: s, from: openEnd, delim: delim) {
                        flushText()
                        let inner = String(s[openEnd..<closeRange.lowerBound])
                        out.append(.emphasis(parseEmphasis(inner)))
                        i = closeRange.upperBound
                        continue
                    } else {
                        buffer.append(ch)
                        i = openEnd
                        continue
                    }
                }

                // fallback
                buffer.append(ch)
                i = s.index(after: i)
                _ = isUnderscore // silence (kept for future rules)
                continue
            }

            buffer.append(ch)
            i = s.index(after: i)
        }

        flushText()
        return out
    }

    private func findClosingDelimiter(in s: String, from start: String.Index, delim: String) -> Range<String.Index>? {
        guard !delim.isEmpty else { return nil }
        var i = start
        while i < s.endIndex {
            if s[i...].hasPrefix(delim) {
                let end = s.index(i, offsetBy: delim.count)
                return i..<end
            }
            i = s.index(after: i)
        }
        return nil
    }

    private func coalesceText(_ nodes: [MarkdownInline]) -> [MarkdownInline] {
        var out: [MarkdownInline] = []
        var buffer: String = ""

        func flush() {
            if !buffer.isEmpty {
                out.append(.text(buffer))
                buffer = ""
            }
        }

        for n in nodes {
            switch n {
            case .text(let s):
                buffer += s
            default:
                flush()
                out.append(n)
            }
        }
        flush()
        return out
    }
}
