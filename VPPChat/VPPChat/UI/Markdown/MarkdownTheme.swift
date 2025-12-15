//
//  MarkdownTheme.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct MarkdownTheme {
    var textPrimary: Color
    var textSecondary: Color
    var textSubtle: Color

    var surfaceInlineCode: Color
    var surfaceCodeBlock: Color
    var borderSoft: Color

    static let app = MarkdownTheme(
        textPrimary: AppTheme.Colors.textPrimary,
        textSecondary: AppTheme.Colors.textSecondary,
        textSubtle: AppTheme.Colors.textSubtle,
        surfaceInlineCode: AppTheme.Colors.surface1,
        surfaceCodeBlock: AppTheme.Colors.surface1,
        borderSoft: AppTheme.Colors.borderSoft
    )

    static let studio = MarkdownTheme(
        textPrimary: StudioTheme.Colors.textPrimary,
        textSecondary: StudioTheme.Colors.textSecondary,
        textSubtle: StudioTheme.Colors.textSubtle,
        surfaceInlineCode: StudioTheme.Colors.panel,
        surfaceCodeBlock: AppTheme.Colors.surface1,
        borderSoft: StudioTheme.Colors.borderSoft
    )
}
