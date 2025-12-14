//
//  Mode.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct Mode: Identifiable, Hashable {
  let id: String
  let title: String
  let systemImage: String?

  init(_ id: String, title: String, systemImage: String? = nil) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
  }
}

struct ModeChips: View {
  let modes: [Mode]
  @Binding var selection: Mode.ID

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var ns

  var body: some View {
    HStack(spacing: 8) {
      ForEach(modes) { mode in
        Chip(mode: mode, selection: $selection, ns: ns)
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(radius: 6, y: 2)
    .motion(Motion.luxSpring(duration: Motion.standard), value: selection, reduceMotion: reduceMotion)
  }

  private struct Chip: View {
    let mode: Mode
    @Binding var selection: Mode.ID
    let ns: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var press = false

    var isSelected: Bool { selection == mode.id }

    var body: some View {
      Button {
        if reduceMotion {
          selection = mode.id
        } else {
          withAnimation(Motion.luxSpring(duration: Motion.standard)) {
            selection = mode.id
          }
        }
      } label: {
        HStack(spacing: 6) {
          if let systemImage = mode.systemImage {
            Image(systemName: systemImage)
              .font(.system(size: 12, weight: .semibold))
              .symbolSwap(reduceMotion: reduceMotion)
          }
          Text(mode.title)
            .font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background {
          ZStack {
            if isSelected {
              RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.ultraThinMaterial)
                .matchedGeometryEffect(id: "chip-pill", in: ns)
            }
          }
        }
        .overlay {
          RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(.primary.opacity(hovering ? 0.14 : 0.08), lineWidth: 1)
        }
        .scaleEffect(press ? 0.985 : 1)
        .opacity(hovering ? 1 : 0.98)
      }
      .buttonStyle(.plain)
      .onHover { hovering = $0 }
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in press = true }
          .onEnded { _ in press = false }
      )
      .motion(Motion.softEase(duration: Motion.micro), value: hovering, reduceMotion: reduceMotion)
      .motion(Motion.luxSpring(duration: Motion.micro), value: press, reduceMotion: reduceMotion)
    }
  }
}
