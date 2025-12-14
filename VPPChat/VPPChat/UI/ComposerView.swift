import SwiftUI

struct ComposerView: View {
    @Binding var draft: String
    @Binding var modifiers: VppModifiers
    @Binding var sources: VppSources

    @ObservedObject var runtime: VppRuntime
    var sendAction: () -> Void
    var tagSelection: (VppTag) -> Void
    var stepCycle: () -> Void
    var resetCycle: () -> Void

    @State private var isQualityExpanded = false
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.base * 1.25) {
            metaBand
            tagBand
            editorBand
            actionBand
        }
        .padding(AppTheme.Spacing.outerHorizontal)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 6, x: 6, y: 6)
        )
        .animation(.spring(response: AppTheme.Motion.medium,
                           dampingFraction: 0.85,
                           blendDuration: 0.2),
                   value: isQualityExpanded)
    }

    // MARK: - Bands

    // Top: cycle, assumptions, locus, sources
    private var metaBand: some View {
        HStack(spacing: AppTheme.Spacing.base * 1.5) {
            // Cycle + assumptions cluster
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("CYCLE")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)

                    Text("\(runtime.state.cycleIndex) / 3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    HStack(spacing: 4) {
                        pillIconButton(systemName: "arrow.uturn.left") {
                            resetCycle()
                        }
                        pillIconButton(systemName: "chevron.right") {
                            stepCycle()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(Capsule())
                }

                // Assumptions as discrete chips (no +/- / Stepper)
                HStack(spacing: 6) {
                    Text("ASSUMPTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)

                    HStack(spacing: 4) {
                        ForEach([0, 1, 2, 3, 4, 5], id: \.self) { value in
                            assumptionsChip(value: value)
                        }
                    }
                }
            }

            Divider()
                .frame(height: 32)
                .overlay(AppTheme.Colors.borderSoft)

            // Locus + sources
            VStack(alignment: .leading, spacing: 6) {
                Text("LOCUS")
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)

                HStack(spacing: 6) {
                    TextField("current thread", text: Binding(
                        get: { runtime.state.locus ?? "" },
                        set: { runtime.setLocus($0.isEmpty ? nil : $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                    // Sources cluster - designed for future expansion
                    HStack(spacing: 4) {
                        sourceChip("None", isSelected: sources == .none) {
                            sources = .none
                        }
                        sourceChip("Web", isSelected: sources == .web) {
                            sources = .web
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // Tag row just above editor
    private var tagBand: some View {
        HStack {
            TagChipsView(selected: runtime.state.currentTag, onSelect: tagSelection)
            Spacer()
        }
    }

    // Middle: TextEditor card
    private var editorBand: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
            .fill(AppTheme.Colors.surface0)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
            )
            .overlay(
                TextEditor(text: $draft)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, AppTheme.Spacing.cardInner)
                    .padding(.vertical, AppTheme.Spacing.base * 1.2)
            )
            .frame(minHeight: 110, maxHeight: 200)
    }

    // Bottom: correctness/severity drawer + send button
    private var actionBand: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.base) {
            qualityDrawer
            Spacer(minLength: 0)
            sendButton
        }
    }

    // MARK: - Quality drawer

    private var qualityDrawer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isQualityExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                    Text("Quality")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                    Image(systemName: isQualityExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.surface0)
                .clipShape(Capsule())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .buttonStyle(.plain)

            if isQualityExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        correctnessChip(
                            title: "NEUTRAL",
                            color: .clear,
                            textColor: AppTheme.Colors.textSecondary,
                            selected: modifiers.correctness == .neutral
                        ) { modifiers.correctness = .neutral }

                        correctnessChip(
                            title: "CORRECT",
                            color: AppTheme.Colors.statusCorrect.opacity(0.16),
                            textColor: AppTheme.Colors.statusCorrect,
                            selected: modifiers.correctness == .correct
                        ) { modifiers.correctness = .correct }

                        correctnessChip(
                            title: "INCORRECT",
                            color: AppTheme.Colors.statusMajor.opacity(0.16),
                            textColor: AppTheme.Colors.statusMajor,
                            selected: modifiers.correctness == .incorrect
                        ) { modifiers.correctness = .incorrect }
                    }

                    HStack(spacing: 6) {
                        severityChip(
                            title: "NONE",
                            selected: modifiers.severity == .none
                        ) { modifiers.severity = .none }

                        severityChip(
                            title: "MINOR",
                            color: AppTheme.Colors.statusMinor,
                            selected: modifiers.severity == .minor
                        ) { modifiers.severity = .minor }

                        severityChip(
                            title: "MAJOR",
                            color: AppTheme.Colors.statusMajor,
                            selected: modifiers.severity == .major
                        ) { modifiers.severity = .major }
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        Button(action: sendAction) {
            Label("Send", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(theme.structuralAccent)
                )
                .foregroundStyle(Color.white)
                .shadow(color: AppTheme.Colors.structuralAccent.opacity(0.6),
                        radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        .keyboardShortcut(.return, modifiers: [.command])
        .scaleEffect(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.01)
    }

    // MARK: - Helpers

    private func pillIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 16, height: 16)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func assumptionsChip(value: Int) -> some View {
        let isSelected = runtime.state.assumptions == value
        return Button {
            runtime.setAssumptions(value)
        } label: {
            Text("\(value)")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.structuralAccent.opacity(0.22)
                                         : AppTheme.Colors.surface0)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? theme.structuralAccent
                                           : AppTheme.Colors.borderSoft,
                                lineWidth: isSelected ? 1.3 : 1)
                )
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func sourceChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.structuralAccent.opacity(0.22)
                                         : AppTheme.Colors.surface0)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? theme.structuralAccent
                                           : AppTheme.Colors.borderSoft,
                                lineWidth: isSelected ? 1.3 : 1)
                )
                .foregroundStyle(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func correctnessChip(
        title: String,
        color: Color,
        textColor: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selected ? color : AppTheme.Colors.surface0.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selected ? (color == .clear
                                        ? theme.structuralAccent
                                        : color)
                                     : AppTheme.Colors.borderSoft,
                            lineWidth: selected ? 1.4 : 1
                        )
                )
                .foregroundStyle(selected ? textColor : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func severityChip(
        title: String,
        color: Color? = nil,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            selected
                            ? (color ?? AppTheme.Colors.surface0).opacity(color != nil ? 0.18 : 0.9)
                            : AppTheme.Colors.surface0.opacity(0.7)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selected
                            ? (color ?? theme.structuralAccent)
                            : AppTheme.Colors.borderSoft,
                            lineWidth: selected ? 1.4 : 1
                        )
                )
                .foregroundStyle(
                    selected
                    ? (color ?? AppTheme.Colors.textPrimary)
                    : AppTheme.Colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }
}
