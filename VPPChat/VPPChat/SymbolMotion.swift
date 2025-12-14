import SwiftUI

enum SymbolMotion {
  /// One-shot (battery-safe) symbol motion; state-driven; respects Reduce Motion.
    static func oneShot<E: SymbolEffect & DiscreteSymbolEffect, T: Hashable>(
    _ effect: E,
    trigger: T,
    reduceMotion: Bool
  ) -> some ViewModifier {
    OneShotSymbolEffect(effect: effect, trigger: trigger, reduceMotion: reduceMotion)
  }

  /// Use for symbol-to-symbol swaps (e.g., paperplane -> checkmark).
  static func magicReplace(reduceMotion: Bool) -> AnyTransition {
    // Keep it simple; avoid extra motion when reduced.
    .opacity
  }

    private struct OneShotSymbolEffect<E: SymbolEffect & DiscreteSymbolEffect, T: Hashable>: ViewModifier {
    let effect: E
    let trigger: T
    let reduceMotion: Bool

    func body(content: Content) -> some View {
      if reduceMotion {
        content
      } else {
        content.symbolEffect(effect, options: .nonRepeating, value: trigger)
      }
    }
  }
}

extension View {
  /// Content transition for SF Symbols (safe baseline; uses Replace).
  @ViewBuilder
  func symbolSwap(reduceMotion: Bool) -> some View {
    if reduceMotion {
      self
    } else {
      self.contentTransition(.symbolEffect(.replace))
    }
  }
}
