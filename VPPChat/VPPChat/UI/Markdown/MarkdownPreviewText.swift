//
//  MarkdownPreviewText.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct MarkdownPreviewText: View {
    let text: String
    var maxLines: Int = 3
    var theme: MarkdownTheme = .app

    var body: some View {
        Text(previewAttributedString())
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(maxLines)
            .truncationMode(.tail)
    }

    private func previewAttributedString() -> AttributedString {
        let doc = MarkdownCache.shared.document(for: text)
        let inlines = pickPreviewInlines(from: doc)
        return MarkdownAttributedStringBuilder.build(
            inlines: inlines,
            style: .bodySmall,
            theme: theme
        )
    }

    private func pickPreviewInlines(from doc: MarkdownDocument) -> [MarkdownInline] {
        for b in doc.blocks {
            switch b.kind {
            case .paragraph(let inlines):
                return inlines

            case .heading(_, let inlines):
                return inlines

            case .list(_, let items):
                if let first = items.first { return first }
                continue

            case .codeBlock(_, let code, _):
                let firstLine = code.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
                return [.code(firstLine)]

            case .plainText(let s):
                return [.text(s)]
            }
        }
        return [.text(text)]
    }
}
