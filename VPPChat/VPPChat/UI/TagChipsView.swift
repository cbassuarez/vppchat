import SwiftUI

struct TagChipsView: View {
    /// The primary tag that will be sent in `!<tag>`.
    var primary: VppTag

    /// When `primary == .e`, this is the tag used for `--<tag>`.
    /// Otherwise it is ignored.
    var echoTarget: VppTag?

    var onSelect: (VppTag) -> Void

    /// Only show the core VPP tags; never show `o_f` in the UI.
    private var visibleTags: [VppTag] {
        [.g, .q, .o, .c, .e, .e_o]
    }

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
            ForEach(visibleTags, id: \.self) { tag in
                let isPrimary = (tag == primary)
                let isEcho    = (primary == .e && echoTarget == tag)

                Button(action: {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                        onSelect(tag)
                    }
                }) {
                    Text(tagLabel(tag))
                        .font(AppTheme.Typography.chip)
                        .textCase(.uppercase)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 32)
                        .background(
                            chipBackground(for: tag, isPrimary: isPrimary, isEcho: isEcho)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    borderColor(for: tag, isPrimary: isPrimary, isEcho: isEcho),
                                    style: borderStyle(for: tag, isPrimary: isPrimary, isEcho: isEcho)
                                )
                        )
                        .clipShape(Capsule())
                        .foregroundStyle(
                            foregroundColor(for: tag, isPrimary: isPrimary, isEcho: isEcho)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Styling helpers

    private func chipBackground(for tag: VppTag,
                                isPrimary: Bool,
                                isEcho: Bool) -> some View {
        ZStack {
            if isPrimary {
                accent(for: tag)
                    .opacity(0.22)
                    .shadow(
                        color: accent(for: tag).opacity(0.2),
                        radius: 6, x: 6, y: 6
                    )
            } else if isEcho {
                accent(for: tag)
                    .opacity(0.16)
            } else {
                AppTheme.Colors.surface2.opacity(0.4)
            }
        }
    }

    private func borderColor(for tag: VppTag,
                             isPrimary: Bool,
                             isEcho: Bool) -> Color {
        if isPrimary || isEcho {
            return accent(for: tag)
        } else {
            return AppTheme.Colors.borderSoft
        }
    }

    private func borderStyle(for tag: VppTag,
                             isPrimary: Bool,
                             isEcho: Bool) -> StrokeStyle {
        let width: CGFloat = (isPrimary || isEcho) ? 1.4 : 1.0

        // E is always dashed — that’s our “escape” semiotic.
        if tag == .e {
            return StrokeStyle(
                lineWidth: width,
                lineCap: .round,
                dash: [4, 3]
            )
        } else {
            return StrokeStyle(lineWidth: width, lineCap: .round)
        }
    }

    private func foregroundColor(for tag: VppTag,
                                 isPrimary: Bool,
                                 isEcho: Bool) -> Color {
        if isPrimary || isEcho {
            return AppTheme.Colors.textPrimary
        } else {
            return AppTheme.Colors.textSecondary
        }
    }

    private func tagLabel(_ tag: VppTag) -> String {
        switch tag {
        case .g:   return "G"
        case .q:   return "Q"
        case .o:   return "O"
        case .c:   return "C"
        case .o_f: return "O_F"
        case .e:   return "E"
        case .e_o: return "E_O"
        }
    }
}

#Preview {
    TagChipsView(
        primary: .g,
        echoTarget: nil,
        onSelect: { _ in }
    )
    .padding()
    .background(NoiseBackground())
}
