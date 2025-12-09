import SwiftUI

struct MessageListView: View {
    var messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.base * 1.5) {
                ForEach(messages) { message in
                    MessageRow(message: message)
                        .padding(.horizontal, AppTheme.Spacing.outerHorizontal)
                        .transition(.asymmetric(
                            insertion: AnyTransition.opacity
                                .combined(with: .move(edge: .bottom))
                                .combined(with: .modifier(
                                    active: BlurModifier(radius: 10),
                                    identity: BlurModifier(radius: 0)
                                )),
                            removal: .opacity
                        ))
                        .animation(.easeOut(duration: AppTheme.Motion.fast), value: messages.count)
                }
            }
            .padding(.vertical, AppTheme.Spacing.base)
        }
    }
}

// A simple blur modifier to use in transitions.
struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

struct MessageRow: View {
    let message: Message

    private var authorLabel: String {
        message.isUser ? "YOU" : "ASSISTANT"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(authorLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Colors.textSubtle)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Text(message.body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                metaChip(label: "TAG", value: message.tag.rawValue.uppercased())
                metaChip(label: "CYCLE", value: "\(message.cycleIndex)")
                metaChip(label: "ASSUMPTIONS", value: "\(message.assumptions)")
                metaChip(label: "SOURCES", value: message.sources.rawValue.uppercased())
                if let locus = message.locus, !locus.isEmpty {
                    metaChip(label: "LOCUS", value: locus)
                        .lineLimit(1)
                }

                Spacer()

                validityDot
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.cardInner)
        .background(
            AppTheme.Colors.surface1
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 16)
    }

    private func metaChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 11, weight: .regular))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.Colors.surface0.opacity(0.7))
        .clipShape(Capsule())
    }

    private var validityDot: some View {
        Group {
            if message.isValidVpp {
                Circle()
                    .fill(AppTheme.Colors.statusCorrect)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(AppTheme.Colors.statusMinor)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    let appVM = AppViewModel()
    MessageListView(messages: appVM.store.sessions.first?.messages ?? [])
        .background(NoiseBackground())
}
