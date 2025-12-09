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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TagChipsView(selected: runtime.state.currentTag, onSelect: tagSelection)
                Spacer()
                Picker("Correctness", selection: $modifiers.correctness) {
                    Text("Neutral").tag(VppCorrectness.neutral)
                    Text("Correct").tag(VppCorrectness.correct)
                    Text("Incorrect").tag(VppCorrectness.incorrect)
                }
                .pickerStyle(.segmented)
                Picker("Severity", selection: $modifiers.severity) {
                    Text("None").tag(VppSeverity.none)
                    Text("Minor").tag(VppSeverity.minor)
                    Text("Major").tag(VppSeverity.major)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Stepper("Assumptions: \(runtime.state.assumptions)", value: Binding(
                    get: { runtime.state.assumptions },
                    set: { runtime.setAssumptions($0) }
                ), in: 0...10)

                HStack {
                    Text("Cycle \(runtime.state.cycleIndex) / 3")
                    Button("Next") { stepCycle() }
                    Button("New") { resetCycle() }
                }

                HStack {
                    Text("Locus:")
                    TextField("locus", text: Binding(
                        get: { runtime.state.locus ?? "" },
                        set: { runtime.setLocus($0) }
                    ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                Picker("Sources", selection: $sources) {
                    Text("None").tag(VppSources.none)
                    Text("Web").tag(VppSources.web)
                }
                .pickerStyle(.menu)
            }

            TextEditor(text: $draft)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .keyboardShortcut(.return, modifiers: [.command])

            HStack {
                Spacer()
                Button(action: sendAction) {
                    Label("Send", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
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
