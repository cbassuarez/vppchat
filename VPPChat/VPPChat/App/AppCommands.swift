import SwiftUI

struct AppCommands: Commands {
    @Binding private var shellMode: ShellMode
    @ObservedObject private var workspaceViewModel: WorkspaceViewModel
    @ObservedObject private var appViewModel: AppViewModel

    init(shellMode: Binding<ShellMode>, workspaceViewModel: WorkspaceViewModel, appViewModel: AppViewModel) {
        _shellMode = shellMode
        _workspaceViewModel = ObservedObject(initialValue: workspaceViewModel)
        _appViewModel = ObservedObject(initialValue: appViewModel)
    }

    var body: some Commands {
        CommandMenu("Shell") {
            Button("Console") {
                shellMode = .console
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Studio") {
                shellMode = .studio
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Atlas") {
                shellMode = .atlas
            }
            .keyboardShortcut("3", modifiers: .command)
            Button("Copy Last Assistant Message") {
                workspaceViewModel.copyLastAssistantMessage()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

        }

        CommandMenu("Command Space") {
            Button(workspaceViewModel.isCommandSpaceVisible ? "Hide Command Space" : "Show Command Space") {
                withAnimation(AppTheme.Motion.commandSpace) {
                    workspaceViewModel.isCommandSpaceVisible.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        CommandMenu("Console") {
            Button("Focus Composer") {
                shellMode = .console
                workspaceViewModel.focusConsoleComposer()
            }
            .keyboardShortcut("l", modifiers: .command)
        }
        
        CommandMenu("File") {
            Button("New…") {
                workspaceViewModel.presentSceneCreationWizard(initialGoal: .newScene)
            }
            .keyboardShortcut("n", modifiers: .command)
        }


        CommandMenu("Studio") {
            Button("Next Scene") {
                shellMode = .studio
                workspaceViewModel.selectNextScene()
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])

            Button("Previous Scene") {
                shellMode = .studio
                workspaceViewModel.selectPreviousScene()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
        }
    }
}
