//
//  VPPRail.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct VPPRail: View {
  let chats: [ChatSummary]
  @Binding var selection: ChatSummary.ID?

  let heroNS: Namespace.ID
  let reduceMotion: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Recent")
          .font(.system(size: 12.5, weight: .semibold))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 8)

      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(chats) { chat in
            Row(chat: chat, isSelected: selection == chat.id, heroNS: heroNS, reduceMotion: reduceMotion) {
              select(chat.id)
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
      }
    }
  }

  private func select(_ id: ChatSummary.ID) {
    if reduceMotion {
      selection = id
    } else {
      withAnimation(Motion.luxSpring(duration: Motion.hero)) {
        selection = id
      }
    }
  }

  private struct Row: View {
    let chat: ChatSummary
    let isSelected: Bool
    let heroNS: Namespace.ID
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var hovering = false

    var body: some View {
      Button(action: onTap) {
        HStack(spacing: 10) {
          HeroBadge(id: chat.id, ns: heroNS)
            // When selected, hide the source badge so the destination badge feels like it "moved".
            .opacity(isSelected ? 0 : 1)

          VStack(alignment: .leading, spacing: 2) {
            Text(chat.title)
              .font(.system(size: 13.5, weight: .semibold))
              .lineLimit(1)
            Text(chat.preview)
              .font(.system(size: 12.5))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
             .fill(isSelected ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Color.clear))
        }
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.primary.opacity(hovering ? 0.10 : 0.06), lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .onHover { hovering = $0 }
      .motion(Motion.softEase(duration: Motion.micro), value: hovering, reduceMotion: reduceMotion)
    }
  }
}

struct HeroBadge: View {
  let id: UUID
  let ns: Namespace.ID

  var body: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
      .fill(.primary.opacity(0.10))
      .frame(width: 34, height: 34)
      .overlay {
        Image(systemName: "sparkles")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .matchedGeometryEffect(id: "hero-\(id.uuidString)", in: ns)
      .accessibilityHidden(true)
  }
}
