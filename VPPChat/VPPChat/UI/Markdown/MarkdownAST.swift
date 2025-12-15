//
//  MarkdownAST.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import Foundation

// MARK: - AST

struct MarkdownDocument: Equatable {
    var blocks: [MarkdownBlock]
}

struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case paragraph([MarkdownInline])
        case heading(level: Int, inlines: [MarkdownInline])
        case list(ordered: Bool, items: [[MarkdownInline]])
        case codeBlock(info: String?, code: String, isFenced: Bool)
        case plainText(String) // strict fallback (e.g. unclosed fence)
    }

    let id = UUID()
    var kind: Kind
}

indirect enum MarkdownInline: Equatable {
    case text(String)
    case softBreak
    case code(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
}
