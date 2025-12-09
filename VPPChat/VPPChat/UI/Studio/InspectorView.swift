import SwiftUI

struct InspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inspector")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Text("Block / scene metadata will appear here.")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)

            Spacer()
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: StudioTheme.Radii.panel, style: .continuous)
        )
    }
}
