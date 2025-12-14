//
//  Motion.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

// Single source of truth for motion timing + feel.
// Luxurious = restrained, consistent, high-damping spring.
enum Motion {
  // Durations
  static let micro: Double = 0.12
  static let short: Double = 0.18
  static let standard: Double = 0.28
  static let hero: Double = 0.42

  // Curves (keep it to two)
  static func luxSpring(duration: Double) -> Animation {
    // High damping = less "bouncy", more "machined".
    .spring(response: duration, dampingFraction: 0.88, blendDuration: 0.12)
  }

  static func softEase(duration: Double) -> Animation {
    .easeInOut(duration: duration)
  }
}

enum MotionTransition {
  // Luxurious "lift + fade" instead of big slides.
  static func liftFade(y: CGFloat = 8) -> AnyTransition {
    .modifier(
      active: LiftFadeModifier(y: y, opacity: 0),
      identity: LiftFadeModifier(y: 0, opacity: 1)
    )
  }

  private struct LiftFadeModifier: ViewModifier {
    let y: CGFloat
    let opacity: CGFloat
    func body(content: Content) -> some View {
      content
        .opacity(opacity)
        .offset(y: y)
    }
  }
}

extension View {
  /// Apply animation only when Reduce Motion is OFF.
  @ViewBuilder
  func motion(_ animation: Animation, value: some Equatable, reduceMotion: Bool) -> some View {
    if reduceMotion {
      self.animation(nil, value: value)
    } else {
      self.animation(animation, value: value)
    }
  }
}
