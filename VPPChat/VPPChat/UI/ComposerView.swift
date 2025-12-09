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

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.base) {
            // Row above text window: cycle, assumptions, locus, sources
            HStack(spacing: AppTheme.Spacing.base * 1.5) {
                HStack(spacing: 6) {
                    Text("CYCLE")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)
                    Text("\(runtime.state.cycleIndex) / 3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Button("Next") { stepCycle() }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.surface1.opacity(0.8))
                        .clipShape(Capsule())
                    Button("New") { resetCycle() }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.surface1.opacity(0.8))
                        .clipShape(Capsule())
                }

                Divider()
                    .frame(height: 20)
                    .overlay(AppTheme.Colors.borderSoft)

                Stepper("ASSUMPTIONS \(runtime.state.assumptions)", value: Binding(
                    get: { runtime.state.assumptions },
                    set: { runtime.setAssumptions($0) }
                ), in: 0...10)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)

                HStack(spacing: 6) {
                    Text("LOCUS")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)
                    TextField("locus", text: Binding(
                        get: { runtime.state.locus ?? "" },
                        set: { runtime.setLocus($0.isEmpty ? nil : $0) }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface1.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                Spacer()

                Picker("Sources", selection: $sources) {
                    Text("None").tag(VppSources.none)
                    Text("Web").tag(VppSources.web)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            // Main text window with embedded tag & correctness chips and send button
            GeometryReader { proxy in
                let maxHeight = proxy.size.height * 0.3

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .fill(AppTheme.Colors.surface1)
                        .background(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )

                    VStack(spacing: AppTheme.Spacing.base) {
                        TextEditor(text: $draft)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.top, AppTheme.Spacing.base)
                            .padding(.horizontal, AppTheme.Spacing.cardInner)
                            .frame(
                                minHeight: 80,
                                maxHeight: maxHeight
                            )

                        HStack(alignment: .center) {
                            // Bottom-left: tag chips + correctness
                            VStack(alignment: .leading, spacing: 6) {
                                TagChipsView(selected: runtime.state.currentTag, onSelect: tagSelection)

                                HStack(spacing: 6) {
                                    correctnessChip(title: "NEUTRAL", color: .clear, textColor: AppTheme.Colors.textSecondary, selected: modifiers.correctness == .neutral) {
                                        modifiers.correctness = .neutral
                                    }
                                    correctnessChip(title: "CORRECT", color: AppTheme.Colors.statusCorrect.opacity(0.16), textColor: AppTheme.Colors.statusCorrect, selected: modifiers.correctness == .correct) {
                                        modifiers.correctness = .correct
                                    }
                                    correctnessChip(title: "INCORRECT", color: AppTheme.Colors.statusMajor.opacity(0.16), textColor: AppTheme.Colors.statusMajor, selected: modifiers.correctness == .incorrect) {
                                        modifiers.correctness = .incorrect
                                    }
                                }

                                HStack(spacing: 6) {
                                    severityChip(title: "NONE", selected: modifiers.severity == .none) {
                                        modifiers.severity = .none
                                    }
                                    severityChip(title: "MINOR", color: AppTheme.Colors.statusMinor, selected: modifiers.severity == .minor) {
                                        modifiers.severity = .minor
                                    }
                                    severityChip(title: "MAJOR", color: AppTheme.Colors.statusMajor, selected: modifiers.severity == .major) {
                                        modifiers.severity = .major
                                    }
                                }
                            }

                            Spacer()

                            // Bottom-right: send button
                            Button(action: sendAction) {
                                Label("Send", systemImage: "paperplane.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(AppTheme.Colors.structuralAccent)
                                            .shadow(color: AppTheme.Colors.structuralAccent.opacity(0.6), radius: 16, x: 0, y: 10)
                                    )
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                            }
                            .buttonStyle(.plain)
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                            .keyboardShortcut(.return, modifiers: [.command])
                        }
                        .padding(.horizontal, AppTheme.Spacing.cardInner)
                        .padding(.bottom, AppTheme.Spacing.base)
                    }
                }
            }
            .frame(height: 180) // base composer height; TextEditor uses up to 30% of this
        }
        .padding(AppTheme.Spacing.outerHorizontal)
        .background(
            AppTheme.Colors.surface2.opacity(0.9)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
        )
    }

    private func correctnessChip(title: String, color: Color, textColor: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selected ? color : AppTheme.Colors.surface1.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? color.opacity(0.9) : AppTheme.Colors.borderSoft, lineWidth: selected ? 1.4 : 1)
                )
                .foregroundStyle(selected ? textColor : AppTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private func severityChip(title: String, color: Color? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selected ? (color ?? AppTheme.Colors.surface1).opacity(color != nil ? 0.18 : 0.9) : AppTheme.Colors.surface1.opacity(0.7))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selected
                            ? (color ?? AppTheme.Colors.structuralAccent).opacity(0.9)
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
