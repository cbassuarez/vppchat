//
//  MessageBody.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct MessageBody___LIVE_CHECK: View {
  let chat: ChatSummary?
  let onBackToList: () -> Void

  let heroNS: Namespace.ID
  let reduceMotion: Bool

  @State private var draft: String = ""
  @State private var sendTick: Int = 0
    @State private var isSending: Bool = false
    @State private var sendFlash: Bool = false
  @State private var showSentCheck: Bool = false
  @State private var showComposer: Bool = true
    @State private var sendAnimFlash = false
    @State private var sendRingT: CGFloat = 0
    @State private var sendRingVisible = false

  var body: some View {
    VStack(spacing: 0) {
      if let chat {
        header(chat: chat)
      } else {
        emptyState
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if let chat {
            Text("Message body for **\(chat.title)**")
              .font(.system(size: 15))
            Text("This is the area you’ll wire up later. For now, the goal is motion + continuity quality.")
              .foregroundStyle(.secondary)
              .font(.system(size: 13.5))
          } else {
            Text("Select a chat from the rail, or start a new one.")
              .foregroundStyle(.secondary)
              .font(.system(size: 13.5))
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
      }

      Divider()

      if showComposer {
        composer
          .transition(reduceMotion ? .opacity : MotionTransition.liftFade(y: 10))
          .motion(Motion.luxSpring(duration: Motion.standard), value: showComposer, reduceMotion: reduceMotion)
      }
    }
  }

  private func header(chat: ChatSummary) -> some View {
    HStack(spacing: 12) {
      HeroBadge(id: chat.id, ns: heroNS)
        // Destination badge is larger; matched geometry animates it.
        .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 2) {
        Text(chat.title)
          .font(.system(size: 16.5, weight: .semibold))
        Text(chat.preview)
          .font(.system(size: 12.5))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button {
        onBackToList()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 12.5, weight: .semibold))
      }
      .buttonStyle(.bordered)
      .help("Back to list")
    }
    .padding(16)
  }

  private var emptyState: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("No chat selected")
          .font(.system(size: 16.5, weight: .semibold))
        Text("Pick one from the rail to see continuity in action.")
          .font(.system(size: 12.5))
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(16)
  }

  private var composer: some View {
    HStack(spacing: 10) {
        Text("LIVE")
            .font(.caption2)
            .padding(4)
            .background(Color.red.opacity(0.6))
            .clipShape(Capsule())
      TextField("Message…", text: $draft, axis: .vertical)
        .textFieldStyle(.plain)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let armed = isSending || !trimmed.isEmpty
      Button {
        send()
      } label: {
          SendIcon(sent: showSentCheck, tick: sendTick, reduceMotion: reduceMotion)
              .overlay(alignment: .topTrailing) { Text("\(sendTick)").font(.caption2) }
      }
      .buttonStyle(.plain)
      .padding(.vertical, 9)
      .padding(.horizontal, 11)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.thinMaterial)
          .opacity(armed ? 1 : 0.35)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
      }
      .overlay {
        // One-shot "ink flash" on click
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.primary.opacity(sendFlash ? 0.14 : 0))
          .animation(.easeOut(duration: 0.22), value: sendFlash)
          .allowsHitTesting(false)
      }
      .opacity(armed ? 1 : 0.55)
      .scaleEffect(sendFlash ? 0.985 : 1)
      .animation(Motion.softEase(duration: Motion.short), value: armed)
      .animation(Motion.luxSpring(duration: Motion.short), value: sendFlash)
      .allowsHitTesting(armed && !isSending)
      .help("Send")
    }
    .padding(12)
    .background(.background)
  }
    private struct SendIcon: View {
      let sent: Bool
      let tick: Int
      let reduceMotion: Bool

      @State private var ringT: CGFloat = 0
      @State private var showRing = false

      var body: some View {
        ZStack {
          // Departing plane
          Image(systemName: "paperplane.fill")
            .opacity(sent ? 0 : 1)
            .offset(x: (!reduceMotion && sent) ? 7 : 0,
                    y: (!reduceMotion && sent) ? -7 : 0)
            .rotationEffect((!reduceMotion && sent) ? .degrees(-12) : .zero)
            .scaleEffect((!reduceMotion && sent) ? 0.90 : 1)

          // Confirmation
          Image(systemName: "checkmark")
            .opacity(sent ? 1 : 0)
            .scaleEffect(sent ? 1 : 0.92)
        }
        .font(.system(size: 13.5, weight: .semibold))
        .overlay {
          // “Ink ring” one-shot (trim draw)
          Circle()
            .trim(from: 0, to: ringT)
            .stroke(.primary.opacity(0.35), lineWidth: 2)
            .scaleEffect(0.90 + ringT * 0.35)
            .opacity(showRing ? (1 - ringT) : 0)
            .allowsHitTesting(false)
        }
        .animation(Motion.luxSpring(duration: Motion.short), value: sent)
        .onChange(of: tick) { _ in
          guard !reduceMotion else { return }
          showRing = true
          ringT = 0
          withAnimation(.easeOut(duration: 0.34)) {
            ringT = 1
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            showRing = false
          }
        }
      }
    }


  private func send() {
      print("SEND tapped", Date())
      let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
      
        isSending = true
        sendFlash = true
        showSentCheck = true
        sendTick &+= 1
      
        // Clear text immediately, but keep button armed via isSending
        draft = ""
      
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
          sendFlash = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
          showSentCheck = false
         isSending = false
        }
  }
}
