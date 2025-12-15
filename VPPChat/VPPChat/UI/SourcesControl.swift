//
//  SourcesControl.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/15/25.
//

import SwiftUI

/// Drop this into the composer meta row.
/// - Single chip: "Sources" (shows mode + count)
/// - Tap opens SourcesModal as a sheet (matches AssumptionsModal behavior)
struct SourcesControl: View {
    @Binding var sources: VppSources
    @Binding var sourcesTable: [VppSourceRef]

    @State private var showSourcesModal: Bool = false

    var body: some View {
        Button {
            showSourcesModal = true
        } label: {
            chipLabel
        }
        .buttonStyle(ScalePressButtonStyle())
        .help("Attach per-message sources (web + explicit refs)")
        .sheet(isPresented: $showSourcesModal) {
            SourcesModal(sources: $sources, sourcesTable: $sourcesTable)
        }
    }

    private var chipLabel: some View {
        let isSelected = (sources != .none) || !sourcesTable.isEmpty
        let count = sourcesTable.count

        return HStack(spacing: 6) {
            Text(chipTitle(isSelected: isSelected, count: count))
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .foregroundStyle(isSelected ? StudioTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
    }

    private func chipTitle(isSelected: Bool, count: Int) -> String {
        var base = "Sources"
        if sources == .web { base += " · Web" }
        if count > 0 { base += " \(count)" }
        return base
    }
}

// MARK: - Button style (keep local if not global)

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
