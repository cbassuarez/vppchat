import SwiftUI

struct CommandSpaceView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query: String = ""
    @State private var isHovering: Bool = false
    @State private var selectionIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    private var items: [CommandSpaceItem] {
        vm.commandSpaceItems(for: query)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            searchField
            resultsList
            keyboardHintRow
        }
        .padding(16)
        .background(
            // Outer glass card
            .ultraThinMaterial.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(StudioTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 6, y: 12)
        .padding()
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.18)) {
                isHovering = hovering
            }
        }
        .onChange(of: query) { _ in
            selectionIndex = 0
        }
        .onChange(of: items) { newValue in
            if newValue.isEmpty {
                selectionIndex = 0
            } else {
                selectionIndex = min(selectionIndex, newValue.count - 1)
            }
        }
        .onAppear {
       #if os(macOS)
                   isSearchFocused = true       // 👈 auto-focus search when Command Space opens
       #endif
               }
    }

    private var header: some View {
        HStack {
            Text("Command Space")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.Colors.textPrimary)

            Spacer()

            if isHovering {
                Text("⇧⌘K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button(action: {
                withAnimation(reduceMotion ? .default : AppTheme.Motion.commandSpace) {
                    vm.isCommandSpaceVisible = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(StudioTheme.Colors.textSecondary)
                    .symbolRenderingMode(.hierarchical)
#if os(macOS)
                    .symbolEffect(.bounce, value: vm.isCommandSpaceVisible)
#endif
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        TextField("Jump to block, scene, or command", text: $query)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                .ultraThinMaterial.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surface0)
            )
            .foregroundStyle(StudioTheme.Colors.textPrimary)
    #if os(macOS)
            .focused($isSearchFocused)   // 👈 make the TextField the focused view for key events
            .onKeyPress(.upArrow) {
                moveSelection(delta: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(delta: 1)
                return .handled
            }
            .onKeyPress(.return) {
                executeSelectedItem()
                return .handled
            }
            .onKeyPress(.escape) {
                withAnimation(AppTheme.Motion.commandSpace) {
                    vm.isCommandSpaceVisible = false
                }
                return .handled
            }
    #endif
    }

    @ViewBuilder
    private var resultsList: some View {
        if items.isEmpty && !query.isEmpty {
            Text("No matches")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .padding(.top, 4)
        } else if items.isEmpty && query.isEmpty {
            Text("Recent messages will appear here.")
                .font(.system(size: 11))
                .foregroundStyle(StudioTheme.Colors.textSecondary)
                .padding(.top, 4)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                        CommandSpaceResultRow(item: item, isSelected: idx == selectionIndex)
                            .onTapGesture {
                                selectionIndex = idx
                                executeSelectedItem()
                            }
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    private var keyboardHintRow: some View {
        HStack(spacing: 8) {
            Text("↑/↓ to move")
            Text("↩ to open")
            Text("Esc to close")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(StudioTheme.Colors.textSubtle)
        .padding(.top, 6)
    }

    private func moveSelection(delta: Int) {
        guard !items.isEmpty else { return }
        let newIndex = max(0, min(selectionIndex + delta, items.count - 1))
        selectionIndex = newIndex
    }

    private func executeSelectedItem() {
        guard items.indices.contains(selectionIndex) else { return }
        let item = items[selectionIndex]
        vm.performCommandSpaceItem(item)

        if item.kind == .action {
            vm.isCommandSpaceVisible = false
        }
    }
}

private struct CommandSpaceResultRow: View {
    let item: CommandSpaceItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? StudioTheme.Colors.accent : StudioTheme.Colors.textSecondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(StudioTheme.Colors.textPrimary)

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(StudioTheme.Colors.textSecondary)
                }
            }

            Spacer()

            Text(item.typeLabel)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioTheme.Colors.surface1.opacity(0.8))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(StudioTheme.Colors.borderSoft.opacity(0.7), lineWidth: 1)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? StudioTheme.Colors.accentSoft.opacity(0.8) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? StudioTheme.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

