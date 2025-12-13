import SwiftUI

struct ShellModeCommands: Commands {
    @Binding var mode: ShellMode

    init(mode: Binding<ShellMode>) {
        _mode = mode
    }

    var body: some Commands {
        CommandMenu("Shell Mode") {
            Button("Console") {
                mode = .console
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Studio") {
                mode = .studio
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Atlas") {
                mode = .atlas
            }
            .keyboardShortcut("3", modifiers: [.command])
        }
    }
}
