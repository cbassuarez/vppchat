//
//  SendButton.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/14/25.
//


import SwiftUI

enum SendPhase: Equatable {
    case idleDisabled
    case idleReady
    case sending
    case receiving
    case error
}

struct SendButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressToken: Int = 0      // triggers bounce
    @State private var errorToken: Int = 0      // triggers error pulse
    @State private var isHovering: Bool = false
    @State private var inkProgress: CGFloat = 0 // 0 = no ink, 1 = fully inked
    let phase: SendPhase
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard phase == .idleReady, isEnabled else { return }
            withAnimation(reduceMotion ? .default : AppTheme.Motion.sendTap) {
                pressToken &+= 1
            }
            action()
        } label: {
            ZStack {
                backgroundPill
                contentLayer
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || phase == .sending || phase == .receiving)
        .onHover { hovering in
            withAnimation(reduceMotion ? .none : .easeOut(duration: AppTheme.Motion.fast)) {
                isHovering = hovering
            }
        }
        .animation(AppTheme.Motion.sendPhase, value: phase)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: phase) { newPhase in
            guard !reduceMotion else { return }

            // Ink in/out based on phase
            if newPhase == .sending || newPhase == .receiving {
                withAnimation(.easeOut(duration: 0.45)) {
                    inkProgress = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    inkProgress = 0.0
                }
            }

            // Error pulse still works as before
            if newPhase == .error {
                errorToken &+= 1
            }
        }

    }

    // MARK: - Layers
    private func animateInk(for newPhase: SendPhase) {
        switch newPhase {
        case .idleReady:
            // Button just became “active” → ink spreads out
            inkProgress = 0
            withAnimation(AppTheme.Motion.sendInkIn) {
                inkProgress = 1
            }

        case .idleDisabled:
            // Button disabled → ink retracts / fades
            withAnimation(AppTheme.Motion.sendInkOut) {
                inkProgress = 0
            }

        default:
            break
        }
    }

    private var backgroundPill: some View {
        let baseRadius: CGFloat = 18

        let baseFill: Color = {
            switch phase {
            case .idleDisabled:
                return AppTheme.Colors.surface1
            case .idleReady:
                return AppTheme.Colors.structuralAccent
            case .sending, .receiving:
                return AppTheme.Colors.structuralAccent.opacity(0.95)
            case .error:
                return AppTheme.Colors.exceptionAccent
            }
        }()

        let hoverBoost: Double = isHovering ? 0.06 : 0.0

        return RoundedRectangle(cornerRadius: baseRadius, style: .continuous)
            .fill(baseFill.opacity(0.95 + hoverBoost))
            .overlay(
                RoundedRectangle(cornerRadius: baseRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.0)
            )
            .overlay(inkOverlay)
            .overlay(FlightSweepOverlay(isActive: (phase == .sending || phase == .receiving) && !reduceMotion)
                 .clipShape(Capsule())
             )

            .shadow(
                color: shadowColor,
                radius: phase == .idleReady && isHovering ? 10 : 8,
                x: 0,
                y: 6
            )
    }
    
    private var showsInk: Bool {
        switch phase {
        case .idleDisabled, .idleReady:
            return true
        default:
            return false
        }
    }

    private var inkOverlay: some View {
        GeometryReader { geo in
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * inkProgress
                    )
                )
                .opacity(showsInk ? 1.0 : 0.0)   // 👈 visibility, not the progress
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    private var contentLayer: some View {
        HStack(spacing: 8) {
            iconLayer
            .frame(width: 16, height: 16)

            Text(labelText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(textOpacity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(foregroundColor)
        .scaleEffect(isHovering && isInteractivePhase ? 1.03 : 1.0)
    }

    private var iconLayer: some View {
        let isInFlight = (phase == .sending || phase == .receiving)
         return ZStack {
             Image(systemName: "paperplane.fill")
                 .opacity(isInFlight ? 0.0 : 1.0)
                 .scaleEffect(isInFlight ? 0.86 : 1.0)
             Image(systemName: "ellipsis.bubble.fill")
                 .opacity(isInFlight ? 1.0 : 0.0)
                 .scaleEffect(isInFlight ? 1.0 : 0.86)
         }

            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .opacity(phase == .idleDisabled ? 0.55 : 1.0)
            // Discrete tap bounce
            .modifier(BounceEffectModifier(trigger: pressToken, enabled: !reduceMotion))
            // Indefinite "thinking" effect while streaming
            .modifier(ThinkingEffectModifier(
                isActive: (phase == .sending || phase == .receiving) && !reduceMotion
            ))
            // Error pulse
            .modifier(ErrorEffectModifier(trigger: errorToken, enabled: !reduceMotion))
    }

    /// Simple circular stroke shown only while sending/streaming.
    private var progressRingLayer: some View {
        Group {
            if phase == .sending || phase == .receiving {
                Circle()
                    .strokeBorder(
                        AppTheme.Colors.window.opacity(0.8),
                        lineWidth: 1.2
                    )
                    .overlay(
                        ArcProgressShape(progress: phase == .sending ? 0.35 : 0.9)
                            .stroke(
                                AppTheme.Colors.structuralAccent.opacity(0.9),
                                style: StrokeStyle(lineWidth: 1.7, lineCap: .round)
                            )
                    )
                    .rotationEffect(.degrees(phase == .sending ? 0 : 180))
                    .animation(
                        .linear(duration: 0.9)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
            }
        }
    }

    // MARK: - Derived UI state

    private var borderColor: Color {
        switch phase {
        case .idleDisabled:
            return AppTheme.Colors.borderSoft
        case .idleReady:
            return AppTheme.Colors.borderEmphasis.opacity(isHovering ? 1.0 : 0.7)
        case .sending, .receiving:
            return AppTheme.Colors.borderEmphasis
        case .error:
            return AppTheme.Colors.exceptionAccent.opacity(0.9)
        }
    }

    private var shadowColor: Color {
        switch phase {
        case .error:
            return AppTheme.Colors.exceptionAccent.opacity(0.45)
        case .sending, .receiving:
            return AppTheme.Colors.structuralAccent.opacity(0.35)
        case .idleReady:
            return AppTheme.Colors.structuralAccent.opacity(0.28)
        case .idleDisabled:
            return Color.black.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch phase {
        case .idleDisabled:
            return AppTheme.Colors.textSecondary.opacity(0.9)
        case .idleReady, .sending, .receiving:
            return Color.white
        case .error:
            return Color.white
        }
    }

    private var labelText: String {
        switch phase {
        case .idleDisabled, .idleReady:
            return "Send"
        case .sending:
            return "Sending…"
        case .receiving:
            return "Streaming…"
        case .error:
            return "Retry"
        }
    }

    private var textOpacity: Double {
        switch phase {
        case .idleDisabled:
            return 0.7
        default:
            return 1.0
        }
    }

    private var isInteractivePhase: Bool {
        phase == .idleReady
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idleDisabled:
            return "Send (disabled)"
        case .idleReady:
            return "Send message"
        case .sending:
            return "Sending message"
        case .receiving:
            return "Receiving response"
        case .error:
            return "Retry sending message"
        }
    }
}

// MARK: - Supporting modifiers & shapes

/// Triggers a discrete bounce on value change (tap).
private struct BounceEffectModifier: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.symbolEffect(.bounce, value: trigger)
        } else {
            content
        }
    }
}

/// Indefinite "thinking" effect while streaming (pulse + subtle scale).
private struct ThinkingEffectModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .symbolEffect(.pulse, isActive: isActive)
            .symbolEffect(.scale.up, isActive: isActive)
    }
}

/// Brief error pulse on failure.
private struct ErrorEffectModifier: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.symbolEffect(.variableColor, value: trigger)
        } else {
            content
        }
    }
}

/// Partial arc for the lightweight progress ring.
private struct ArcProgressShape: Shape {
    var progress: CGFloat // 0...1

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let startAngle: Angle = .degrees(-90)
        let endAngle: Angle = .degrees(-90 + 360 * progress)
        let inset: CGFloat = 0.5
        let r = min(rect.width, rect.height) / 2 - inset
        let center = CGPoint(x: rect.midX, y: rect.midY)

        p.addArc(
            center: center,
            radius: r,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return p
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}
private struct FlightSweepOverlay: View {
    let isActive: Bool
    @State private var x: CGFloat = -0.6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.22),
                            .white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(40, w * 0.28), height: geo.size.height)
                .offset(x: x * w)
                .blendMode(.screen)
                .opacity(isActive ? 1 : 0)
                .onAppear { startIfNeeded() }
                .onChange(of: isActive) { _ in startIfNeeded() }
        }
        .allowsHitTesting(false)
    }

    private func startIfNeeded() {
        guard isActive else {
            x = -0.6
            return
        }
        x = -0.6
        withAnimation(.linear(duration: 1.05).repeatForever(autoreverses: false)) {
            x = 1.6
        }
    }
}
