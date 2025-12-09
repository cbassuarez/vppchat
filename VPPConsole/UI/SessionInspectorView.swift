import SwiftUI

struct SessionInspectorView: View {
    var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SESSION")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(session.name)
                    .font(.system(size: 14, weight: .semibold))
                if let locus = session.locus {
                    Text("Locus: \(locus)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Text("Created: \(session.createdAt.formatted())")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Messages: \(session.messages.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SYSTEM PROMPT")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text("Not configurable yet.")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

#Preview {
    if let session = AppViewModel().store.sessions.first {
        SessionInspectorView(session: session)
    }
}
