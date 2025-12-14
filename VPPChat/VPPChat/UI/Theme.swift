//
//  Theme.swift
//  VPPChat
//
//  Created by Sebastian Suarez-Solis on 12/9/25.
//

import SwiftUI
import Combine
import MetalKit
import simd
import AppKit

// MARK: - Accent Palette & Theme Manager

enum AccentPalette: String, CaseIterable {
    case ocean
    case forest
    case ember
    case graphite

    // Default palette
    static var current: AccentPalette = .graphite

    // SwiftUI colors for UI
    var structural: Color {
        switch self {
        case .ocean:
            return Color(red: 0.00, green: 0.39, blue: 0.78)
        case .forest:
            return Color(red: 0.11, green: 0.55, blue: 0.38)
        case .ember:
            return Color(red: 0.74, green: 0.29, blue: 0.21)
        case .graphite:
            return Color(red: 0.18, green: 0.20, blue: 0.26)
        }
    }

    var exception: Color {
        switch self {
        case .ocean:
            return Color(red: 0.92, green: 0.31, blue: 0.39)
        case .forest:
            return Color(red: 0.84, green: 0.30, blue: 0.28)
        case .ember:
            return Color(red: 0.16, green: 0.30, blue: 0.60)
        case .graphite:
            return Color(red: 0.75, green: 0.34, blue: 0.38)
        }
    }

    // Raw RGB triplets for the shader uniforms
    var structuralRGB: SIMD3<Float> {
        switch self {
        case .ocean:
            return SIMD3(0.00, 0.39, 0.78)
        case .forest:
            return SIMD3(0.11, 0.55, 0.38)
        case .ember:
            return SIMD3(0.74, 0.29, 0.21)
        case .graphite:
            return SIMD3(0.18, 0.20, 0.26)
        }
    }

    var exceptionRGB: SIMD3<Float> {
        switch self {
        case .ocean:
            return SIMD3(0.92, 0.31, 0.39)
        case .forest:
            return SIMD3(0.84, 0.30, 0.28)
        case .ember:
            return SIMD3(0.16, 0.30, 0.60)
        case .graphite:
            return SIMD3(0.75, 0.34, 0.38)
        }
    }
}

// Global theme manager you can inject at the app root.
final class ThemeManager: ObservableObject {
    @Published var palette: AccentPalette {
        didSet {
            AccentPalette.current = palette
            UserDefaults.standard.set(palette.rawValue, forKey: "AccentPalette.current")
        }
    }

    /// Background "activity" 0 = idle, 1 = intense thinking.
    /// Animate this from view models when the visible context is "thinking".
    @Published var activity: CGFloat = 0.25

    init() {
        if let saved = UserDefaults.standard.string(forKey: "AccentPalette.current"),
           let p = AccentPalette(rawValue: saved) {
            self.palette = p
        } else {
            self.palette = .graphite
        }
        AccentPalette.current = palette
    }

    var structuralAccent: Color { palette.structural }
    var exceptionAccent: Color { palette.exception }
}

// MARK: - AppTheme tokens (light aerogel)

enum AppTheme {
    enum Colors {
        // Backgrounds — aerogel / light glass
        //
        // Let the MTKView noise actually be the window background,
        // then layer translucent surfaces on top.
        static let window   = Color.white.opacity(0.50)
        static let surface0 = Color.white.opacity(0.32)
        static let surface1 = Color.white.opacity(0.68)
        static let surface2 = Color.white.opacity(0.92)


        // Accent families (driven by AccentPalette.current)
        static var structuralAccent: Color {
            AccentPalette.current.structural
        }

        static var structuralAccentSoft: Color {
            structuralAccent.opacity(0.18)
        }

        static var exceptionAccent: Color {
            AccentPalette.current.exception
        }

        static var exceptionAccentSoft: Color {
            exceptionAccent.opacity(0.18)
        }

        // Status
        static let statusCorrect = Color(red: 0.06, green: 0.62, blue: 0.26)
        static let statusMinor   = Color(red: 0.87, green: 0.65, blue: 0.09)
        static let statusMajor   = Color(red: 0.80, green: 0.15, blue: 0.20)

        // Text — dark ink on light glass
        static let textPrimary   = Color(red: 0.08, green: 0.10, blue: 0.16)
        static let textSecondary = Color(red: 0.35, green: 0.38, blue: 0.47)
        static let textSubtle    = Color(red: 0.55, green: 0.59, blue: 0.69)

        static let borderSoft     = Color.black.opacity(0.06)
        static var borderEmphasis: Color {
            structuralAccent.opacity(0.40)
        }
    }

    enum Radii {
        static let card: CGFloat = 16
        static let panel: CGFloat = 24
        static let chip: CGFloat = 999
    }

    enum Spacing {
        static let base: CGFloat = 8
        static let cardInner: CGFloat = 16
        static let outerHorizontal: CGFloat = 24
    }

    enum Motion {
        static let fast: Double = 0.18
        static let medium: Double = 0.25
    }
}

// MARK: - Public background view (shader + veil)
struct NoiseBackground: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            // Base: halftone shader
            ShaderNoiseBackgroundView(
                palette: theme.palette,
                activity: Float(theme.activity)
            )

            // Theme-tinted two-tone gradient veil (per palette)
            LinearGradient(
                colors: [
                    AppTheme.Colors.structuralAccent.opacity(0.20), // top/leading
                    AppTheme.Colors.exceptionAccent.opacity(0.14)   // bottom/trailing
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)
        }
        .ignoresSafeArea()
        .background(AppTheme.Colors.window)  // keep your 0.26 translucency
        .allowsHitTesting(false)
    }
}


// MARK: - Shared uniforms for Swift <-> Metal

/// Must match the layout of `NoiseUniforms` in `NoiseShader.metal`.
struct NoiseUniforms {
    var time: Float
    var activity: Float
    var resolution: SIMD2<Float>
    var structuralColor: SIMD3<Float>
    var exceptionColor: SIMD3<Float>

    var pointerUV: SIMD2<Float>
    var pointerDown: Float
    var pointerPresent: Float

    var rippleCenter: SIMD2<Float>
    var rippleTime: Float
    var rippleActive: Float
}

// MARK: - Metal renderer

final class NoiseRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    private var startTime: CFTimeInterval = CACurrentMediaTime()

    /// Global activity uniform for the shader (0 = idle, 1 = thinking).
    var activity: Float = 0.25

    /// Pointer state (hover & click)
    var pointerUV: SIMD2<Float>      = SIMD2(-1, -1)
    var pointerDown: Float           = 0.0
    var pointerPresent: Float        = 0.0

    /// Ripple state (last click)
    var rippleCenter: SIMD2<Float>   = SIMD2(-1, -1)
    var rippleTime: Float            = -10.0
    var rippleActive: Float          = 0.0

    var palette: AccentPalette

    init?(metalKitView: MTKView, initialPalette: AccentPalette) {
        print("🔥 NoiseRenderer init starting")

        guard let device = metalKitView.device ?? MTLCreateSystemDefaultDevice() else {
            print("❌ NoiseRenderer: no Metal device")
            return nil
        }
        self.device = device
        self.palette = initialPalette

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ NoiseRenderer: could not create command queue")
            return nil
        }
        self.commandQueue = commandQueue

        guard let library = device.makeDefaultLibrary() else {
            print("❌ NoiseRenderer: makeDefaultLibrary() failed")
            return nil
        }

        guard let vertexFunction   = library.makeFunction(name: "vertex_passthrough"),
              let fragmentFunction = library.makeFunction(name: "fragment_noise") else {
            print("❌ NoiseRenderer: could not find shader functions")
            return nil
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction   = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat

        // 🔑 Alpha blending so the shader can be translucent over the desktop
        if let attachment = pipelineDescriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.sourceAlphaBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("✅ NoiseRenderer pipeline created")
        } catch {
            print("❌ NoiseRenderer pipeline error: \(error)")
            return nil
        }

        super.init()
        print("✅ NoiseRenderer init finished")
    }

    // Required by MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Noise is resolution-independent; nothing needed here.
    }

    /// Trigger a new ripple at the given UV point (0..1).
    func triggerRipple(at uv: SIMD2<Float>) {
        let now = CACurrentMediaTime()
        let t   = Float(now - startTime)
        rippleCenter = uv
        rippleTime   = t
        rippleActive = 1.0
    }

    func draw(in view: MTKView) {
        guard let drawable   = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else {
            return
        }

        let now = CACurrentMediaTime()
        let t   = Float(now - startTime)

        // Auto-disable ripple after a couple seconds to keep uniforms sane
        if rippleActive > 0.5, (t - rippleTime) > 2.0 {
            rippleActive = 0.0
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder       = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)

        // Full-screen quad (NDC space)
        let vertices: [Float] = [
            -1, -1, 0, 1,
             1, -1, 0, 1,
            -1,  1, 0, 1,
             1,  1, 0, 1
        ]

        encoder.setVertexBytes(
            vertices,
            length: MemoryLayout<Float>.size * vertices.count,
            index: 0
        )

        let size = view.drawableSize
        var uniforms = NoiseUniforms(
            time: t,
            activity: activity,
            resolution: SIMD2(Float(size.width), Float(size.height)),
            structuralColor: palette.structuralRGB,
            exceptionColor: palette.exceptionRGB,
            pointerUV: pointerUV,
            pointerDown: pointerDown,
            pointerPresent: pointerPresent,
            rippleCenter: rippleCenter,
            rippleTime: rippleTime,
            rippleActive: rippleActive
        )

        encoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<NoiseUniforms>.stride,
            index: 0
        )

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Interactive MTKView (hover + click → uniforms)

final class InteractiveMTKView: MTKView {
    weak var noiseRenderer: NoiseRenderer?

    private var trackingArea: NSTrackingArea?

    // 🔑 Make the view itself non-opaque so the window can be translucent
    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeInKeyWindow,
            .inVisibleRect
        ]

        let area = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )

        addTrackingArea(area)
        trackingArea = area
    }

    private func updatePointer(with event: NSEvent,
                               isDown: Bool,
                               triggerRipple: Bool = false) {
        guard let renderer = noiseRenderer,
              bounds.width > 0,
              bounds.height > 0 else { return }

        let location = convert(event.locationInWindow, from: nil)

        let u = Float(min(max(location.x / bounds.width, 0), 1))
        let v = Float(min(max(1.0 - (location.y / bounds.height), 0), 1))

        renderer.pointerUV      = SIMD2<Float>(u, v)
        renderer.pointerPresent = 1.0

        if isDown {
            renderer.pointerDown = 1.0
        }

        if triggerRipple {
            renderer.triggerRipple(at: SIMD2<Float>(u, v))
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        window?.acceptsMouseMovedEvents = true
        noiseRenderer?.pointerPresent = 1.0
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        noiseRenderer?.pointerPresent = 0.0
        noiseRenderer?.pointerDown    = 0.0
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updatePointer(with: event, isDown: false)
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        updatePointer(with: event, isDown: true)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
        updatePointer(with: event, isDown: true, triggerRipple: true)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        noiseRenderer?.pointerDown = 0.0
    }
}

// MARK: - SwiftUI bridge

struct ShaderNoiseBackgroundView: NSViewRepresentable {
    var palette: AccentPalette
    var activity: Float

    final class Coordinator {
        var renderer: NoiseRenderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtkView = InteractiveMTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm

        // 🔑 Transparent Metal layer over the desktop
        mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        mtkView.framebufferOnly = false
        if let layer = mtkView.layer {
            layer.isOpaque = false
            layer.backgroundColor = NSColor.clear.cgColor
        }

        // continuous rendering
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        if let renderer = NoiseRenderer(metalKitView: mtkView, initialPalette: palette) {
            renderer.activity = activity
            mtkView.delegate = renderer
            (mtkView as? InteractiveMTKView)?.noiseRenderer = renderer
            context.coordinator.renderer = renderer   // keep strong ref
            print("✅ ShaderNoiseBackgroundView: renderer attached")
        } else {
            print("❌ ShaderNoiseBackgroundView: renderer failed to init")
        }

        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.activity = activity
        renderer.palette  = palette
    }
}

// MARK: - Accent palette drawer (canonical palette selector)

struct AccentPaletteDrawer: View {
    @EnvironmentObject var theme: ThemeManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.base) {
            Text("Accent")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.bottom, AppTheme.Spacing.base)

            ForEach(AccentPalette.allCases, id: \.self) { palette in
                AccentPaletteRow(palette: palette) {
                    theme.palette = palette
                    isPresented = false
                }
            }
        }
        .padding(AppTheme.Spacing.cardInner)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                .fill(AppTheme.Colors.surface0)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.panel, style: .continuous)
                        .stroke(AppTheme.Colors.borderSoft, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 12)
    }
}

struct AccentPaletteRow: View {
    let palette: AccentPalette
    let action: () -> Void

    @EnvironmentObject var theme: ThemeManager

    private var isSelected: Bool {
        theme.palette == palette
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.base) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.structural.opacity(0.80))
                        .frame(width: 34, height: 20)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.exception.opacity(0.80))
                        .frame(width: 20, height: 12)
                        .offset(x: 10, y: 5)
                }

                Text(palette.rawValue.capitalized)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.small)
                        .foregroundColor(AppTheme.Colors.structuralAccent)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? AppTheme.Colors.structuralAccentSoft : Color.clear)
        )
    }
}
