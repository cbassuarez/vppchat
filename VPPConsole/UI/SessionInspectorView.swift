import SwiftUI

struct SessionInspectorView: View {
    var session: Session

    var body: some View {
        Form {
            Section("Session") {
                Text(session.name)
                if let locus = session.locus {
                    Text("Locus: \(locus)")
                }
                Text("Created: \(session.createdAt.formatted())")
                Text("Messages: \(session.messages.count)")
            }
            Section("System Prompt") {
                Text("Not configurable yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    if let session = AppViewModel().store.sessions.first {
        SessionInspectorView(session: session)
    }
}
