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
struct StreamingMessageBody: View {
    let message: Message
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleLines: Int = 0

    private var lines: [String] {
        message.body
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

    private var shouldAnimate: Bool {
        // Animate assistant / model output, keep user messages snappy
        !message.isUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(visibleLines > index ? 1 : 0)
                    .animation(
                        reduceMotion || !shouldAnimate
                        ? .none
                        : .easeOut(duration: 0.22)
                            .delay(Double(index) * 0.06),
                        value: visibleLines
                    )
            }
        }
        .onAppear {
            if reduceMotion || !shouldAnimate {
                visibleLines = lines.count
            } else {
                visibleLines = 0
                DispatchQueue.main.async {
                    visibleLines = lines.count
                }
            }
        }
    }
}

struct MessageRow: View {
    let message: Message

    private var authorLabel: String {
        message.isUser ? "YOU" : "ASSISTANT"
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var theme: ThemeManager

    @State private var showInvalidPulse: Bool = false

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

            // Streaming body instead of a single Text
            StreamingMessageBody(message: message)

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
            AppTheme.Colors.surface2
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card, style: .continuous)
                .stroke(borderColor, lineWidth: showInvalidPulse ? 2.0 : 1.0)
                .shadow(color: glowColor, radius: showInvalidPulse ? 10 : 0)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 6, x: 6, y: 6)
        .onAppear {
            triggerInvalidPulseIfNeeded()
        }
        .onChange(of: message.isValidVpp) { _ in
            triggerInvalidPulseIfNeeded()
        }
    }

    private var borderColor: Color {
        message.isValidVpp ? AppTheme.Colors.borderSoft : AppTheme.Colors.statusMajor
    }

    private var glowColor: Color {
        message.isValidVpp ? Color.clear : AppTheme.Colors.statusMajor.opacity(0.55)
    }

    private func triggerInvalidPulseIfNeeded() {
        guard !message.isValidVpp, !reduceMotion else { return }

        showInvalidPulse = false
        theme.signal(.errorHighlight)

        withAnimation(AppTheme.Motion.invalidPulse) {
            showInvalidPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(AppTheme.Motion.invalidPulse) {
                showInvalidPulse = false
            }
        }
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
        .background(AppTheme.Colors.surface2.opacity(0.7))
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
                    .fill(AppTheme.Colors.statusMajor)
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
