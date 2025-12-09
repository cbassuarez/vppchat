import SwiftUI

struct TagChipsView: View {
    var selected: VppTag
    var onSelect: (VppTag) -> Void

    private func accent(for tag: VppTag) -> Color {
        switch tag {
        case .e, .e_o:
            return AppTheme.Colors.exceptionAccent
        default:
            return AppTheme.Colors.structuralAccent
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(VppTag.allCases, id: \.self) { tag in
                Button(action: { withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) { onSelect(tag) } }) {
                    Text(tagLabel(tag))
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .textCase(.uppercase)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 32)
                        .background(
                            ZStack {
                                if selected == tag {
                                    accent(for: tag)
                                        .opacity(0.22)
                                        .shadow(color: accent(for: tag).opacity(0.4), radius: 8, x: 0, y: 6)
                                } else {
                                    AppTheme.Colors.surface1.opacity(0.4)
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selected == tag
                                    ? accent(for: tag)
                                    : AppTheme.Colors.borderSoft,
                                    lineWidth: selected == tag ? 1.4 : 1
                                )
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(selected == tag ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                //.hoverEffect(.highlight)
            }
        }
    }

    private func tagLabel(_ tag: VppTag) -> String {
        switch tag {
        case .g: return "G"
        case .q: return "Q"
        case .o: return "O"
        case .c: return "C"
        case .o_f: return "O_F"
        case .e: return "E"
        case .e_o: return "E_O"
        }
    }
}

#Preview {
    TagChipsView(selected: .g, onSelect: { _ in })
        .padding()
        .background(NoiseBackground())
}
