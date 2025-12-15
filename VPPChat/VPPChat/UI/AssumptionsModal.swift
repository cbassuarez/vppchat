//
//  AssumptionsModal.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//

import SwiftUI

struct AssumptionsModal: View {
@Binding var assumptions: AssumptionsConfig
    @Environment(\.dismiss) private var dismiss
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

// 1–8 only (0 is handled by the composer chips, not here)
@State private var count: Int = 1
@State private var items: [String] = Array(repeating: "", count: 8)

private var popAnimation: Animation {
    reduceMotion
    ? .easeOut(duration: 0.01)
    : .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.12)
}

private var fieldTransition: AnyTransition {
    let base = AnyTransition.opacity.combined(with: .scale(scale: 0.985, anchor: .topLeading))
    if reduceMotion { return base }
    return base.combined(with: .move(edge: .top))
}

var body: some View {
    VStack(spacing: 0) {
        header

        Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose how many assumptions the assistant should make for this send, and enumerate them explicitly. These will be passed at send-time (not stored in the transcript).")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                countPicker

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<count, id: \.self) { idx in
                        assumptionField(index: idx)
                            .transition(fieldTransition)
                    }
                }
                .animation(popAnimation, value: count)

                footerHint
            }
            .padding(16)
        }

        Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))

        buttons
    }
    .frame(minWidth: 560, minHeight: 440)
    .background(AppTheme.Colors.surface0)
    .onAppear { seedFromBinding() }
}

// MARK: - Header

private var header: some View {
    HStack(spacing: 10) {
        Image(systemName: "list.bullet.rectangle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(StudioTheme.Colors.accent)

        VStack(alignment: .leading, spacing: 2) {
            Text("Assumptions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Applied to this send only.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }

        Spacer()
    }
    .padding(16)
}

// MARK: - Count chips (1–8)

private var countPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("Count")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Spacer()
        }

        HStack(spacing: 6) {
            ForEach(1...8, id: \.self) { value in
                countChip(value)
            }
            Spacer(minLength: 0)
        }
    }
}

private func countChip(_ value: Int) -> some View {
    let isSelected = (value == count)

    return Button {
        withAnimation(popAnimation) {
            count = value
        }
    } label: {
        Text("\(value)")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? StudioTheme.Colors.accentSoft : AppTheme.Colors.surface1)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? StudioTheme.Colors.accent : AppTheme.Colors.borderSoft,
                            lineWidth: isSelected ? 1.4 : 1)
            )
            .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
    }
    .buttonStyle(.plain)
}

// MARK: - Fields

private func assumptionField(index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text("Assumption \(index + 1)")
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.Colors.textSubtle)

        TextField(
            "e.g. The user is asking about the same file as last message.",
            text: bindingForIndex(index)
        )
        .textFieldStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .animation(popAnimation, value: count) // keeps entry feel consistent when fields appear/disappear
    }
}

private var footerHint: some View {
    HStack(spacing: 8) {
        Image(systemName: "sparkles")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.Colors.textSubtle)

        Text("These become a temporary system attachment at send-time, plus `--assumptions=N` in the user header.")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.Colors.textSecondary)
    }
    .padding(.top, 2)
}

// MARK: - Buttons

private var buttons: some View {
    HStack(spacing: 10) {
        Button("Clear") {
            withAnimation(popAnimation) {
                assumptions = .none
            }
            dismiss()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .foregroundStyle(AppTheme.Colors.textSecondary)

        Spacer()

        Button("Cancel") {
            dismiss()
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.Colors.textSecondary)

        Button {
            let list = items.prefix(count).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            assumptions = .custom(items: Array(list))
            dismiss()
        } label: {
            Text("Done")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(StudioTheme.Colors.accentSoft)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .stroke(StudioTheme.Colors.accent, lineWidth: 1)
        )
    }
    .padding(16)
    .background(AppTheme.Colors.surface0)
}

// MARK: - State plumbing

private func seedFromBinding() {
    switch assumptions {
    case .none, .zero:
        count = 1
        items = Array(repeating: "", count: 8)

    case .custom(let list):
        count = max(1, min(8, list.count))
        items = Array(repeating: "", count: 8)
        for i in 0..<min(8, list.count) {
            items[i] = list[i]
        }
    }
}

private func bindingForIndex(_ idx: Int) -> Binding<String> {
    Binding(
        get: { items[idx] },
        set: { newValue in items[idx] = newValue }
    )
}

}
