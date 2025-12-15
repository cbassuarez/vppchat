//
//  MarkdownListView.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI

struct MarkdownListView: View {
    let ordered: Bool
    let items: [[MarkdownInline]]
    var theme: MarkdownTheme = .app
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, inlines in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(marker(for: idx))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(width: ordered ? 24 : 16, alignment: .trailing)

                    // Reuse your existing inline renderer
                    MarkdownTextView(inlines: inlines, style: .body, theme: theme)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func marker(for idx: Int) -> String {
        ordered ? "\(idx + 1)." : "•"
    }
}
