import SwiftUI

struct TagChipsView: View {
    var selected: VppTag
    var onSelect: (VppTag) -> Void

    var body: some View {
        HStack {
            ForEach(VppTag.allCases, id: \.self) { tag in
                Button(action: { onSelect(tag) }) {
                    Text(tag.rawValue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tag == selected ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    TagChipsView(selected: .g, onSelect: { _ in })
}
