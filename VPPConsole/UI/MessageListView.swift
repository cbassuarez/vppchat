import SwiftUI

struct MessageListView: View {
    var messages: [Message]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(messages) { message in
                    MessageCard(message: message, reduceMotion: reduceMotion)
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .animation(.easeOut(duration: 0.2), value: messages.count)
        }
    }
}

private struct MessageCard: View {
    let message: Message
    let reduceMotion: Bool
    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(message.isUser ? "YOU" : "ASSISTANT")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(message.body)
                .font(.system(size: 14, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                metadataChip(title: "TAG", value: message.tag.rawValue.uppercased())
                metadataChip(title: "CYCLE", value: "\(message.cycleIndex)")
                metadataChip(title: "ASSUMPTIONS", value: "\(message.assumptions)")
                metadataChip(title: "SOURCES", value: message.sources.rawValue.uppercased())
                if let locus = message.locus, !locus.isEmpty {
                    metadataChip(title: "LOCUS", value: locus)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(message.isValidVpp ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                    .frame(width: 8, height: 8)
            }
            .font(.system(size: 10, weight: .semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTint)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .blendMode(.overlay)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1 : 0)
        .blur(radius: reduceMotion ? 0 : (isVisible ? 0 : 9))
        .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 12))
        .onAppear {
            guard !isVisible else { return }
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
        }
    }

    private var backgroundTint: some View {
        let base = message.isUser ? Color.orange.opacity(0.08) : Color.indigo.opacity(0.08)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(base)
    }

    private func metadataChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .textCase(.uppercase)
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06).blendMode(.plusLighter))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.6)
        )
    }
}

#Preview {
    let appVM = AppViewModel()
    MessageListView(messages: appVM.store.sessions.first?.messages ?? [])
}
