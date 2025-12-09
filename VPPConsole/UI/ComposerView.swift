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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CYCLE")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text("\(runtime.state.cycleIndex) / 3")
                            .font(.system(size: 13, weight: .medium))
                            .monospaced()
                        pillButton(title: "Next", systemImage: "chevron.right", action: stepCycle)
                        pillButton(title: "New", systemImage: "arrow.counterclockwise", action: resetCycle)
                    }
                }

                Divider().frame(height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ASSUMPTIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Stepper(value: Binding(
                        get: { runtime.state.assumptions },
                        set: { runtime.setAssumptions($0) }
                    ), in: 0...10) {
                        Text("\(runtime.state.assumptions)")
                            .font(.system(size: 13, weight: .medium))
                            .monospaced()
                    }
                    .frame(maxWidth: 140)
                }

                Divider().frame(height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCUS")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    TextField("locus", text: Binding(
                        get: { runtime.state.locus ?? "" },
                        set: { runtime.setLocus($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                }

                Spacer()

                Picker("Sources", selection: $sources) {
                    Text("None").tag(VppSources.none)
                    Text("Web").tag(VppSources.web)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $draft)
                        .font(.system(size: 14))
                        .frame(minHeight: 160, maxHeight: 240)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)

                    HStack(alignment: .center, spacing: 10) {
                        TagChipsView(selected: runtime.state.currentTag, onSelect: tagSelection)

                        correctnessChips
                        severityChips

                        Spacer()

                        sendButton
                    }
                }
                .padding(16)
            }
        }
    }

    private var sendButton: some View {
        let isDisabled = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button(action: sendAction) {
            Label("Send", systemImage: "paperplane.fill")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.indigo.opacity(isDisabled ? 0.25 : 0.6)))
                .shadow(color: Color.indigo.opacity(isDisabled ? 0 : 0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.65 : 1)
    }

    private var correctnessChips: some View {
        HStack(spacing: 6) {
            chip(label: "Neutral", color: Color.green.opacity(0.15), isSelected: modifiers.correctness == .neutral) {
                modifiers.correctness = .neutral
            }
            chip(label: "Correct", color: Color.green.opacity(0.35), isSelected: modifiers.correctness == .correct) {
                modifiers.correctness = .correct
            }
            chip(label: "Incorrect", color: Color.red.opacity(0.25), isSelected: modifiers.correctness == .incorrect) {
                modifiers.correctness = .incorrect
            }
        }
    }

    private var severityChips: some View {
        HStack(spacing: 6) {
            chip(label: "None", color: Color.gray.opacity(0.15), isSelected: modifiers.severity == .none) {
                modifiers.severity = .none
            }
            chip(label: "Minor", color: Color.yellow.opacity(0.25), isSelected: modifiers.severity == .minor) {
                modifiers.severity = .minor
            }
            chip(label: "Major", color: Color.red.opacity(0.32), isSelected: modifiers.severity == .major) {
                modifiers.severity = .major
            }
        }
    }

    private func chip(label: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? color : Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(isSelected ? color.opacity(0.9) : Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func pillButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
                .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let appVM = AppViewModel()
    ComposerView(
        draft: .constant("Hello"),
        modifiers: .constant(VppModifiers()),
        sources: .constant(.none),
        runtime: appVM.runtime,
        sendAction: {},
        tagSelection: { _ in },
        stepCycle: {},
        resetCycle: {}
    )
    .padding()
}
