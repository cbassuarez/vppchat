//
//  MarkdownParser.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

// MARK: - Parser (CommonMark-inspired, intentionally strict + small)

struct MarkdownParser {

    func parse(_ input: String) -> MarkdownDocument {
        // Preserve empty trailing line if present
        let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0
        var blocks: [MarkdownBlock] = []

        func isBlank(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        while i < lines.count {
            let line = lines[i]

            // Skip blank lines (paragraph separators)
            if isBlank(line) {
                i += 1
                continue
            }

            // 1) Fenced code blocks
            if let open = parseFenceOpen(line) {
                let startIndex = i
                var codeLines: [String] = []
                i += 1

                var closed = false
                while i < lines.count {
                    if isFenceClose(lines[i], fenceChar: open.fenceChar, minCount: open.count) {
                        closed = true
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }

                if closed {
                    let code = codeLines.joined(separator: "\n")
                    blocks.append(
                        MarkdownBlock(kind: .codeBlock(info: open.infoToken, code: code, isFenced: true))
                    )
                    i += 1 // consume closing fence
                    continue
                } else {
                    // Strict + graceful: once a fence opens and never closes,
                    // we DO NOT keep styling the rest of the message.
                    let remaining = lines[startIndex...].joined(separator: "\n")
                    blocks.append(MarkdownBlock(kind: .plainText(remaining)))
                    break
                }
            }

            // 2) Indented code blocks (CommonMark: 4 spaces or tab)
            if isIndentedCodeStart(line) {
                var codeLines: [String] = []
                while i < lines.count {
                    let l = lines[i]
                    if isBlank(l) {
                        // blank lines are allowed inside indented code blocks
                        codeLines.append("")
                        i += 1
                        continue
                    }
                    if isIndentedCodeStart(l) {
                        codeLines.append(stripIndent(l))
                        i += 1
                        continue
                    }
                    break
                }
                let code = codeLines.joined(separator: "\n")
                blocks.append(MarkdownBlock(kind: .codeBlock(info: nil, code: code, isFenced: false)))
                continue
            }

            // 3) Headings (#..######)
            if let h = parseHeading(line) {
                blocks.append(
                    MarkdownBlock(kind: .heading(level: h.level, inlines: parseInlines(h.text)))
                )
                i += 1
                continue
            }

            // 4) Lists (simple, single-level)
            if let firstItem = parseListItem(line) {
                var items: [String] = [firstItem.text]
                let ordered = firstItem.ordered
                i += 1

                while i < lines.count {
                    if isBlank(lines[i]) { break }
                    if let li = parseListItem(lines[i]), li.ordered == ordered {
                        items.append(li.text)
                        i += 1
                        continue
                    }
                    break
                }

                let inlineItems = items.map { parseInlines($0) }
                blocks.append(MarkdownBlock(kind: .list(ordered: ordered, items: inlineItems)))
                continue
            }

            // 5) Paragraph: consume until blank line or next block-start
            var paraLines: [String] = [line]
            i += 1

            while i < lines.count {
                let next = lines[i]
                if isBlank(next) { break }

                if parseFenceOpen(next) != nil { break }
                if isIndentedCodeStart(next) { break }
                if parseHeading(next) != nil { break }
                if parseListItem(next) != nil { break }

                paraLines.append(next)
                i += 1
            }

            let paraText = paraLines.joined(separator: "\n")
            blocks.append(MarkdownBlock(kind: .paragraph(parseInlines(paraText))))
        }

        return MarkdownDocument(blocks: blocks)
    }
}

// MARK: - Block helpers

private extension MarkdownParser {

    struct FenceOpen {
        let fenceChar: Character
        let count: Int
        let infoToken: String?
    }

    func parseFenceOpen(_ line: String) -> FenceOpen? {
        // CommonMark: up to 3 leading spaces allowed
        let (indent, rest) = splitLeadingSpaces(line)
        if indent > 3 { return nil }
        guard let first = rest.first, (first == "`" || first == "~") else { return nil }

        let runCount = countRun(rest, char: first)
        guard runCount >= 3 else { return nil }

        let after = rest.dropFirst(runCount)
        let info = after.trimmingCharacters(in: .whitespacesAndNewlines)

        // CommonMark: if using backtick fence, info string may not contain backticks
        if first == "`", info.contains("`") {
            return nil
        }

        let token = info.isEmpty ? nil : info.split(whereSeparator: \.isWhitespace).first.map(String.init)

        return FenceOpen(fenceChar: first, count: runCount, infoToken: token)
    }

    func isFenceClose(_ line: String, fenceChar: Character, minCount: Int) -> Bool {
        let (indent, rest) = splitLeadingSpaces(line)
        if indent > 3 { return false }
        guard rest.first == fenceChar else { return false }

        let runCount = countRun(rest, char: fenceChar)
        guard runCount >= minCount else { return false }

        let after = rest.dropFirst(runCount)
        // Closing fence line may have only whitespace after
        return after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let (indent, rest) = splitLeadingSpaces(line)
        if indent > 3 { return nil }
        guard rest.first == "#" else { return nil }

        let count = countRun(rest, char: "#")
        guard (1...6).contains(count) else { return nil }

        let after = rest.dropFirst(count)
        // CommonMark: require space or end
        if let first = after.first, first != " " && first != "\t" {
            return nil
        }

        let text = after.trimmingCharacters(in: .whitespacesAndNewlines)
        return (count, text)
    }

    struct ListItem {
        let ordered: Bool
        let text: String
    }

    func parseListItem(_ line: String) -> ListItem? {
        let (indent, rest) = splitLeadingSpaces(line)
        if indent > 3 { return nil }

        // Unordered: -, *, +
        if let c = rest.first, (c == "-" || c == "*" || c == "+") {
            let after = rest.dropFirst()
            guard after.first == " " || after.first == "\t" else { return nil }
            return ListItem(ordered: false, text: after.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Ordered: 1. or 1)
        var digits = ""
        var idx = rest.startIndex
        while idx < rest.endIndex, rest[idx].isNumber, digits.count < 9 {
            digits.append(rest[idx])
            idx = rest.index(after: idx)
        }
        if digits.isEmpty { return nil }
        if idx >= rest.endIndex { return nil }

        let punct = rest[idx]
        guard punct == "." || punct == ")" else { return nil }

        let next = rest.index(after: idx)
        if next >= rest.endIndex { return nil }
        let space = rest[next]
        guard space == " " || space == "\t" else { return nil }

        let after = rest[rest.index(after: next)...]
        return ListItem(ordered: true, text: after.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func isIndentedCodeStart(_ line: String) -> Bool {
        if line.hasPrefix("\t") { return true }
        return line.hasPrefix("    ")
    }

    func stripIndent(_ line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        if line.hasPrefix("    ") {
            return String(line.dropFirst(4))
        }
        return line
    }

    func splitLeadingSpaces(_ s: String) -> (Int, Substring) {
        var count = 0
        var idx = s.startIndex
        while idx < s.endIndex, s[idx] == " " {
            count += 1
            idx = s.index(after: idx)
        }
        return (count, s[idx...])
    }

    func countRun(_ s: Substring, char: Character) -> Int {
        var n = 0
        for c in s {
            if c == char { n += 1 } else { break }
        }
        return n
    }
}
