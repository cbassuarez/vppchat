import SwiftUI

struct BlockCardView: View {
    let block: Block

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(block.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                Spacer()

                Text(block.createdAt, style: .time)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
            }

            if let subtitle = block.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
            }

            switch block.kind {
            case .conversation:
                ForEach(Array(block.messages.suffix(2)), id: \.id) { message in
                    Text(message.body)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(3)
                }

            case .document:
                if let text = block.documentText {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(4)
                }

            case .reference:
                if let text = block.documentText {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(StudioTheme.Colors.textPrimary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 6) {
                if block.isCanonical {
                    chip("CANONICAL")
                }

                chip(block.kind.rawValue.uppercased())
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.Radii.card, style: .continuous)
                        .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }

    private func chip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(StudioTheme.Colors.panel.opacity(0.9))
            )
            .foregroundStyle(StudioTheme.Colors.textSecondary)
    }
}
