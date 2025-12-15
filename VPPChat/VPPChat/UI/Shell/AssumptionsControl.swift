//
//  AssumptionsControl.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

private enum AssumptionsPopover: Hashable {
    case editor
}

private struct AssumptionsAnchorKey: PreferenceKey {
    static var defaultValue: [AssumptionsPopover: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AssumptionsPopover: Anchor<CGRect>],
                       nextValue: () -> [AssumptionsPopover: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Drop this into the composer meta row.
/// - Two chips: `0` and `1+`
/// - No selection => `.none`
/// - `0` => `.zero`
/// - `1+` => opens editor; Done commits `.custom(items:)`
struct AssumptionsControl: View {
    @Binding var config: AssumptionsConfig

    @State private var activePopover: AssumptionsPopover? = nil
    @State private var draftCount: Int = 1
    @State private var draftItems: [String] = [""]

    private let maxCount = 8

    var body: some View {
        HStack(spacing: 6) {
            chipZero
            chipOnePlus
        }
        // 👇 Anchor + overlay popover (Atlas pattern; avoids SwiftUI `.popover` issues)
        .overlayPreferenceValue(AssumptionsAnchorKey.self) { anchors in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    if activePopover == .editor,
                       let anchor = anchors[.editor] {
                        let rect = proxy[anchor]
                        AssumptionsEditorPanel(
                            count: $draftCount,
                            items: $draftItems,
                            maxCount: maxCount,
                            onCancel: { closeEditor(commit: false) },
                            onDone: { closeEditor(commit: true) }
                        )
                        .fixedSize(horizontal: true, vertical: true)
                        .frame(maxWidth: 420, alignment: .leading)
                        .offset(x: rect.minX, y: rect.maxY + 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Chips

    private var chipZero: some View {
        let isSelected = (config == .zero)

        return Button {
            // toggle 0 on/off
            if isSelected {
                config = .none
            } else {
                config = .zero
            }
            activePopover = nil
        } label: {
            Text("0")
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
        .buttonStyle(ScalePressButtonStyle())
        .help("Pass --assumptions=0")
    }

    private var chipOnePlus: some View {
        let isSelected = {
            if case .custom = config { return true }
            return false
        }()

        return Button {
            // open editor (or close if already open)
            if activePopover == .editor {
                activePopover = nil
            } else {
                openEditorFromCurrentConfig()
                activePopover = .editor
            }
        } label: {
            HStack(spacing: 6) {
                Text(config.chipLabelOnePlus)
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
        .buttonStyle(ScalePressButtonStyle())
        .anchorPreference(key: AssumptionsAnchorKey.self, value: .bounds) { anchor in
            [.editor: anchor]
        }
        .help("Choose explicit assumptions to pass")
    }

    // MARK: - Editor lifecycle

    private func openEditorFromCurrentConfig() {
        let existing = config.customItems
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if existing.isEmpty {
            draftCount = 1
            draftItems = [""]
            return
        }

        let n = max(1, min(maxCount, existing.count))
        draftCount = n
        draftItems = Array(existing.prefix(n))
        if draftItems.count < n {
            draftItems.append(contentsOf: Array(repeating: "", count: n - draftItems.count))
        }
    }

    private func closeEditor(commit: Bool) {
        defer { activePopover = nil }

        guard commit else { return }

        let cleaned = draftItems
            .prefix(draftCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Require all fields non-empty to commit.
        let allFilled = cleaned.allSatisfy { !$0.isEmpty }
        guard allFilled else { return }

        config = .custom(items: Array(cleaned))
    }
}

// MARK: - Panel UI

private struct AssumptionsEditorPanel: View {
    @Binding var count: Int
    @Binding var items: [String]

    let maxCount: Int
    let onCancel: () -> Void
    let onDone: () -> Void

    @FocusState private var focusedIndex: Int?

    private var canDone: Bool {
        let trimmed = items.prefix(count).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return trimmed.count == count && trimmed.allSatisfy { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().overlay(AppTheme.Colors.borderSoft.opacity(0.7))
            countRow
            fields
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 6, y: 10)
        // Swallow drags so the window doesn’t “grab” while interacting inside the panel.
        .gesture(DragGesture(minimumDistance: 0), including: .all)
        .onAppear {
            normalizeItems(for: count)
            focusedIndex = 0
        }
        .onChange(of: count) { newValue in
            normalizeItems(for: newValue)
            focusedIndex = min(focusedIndex ?? 0, max(0, newValue - 1))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Assumptions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Spacer()

            Button("Cancel", action: onCancel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .buttonStyle(.plain)

            Button("Done", action: onDone)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(canDone ? StudioTheme.Colors.accent : AppTheme.Colors.textSubtle)
                .buttonStyle(.plain)
                .disabled(!canDone)
        }
    }

    private var countRow: some View {
        HStack {
            Text("Count")
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Colors.textSubtle)

            Spacer()

            Stepper(value: $count, in: 1...maxCount) {
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(minWidth: 22, alignment: .trailing)
            }
            .controlSize(.small)
        }
    }

    private var fields: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<count, id: \.self) { i in
                    assumptionField(index: i)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 260)
    }

    private func assumptionField(index: Int) -> some View {
        TextField("Assumption \(index + 1)", text: Binding(
            get: {
                if items.indices.contains(index) { return items[index] }
                return ""
            },
            set: { newValue in
                if items.indices.contains(index) {
                    items[index] = newValue
                }
            }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.Colors.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .focused($focusedIndex, equals: index)
    }

    private func normalizeItems(for n: Int) {
        let clamped = max(1, min(maxCount, n))
        if items.count < clamped {
            items.append(contentsOf: Array(repeating: "", count: clamped - items.count))
        } else if items.count > clamped {
            items = Array(items.prefix(clamped))
        }
        count = clamped
    }
}

// MARK: - Button style (if you don’t already have it in scope)

private struct ScalePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
