//
//  MarkdownViews.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

// MARK: - Public entry point

struct MarkdownMessageBody: View {
     let text: String
     let role: ConsoleMessageRole
    var theme: MarkdownTheme = .app

    init(text: String, role: ConsoleMessageRole = .user, theme: MarkdownTheme = .app) {
            self.text = text
            self.role = role
            self.theme = theme
        }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleBlocks: Int = 0

    private var document: MarkdownDocument {
        MarkdownCache.shared.document(for: text)
    }

    private var shouldAnimate: Bool {
        role == .assistant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(document.blocks.enumerated()), id: \.1.id) { idx, block in
                MarkdownBlockView(block: block, theme: theme)
                    .opacity(reduceMotion || !shouldAnimate ? 1 : (idx < visibleBlocks ? 1 : 0))
                    .animation(
                        reduceMotion || !shouldAnimate
                        ? .none
                        : .easeOut(duration: 0.22).delay(Double(idx) * 0.06),
                        value: visibleBlocks
                    )
            }
        }
        .textSelection(.enabled)
        .onAppear {
            if reduceMotion || !shouldAnimate {
                visibleBlocks = document.blocks.count
            } else {
                visibleBlocks = 0
                DispatchQueue.main.async {
                    visibleBlocks = document.blocks.count
                }
            }
        }
    }
}

// MARK: - Block rendering

private struct MarkdownBlockView: View {
     let block: MarkdownBlock
     let theme: MarkdownTheme

    var body: some View {
        switch block.kind {
        case .plainText(let s):
            Text(s)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let inlines):
            MarkdownTextView(inlines: inlines, style: .body, theme: theme)

        case .heading(let level, let inlines):
            MarkdownTextView(inlines: inlines, style: .heading(level), theme: theme)

        case .list(let ordered, let items):
            MarkdownListView(ordered: ordered, items: items, theme: theme)

        case .codeBlock(let info, let code, _):
            CodeBlockView(code: code, language: info, theme: theme)
        }
    }
}

// MARK: - Text rendering (AttributedString)

enum MarkdownTextStyle {
     case body
     case bodySmall
     case heading(Int)

    var fontSize: CGFloat {
        switch self {
        case .body: return 14
        case .bodySmall: return 12
        case .heading(let level):
            switch level {
            case 1: return 22
            case 2: return 18
            case 3: return 16
            default: return 15
            }
        }
    }

    var weight: Font.Weight {
        switch self {
        case .bodySmall: return .regular
        case .body: return .regular
        case .heading: return .semibold
        }
    }
}

struct MarkdownTextView: View {
    let inlines: [MarkdownInline]
    let style: MarkdownTextStyle
    let theme: MarkdownTheme
    var body: some View {
        Text(MarkdownAttributedStringBuilder.build(inlines: inlines, style: style, theme: theme))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkdownAttributedStringBuilder {

    struct Traits {
        var strong: Bool = false
        var emphasis: Bool = false
        var code: Bool = false
    }

    static func build(inlines: [MarkdownInline], style: MarkdownTextStyle, theme: MarkdownTheme) -> AttributedString {
        var out = AttributedString()
        var t = Traits()
        append(inlines: inlines, into: &out, style: style, traits: t, theme: theme)
        return out
    }

    private static func append(inlines: [MarkdownInline],
                               into out: inout AttributedString,
                               style: MarkdownTextStyle,
                               traits: Traits,
                               theme: MarkdownTheme) {
        for node in inlines {
            append(node: node, into: &out, style: style, traits: traits, theme: theme)
        }
    }

    private static func append(node: MarkdownInline,
                               into out: inout AttributedString,
                               style: MarkdownTextStyle,
                               traits: Traits,
                               theme: MarkdownTheme) {
        switch node {
        case .text(let s):
            out.append(styled(s, style: style, traits: traits, theme: theme))

        case .softBreak:
            out.append(styled("\n", style: style, traits: traits, theme: theme))

        case .code(let code):
            var codeTraits = traits
            codeTraits.code = true

            // Cheap “pill” feel: non-breaking spaces around + background
            out.append(styled("\u{00A0}\(code)\u{00A0}", style: style, traits: codeTraits, theme: theme, isInlineCode: true))

        case .strong(let children):
            var next = traits
            next.strong = true
            append(inlines: children, into: &out, style: style, traits: next, theme: theme)

        case .emphasis(let children):
            var next = traits
            next.emphasis = true
            append(inlines: children, into: &out, style: style, traits: next, theme: theme)
        }
    }

    private static func styled(_ s: String,
                               style: MarkdownTextStyle,
                               traits: Traits,
                               theme: MarkdownTheme,
                               isInlineCode: Bool = false) -> AttributedString {
        var a = AttributedString(s)

        let font: Font = {
            let design: Font.Design = traits.code ? .monospaced : .default
            var f = Font.system(size: style.fontSize, weight: traits.strong ? .semibold : style.weight, design: design)
            if traits.emphasis { f = f.italic() }
            return f
        }()

        var container = AttributeContainer()
        container.font = font
        container.foregroundColor = theme.textPrimary

        if isInlineCode {
            container.backgroundColor = theme.surfaceInlineCode
        }

        a.mergeAttributes(container)
        return a
    }
}
enum VppCopySanitizer {
    static func stripHeaderFooter(from raw: String) -> String {
        var lines = raw.components(separatedBy: .newlines)

        if let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
           first.hasPrefix("<"), first.hasSuffix(">") {
            lines.removeFirst()
        }

        if let last = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           last.hasPrefix("[Version=") {
            lines.removeLast()
        }

        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MarkdownCopyText {
    static func renderedText(from rawMessage: String) -> String {
        let cleaned = VppCopySanitizer.stripHeaderFooter(from: rawMessage)
        let doc = MarkdownCache.shared.document(for: cleaned)
        return MarkdownPlainTextBuilder.build(document: doc)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MarkdownPlainTextBuilder {
    static func build(document: MarkdownDocument) -> String {
        var parts: [String] = []

        for block in document.blocks {
            switch block.kind {
            case .plainText(let s):
                parts.append(s)

            case .paragraph(let inlines):
                parts.append(inlineText(inlines))

            case .heading(_, let inlines):
                parts.append(inlineText(inlines))

            case .list(let ordered, let items):
                var lines: [String] = []
                for (i, item) in items.enumerated() {
                    let prefix = ordered ? "\(i + 1). " : "• "
                    lines.append(prefix + inlineText(item))
                }
                parts.append(lines.joined(separator: "\n"))

            case .codeBlock(_, let code, _):
                parts.append(code)
            }
        }

        // match typical markdown “block spacing”
        return parts.joined(separator: "\n\n")
    }

    private static func inlineText(_ inlines: [MarkdownInline]) -> String {
        var out = ""
        for node in inlines {
            switch node {
            case .text(let s):
                out += s
            case .softBreak:
                out += "\n"
            case .code(let s):
                out += s
            case .strong(let children):
                out += inlineText(children)
            case .emphasis(let children):
                out += inlineText(children)
            }
        }
        return out
    }
}
