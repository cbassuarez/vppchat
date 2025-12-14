import SwiftUI

private struct ShellModeBindingKey: EnvironmentKey {
    static let defaultValue: Binding<ShellMode>? = nil
}

extension EnvironmentValues {
    var shellModeBinding: Binding<ShellMode>? {
        get { self[ShellModeBindingKey.self] }
        set { self[ShellModeBindingKey.self] = newValue }
    }
}
