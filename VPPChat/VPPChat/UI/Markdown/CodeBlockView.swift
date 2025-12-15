//
//  CodeBlockView.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//


import SwiftUI
// Platform pasteboard
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct CodeBlockView: View {
    let code: String
    let language: String?
    var theme: MarkdownTheme = .app

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: true, vertical: false) // don’t wrap; scroll instead
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .background(theme.surfaceCodeBlock)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.borderSoft, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let language, !language.isEmpty {
                Text(language.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.Colors.borderSoft, lineWidth: 1))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                copyToPasteboard(code)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { didCopy = false }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(didCopy ? "Copied" : "Copy")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.surface0)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.borderSoft, lineWidth: 1))
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func copyToPasteboard(_ s: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = s
        #endif
    }
}
