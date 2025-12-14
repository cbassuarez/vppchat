//
//  ChatSummary.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct ChatSummary: Identifiable, Hashable {
  let id: UUID
  var title: String
  var preview: String
  var updatedAt: Date
}

struct VPPBrowserShell: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var heroNS

  @State private var modeSelection: Mode.ID = "chat"
  @State private var chats: [ChatSummary] = [
    .init(id: UUID(), title: "VPP: Spec pass", preview: "Lock motion tokens + continuity pass", updatedAt: .now),
    .init(id: UUID(), title: "Atlas: Filters", preview: "Chip sizing + popover polish", updatedAt: .now.addingTimeInterval(-3600)),
    .init(id: UUID(), title: "Docs: Reader", preview: "Navigation semantics and prompt loops", updatedAt: .now.addingTimeInterval(-9000))
  ]
  @State private var selection: ChatSummary.ID? = nil

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        rail
          .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        bodyPane
          .frame(minWidth: 520)
      }
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      ModeChips(
        modes: [
          .init("chat", title: "Chat", systemImage: "bubble.left.and.bubble.right"),
          .init("atlas", title: "Atlas", systemImage: "square.grid.2x2"),
          .init("docs", title: "Docs", systemImage: "doc.text")
        ],
        selection: $modeSelection
      )

      Spacer()

      Button {
        startNewChat()
      } label: {
        Label("New", systemImage: "plus")
          .font(.system(size: 12.5, weight: .semibold))
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(12)
  }

  private var rail: some View {
    VPPRail(
      chats: chats,
      selection: $selection,
      heroNS: heroNS,
      reduceMotion: reduceMotion
    )
    .background(.background)
  }

  private var bodyPane: some View {
    MessageBody(
      chat: chats.first(where: { $0.id == selection }),
      onBackToList: { backToList() },
      heroNS: heroNS,
      reduceMotion: reduceMotion
    )
    .background(.background)
  }

  private func startNewChat() {
    let new = ChatSummary(id: UUID(), title: "New chat", preview: "Draft…", updatedAt: .now)
    chats.insert(new, at: 0)

    if reduceMotion {
      selection = new.id
    } else {
      withAnimation(Motion.luxSpring(duration: Motion.hero)) {
        selection = new.id
      }
    }
  }

  private func backToList() {
    if reduceMotion {
      selection = nil
    } else {
      withAnimation(Motion.luxSpring(duration: Motion.standard)) {
        selection = nil
      }
    }
  }
}
