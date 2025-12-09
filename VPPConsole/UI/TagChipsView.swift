import SwiftUI

struct TagChipsView: View {
    var selected: VppTag
    var onSelect: (VppTag) -> Void

    @State private var hoveredTag: VppTag?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VppTag.allCases, id: \.self) { tag in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        onSelect(tag)
                    }
                } label: {
                    Text(tag.rawValue.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(minWidth: 34)
                        .background(chipBackground(tag))
                        .overlay(
                            Capsule()
                                .stroke(chipStroke(tag), lineWidth: 1)
                        )
                        .foregroundStyle(chipForeground(tag))
                        .clipShape(Capsule())
                        .shadow(color: tag == selected ? accentColor(for: tag).opacity(0.35) : .clear, radius: 8, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredTag = hovering ? tag : nil
                }
            }
        }
    }

    private func accentColor(for tag: VppTag) -> Color {
        switch tag {
        case .e, .e_o:
            return Color.pink
        default:
            return Color.indigo
        }
    }

    private func chipBackground(_ tag: VppTag) -> Color {
        if tag == selected {
            return accentColor(for: tag).opacity(0.28)
        }
        if hoveredTag == tag {
            return Color.primary.opacity(0.07)
        }
        return Color.primary.opacity(0.05)
    }

    private func chipStroke(_ tag: VppTag) -> Color {
        if tag == selected { return accentColor(for: tag).opacity(0.55) }
        if hoveredTag == tag { return Color.primary.opacity(0.2) }
        return Color.secondary.opacity(0.25)
    }

    private func chipForeground(_ tag: VppTag) -> Color {
        tag == selected ? .white : .primary
    }
}

#Preview {
    TagChipsView(selected: .g, onSelect: { _ in })
}
