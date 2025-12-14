//
//  VPPMotionDemoApp.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

struct SettingsRoot: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pane: Pane = .general

  enum Pane: String, CaseIterable, Identifiable {
    case general = "General"
    case motion = "Motion"
    case advanced = "Advanced"
    var id: String { rawValue }
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Pane", selection: $pane) {
        ForEach(Pane.allCases) { p in
          Text(p.rawValue).tag(p)
        }
      }
      .pickerStyle(.segmented)
      .padding(12)

      Divider()

      Group {
        switch pane {
        case .general:
          paneCard(title: "General", lines: 6)
        case .motion:
          paneCard(title: "Motion", lines: 12)
        case .advanced:
          paneCard(title: "Advanced", lines: 18)
        }
      }
      .padding(12)
      .motion(Motion.luxSpring(duration: Motion.standard), value: pane, reduceMotion: reduceMotion)
    }
    .frame(minWidth: 520)
  }

  private func paneCard(title: String, lines: Int) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 16.5, weight: .semibold))

      ForEach(0..<lines, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(.primary.opacity(0.06))
          .frame(height: 12)
      }
    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
    }
  }
}
