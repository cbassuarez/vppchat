//
//  WindowResizeAnchor.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


#if os(macOS)
import SwiftUI
import AppKit

enum WindowResizeAnchor {
  case trailing
}

private struct WindowResizeAnchorCompatView: NSViewRepresentable {
  let anchor: WindowResizeAnchor

  func makeCoordinator() -> Coordinator { Coordinator(anchor: anchor) }
  func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.anchor = anchor
    DispatchQueue.main.async {
      context.coordinator.attachIfNeeded(to: nsView.window)
    }
  }

  final class Coordinator: NSObject {
    var anchor: WindowResizeAnchor
    weak var window: NSWindow?
    var lastFrame: NSRect = .zero
    var isAdjusting = false

    init(anchor: WindowResizeAnchor) {
      self.anchor = anchor
      super.init()
    }

    func attachIfNeeded(to newWindow: NSWindow?) {
      guard let newWindow else { return }
      if window !== newWindow {
        if let window {
          NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
        }
        window = newWindow
        lastFrame = newWindow.frame
        NotificationCenter.default.addObserver(self, selector: #selector(onResize(_:)), name: NSWindow.didResizeNotification, object: newWindow)
      }
    }

    @objc private func onResize(_ note: Notification) {
      guard let window, !isAdjusting else { return }
      let newFrame = window.frame
      defer { lastFrame = window.frame }

      let deltaW = newFrame.width - lastFrame.width
      guard abs(deltaW) > 0.5 else { return }

      switch anchor {
      case .trailing:
        // Keep trailing edge fixed: shift origin left when width grows, right when it shrinks.
        isAdjusting = true
        window.setFrameOrigin(NSPoint(x: newFrame.origin.x - deltaW, y: newFrame.origin.y))
        isAdjusting = false
      }
    }

    deinit {
      if let window {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: window)
      }
    }
  }
}

extension View {
  /// macOS 15-compatible trailing resize anchor (horizontal only).
  func windowResizeAnchorCompat(_ anchor: WindowResizeAnchor) -> some View {
    background(WindowResizeAnchorCompatView(anchor: anchor).frame(width: 0, height: 0))
  }
}
#endif
