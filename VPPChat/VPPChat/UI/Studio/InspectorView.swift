import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            // TODO: block / scene specific metadata cards here

            Spacer(minLength: 8)

            // Session model config at the bottom of the inspector
            ConsoleSessionInspectorView(
                modelID: $vm.consoleModelID,
                temperature: $vm.consoleTemperature,
                contextStrategy: $vm.consoleContextStrategy
            )
        }
        .padding(12)
        .panelBackground()
    }
}
