import SwiftUI

struct MessageListView: View {
    var messages: [Message]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(message.isUser ? "You" : "Assistant")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(message.timestamp, style: .time)
                                .foregroundStyle(.secondary)
                        }
                        Text(message.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 8) {
                            Label("\(message.tag.rawValue)", systemImage: "tag")
                            Text("Cycle \(message.cycleIndex)")
                            Text("Assumptions \(message.assumptions)")
                            Text("Sources: \(message.sources.rawValue)")
                            if let locus = message.locus {
                                Text("Locus: \(locus)")
                            }
                            if message.isValidVpp {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    let appVM = AppViewModel()
    MessageListView(messages: appVM.store.sessions.first?.messages ?? [])
}
