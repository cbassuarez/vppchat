import SwiftUI

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                    .fill(AppTheme.Colors.surface0)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                            .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous))
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 8)
    }
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}
