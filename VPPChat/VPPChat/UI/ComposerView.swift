import SwiftUI

struct ComposerView: View {
    @Binding var draft: String
    @Binding var modifiers: VppModifiers
    @Binding var sources: VppSources
    @Binding var sourcesTable: [VppSourceRef]
    @Binding var assumptions: AssumptionsConfig
    @State private var showAssumptionsModal = false
    @State private var showSourcesModal = false

    @ObservedObject var runtime: VppRuntime
    var requestStatus: RequestStatus
    var sendAction: () -> Void
    var tagSelection: (VppTag) -> Void
    var stepCycle: () -> Void
    var resetCycle: () -> Void
    var focusBinding: FocusState<Bool>.Binding? = nil
    @FocusState private var isEditorFocused: Bool
    @State private var isQualityExpanded = false
    @EnvironmentObject private var theme: ThemeManager

    // Tags that may be used as echo targets with !<e> --<tag>
    private let echoableTags: Set<VppTag> = [.g, .q, .o, .c]

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sendPhase: SendPhase {
        switch requestStatus {
        case .inFlight(let stage, _):
        return (stage == .sending) ? .sending : .receiving
        case .error:
            // Visually shows “Retry”, but actual retry is via the error card for now.
            return .error
        case .idle:
            return trimmedDraft.isEmpty ? .idleDisabled : .idleReady
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.base * 1.25) {
            metaBand
            tagBand
            editorBand
            actionBand
        }
        .onChange(of: sourcesTable) { _ in
                    sources = VppSources.summary(for: sourcesTable)
                }
        .padding(AppTheme.Spacing.outerHorizontal)
        .panelBackground()
        .animation(
            .spring(response: AppTheme.Motion.medium,
                    dampingFraction: 0.85,
                    blendDuration: 0.2),
            value: isQualityExpanded
        )
    }

    // MARK: - Bands
    private var assumptionsZeroChip: some View {
        let isSelected = (assumptions == .zero)

        return Button {
            // tap again to clear (→ none)
            assumptions = isSelected ? .none : .zero
        } label: {
            Text("0")
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

    private var assumptionsMoreChip: some View {
        let isSelected = assumptions.isCustom

        return Button {
            showAssumptionsModal = true
        } label: {
            HStack(spacing: 6) {
                Text("1+")
                    .font(.system(size: 11, weight: .medium))

                if case .custom(let items) = assumptions {
                    Text("\(items.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.surface1)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                        )
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

            }
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
    init(
            draft: Binding<String>,
            modifiers: Binding<VppModifiers>,
            sources: Binding<VppSources>,
            sourcesTable: Binding<[VppSourceRef]>,
            assumptions: Binding<AssumptionsConfig>,
            runtime: VppRuntime,
            requestStatus: RequestStatus,
            sendAction: @escaping () -> Void,
            tagSelection: @escaping (VppTag) -> Void,
            stepCycle: @escaping () -> Void,
            resetCycle: @escaping () -> Void,
            focusBinding: FocusState<Bool>.Binding? = nil
        ) {
            self._draft = draft
            self._modifiers = modifiers
            self._sources = sources
            self._sourcesTable = sourcesTable
            self._assumptions = assumptions
            self.runtime = runtime
            self.requestStatus = requestStatus
            self.sendAction = sendAction
            self.tagSelection = tagSelection
            self.stepCycle = stepCycle
            self.resetCycle = resetCycle
            self.focusBinding = focusBinding
        }
    // Top: cycle (read-only), assumptions, locus, sources
    private var metaBand: some View {
        HStack(spacing: AppTheme.Spacing.base * 1.5) {
            // Cycle + assumptions cluster
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("CYCLE")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)

                    HStack(spacing: 6) {
                        Text("\(runtime.state.cycleIndex) / 3")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(Capsule())
                }

                // Assumptions as discrete chips
                HStack(spacing: 6) {
                    Text("ASSUMPTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Colors.textSubtle)

                    assumptionsZeroChip
                    assumptionsMoreChip
                }
                .sheet(isPresented: $showAssumptionsModal) {
                    AssumptionsModal(assumptions: $assumptions)
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
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.Colors.textSubtle)

                        Text(runtime.state.locus ?? "Auto from assistant")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                (runtime.state.locus ?? "").isEmpty
                                ? AppTheme.Colors.textSubtle
                                : AppTheme.Colors.textSecondary
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Sources cluster
                    HStack(spacing: 4) {
                        sourceChip("None", isSelected: sources == .none) {
                            sources = .none
                        }
                        sourceChip("Web", isSelected: sources == .web) {
                            sources = .web
                        }
                    }
                    Button {
                                            showSourcesModal = true
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(sourcesTable.isEmpty ? "Sources" : "Sources \(sourcesTable.count)")
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 10, weight: .semibold))
                                            }
                                            .font(.system(size: 11, weight: .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill((sources == .web || !sourcesTable.isEmpty)
                                                          ? theme.structuralAccent.opacity(0.22)
                                                          : AppTheme.Colors.surface0)
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke((sources == .web || !sourcesTable.isEmpty)
                                                            ? theme.structuralAccent
                                                            : AppTheme.Colors.borderSoft,
                                                            lineWidth: (sources == .web || !sourcesTable.isEmpty) ? 1.3 : 1)
                                            )
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .sheet(isPresented: $showSourcesModal) {
                                            SourcesModal(sources: $sources, sourcesTable: $sourcesTable)
                                        }
                
                }
            }

            Spacer(minLength: 0)
        }
    }
    
    // Keep coarse summary in sync for any legacy consumers.
       private func recomputeSourcesSummary() {
           sources = VppSources.summary(for: sourcesTable)
       }

    // Tag row just above editor — inline E / echo behavior is handled via handleTagTap(_:)
    private var tagBand: some View {
        HStack {
            TagChipsView(
                primary: runtime.state.currentTag,
                echoTarget: modifiers.echoTarget,
                onSelect: handleTagTap(_:)
            )
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
                Group {
                    if let focusBinding {
                        TextEditor(text: $draft)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused(focusBinding)   // 👈 only when provided
                            .padding(.horizontal, AppTheme.Spacing.cardInner)
                            .padding(.vertical, AppTheme.Spacing.base * 1.2)
                    } else {
                        TextEditor(text: $draft)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .focused($isEditorFocused)   // 👈 local fallback
                            .padding(.horizontal, AppTheme.Spacing.cardInner)
                            .padding(.vertical, AppTheme.Spacing.base * 1.2)
                    }
                }
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
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .scale(scale: 0.98, anchor: .topLeading)),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.98, anchor: .topLeading))
                    )
                )
            }
        }
    }

    // MARK: - Send

    private var sendButton: some View {
        let isEnabled = (sendPhase == .idleReady)

        return SendButton(
            phase: sendPhase,
            isEnabled: isEnabled,
            action: sendAction
        )
        .fixedSize()
        .keyboardShortcut(.return, modifiers: [.command])
    }

    // MARK: - Tag handling (E / echo behavior)

    /// Inline E / echo behavior:
    /// - Normal: one primary tag.
    /// - If primary is E, we also use `modifiers.echoTarget` as `--<tag>`.
    private func handleTagTap(_ tapped: VppTag) {
        let current = runtime.state.currentTag
        var newPrimary = current
        var newEcho = modifiers.echoTarget

        // Helper: safe default when we need "some" tag to fall back to.
        func defaultPrimary() -> VppTag {
            // Prefer existing echo if it’s valid, otherwise fall back to G.
            if let echo = newEcho, echoableTags.contains(echo) {
                return echo
            }
            if echoableTags.contains(current) {
                return current
            }
            return .g
        }

        switch (current, tapped) {

        // 1. Not in E mode yet, user taps E → enter escape mode: !<e> --<primary?>
        case let (primary, .e) where primary != .e:
            newPrimary = .e
            if echoableTags.contains(primary) {
                newEcho = primary
            } else {
                newEcho = .g
            }

        // 1b. Not in E mode, tapping any non-E tag → simple selection.
        case (_, let tag) where current != .e:
            newPrimary = tag
            newEcho = nil

        // 2. Already in E mode, user taps E again → exit escape mode.
        case (.e, .e):
            newPrimary = defaultPrimary()
            newEcho = nil

        // 2b. In E mode, tap an echoable tag:
        //     - first tap: choose echo target and stay in E
        //     - second tap on same tag: exit E to that tag.
        case (.e, let tag) where echoableTags.contains(tag):
            if newEcho == tag {
                // Tapping same echo target → exit E mode to that tag.
                newPrimary = tag
                newEcho = nil
            } else {
                // Change echo target, remain in E mode.
                newPrimary = .e
                newEcho = tag
            }

        // 2c. In E mode, tap a non-echoable tag (e.g. e_o):
        //     treat as normal main tag, exit E mode.
        case (.e, let tag):
            newPrimary = tag
            newEcho = nil

        default:
            break
        }

        // Commit updates
        modifiers.echoTarget = newEcho
        tagSelection(newPrimary)
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
extension AssumptionsConfig {
    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
    var persistedCount: Int {
            switch self {
            case .none: return 0
            case .zero: return 0
            case .custom(let items): return items.count
            }
        }
}
