import SwiftUI

extension View {
    /// Draws a band of color that travels around the view's rounded edge, with a soft halo and a highlight that
    /// brightens the edge as the band passes.
    ///
    /// ```swift
    /// TextField("Ask anything", text: $text)
    ///     .padding()
    ///     .background(.thinMaterial, in: .rect(cornerRadius: 20))
    ///     .marqueeGlow(isActive: isGenerating, colors: .nebula, cornerRadius: 20)
    /// ```
    ///
    /// The glow fades in and out when `isActive` changes. With Reduce Motion on it stays still: the same band and
    /// halo, no rotation and no moving highlight. It never takes touches and is hidden from accessibility.
    ///
    /// With `.outside` placement the halo extends past the view's bounds by about 12 × `lineWidth`; an ancestor
    /// that clips (a `ScrollView`, `.clipped()`) cuts it off, so leave room or apply the modifier outside the clip.
    ///
    /// - Parameters:
    ///   - isActive: Whether the glow is shown.
    ///   - colors: The colors that travel around the edge. Defaults to ``MarqueeGlowColors/nebula``.
    ///   - lineWidth: Width of the sharp band in points; the halo scales with it.
    ///   - cornerRadius: Corner radius of the edge, matching the view's own shape. `.infinity` gives a capsule.
    ///   - placement: Halo outside the view (controls) or inside it (a screen or container edge).
    ///   - period: Seconds for one full turn.
    public func marqueeGlow(
        isActive: Bool = true,
        colors: MarqueeGlowColors = .nebula,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 16,
        placement: MarqueeGlowPlacement = .outside,
        period: Double = 3
    ) -> some View {
        modifier(MarqueeGlowModifier(
            isActive: isActive, colors: colors, lineWidth: lineWidth,
            cornerRadius: cornerRadius, placement: placement, period: period
        ))
    }
}

struct MarqueeGlowModifier: ViewModifier {
    var isActive: Bool
    var colors: MarqueeGlowColors
    var lineWidth: CGFloat
    var cornerRadius: CGFloat
    var placement: MarqueeGlowPlacement
    var period: Double

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if isActive {
                    GeometryReader { proxy in
                        let geometry = GlowGeometry(
                            size: proxy.size, lineWidth: lineWidth,
                            cornerRadius: cornerRadius, placement: placement
                        )
                        GlowLayer(
                            geometry: geometry,
                            colors: colors.gradientColors(for: colorScheme),
                            highlightOpacity: colorScheme == .dark ? 0.45 : 0.85,
                            period: period
                        )
                        // A new layer, and a fresh animation, when the motion or the speed changes.
                        .id(LayerIdentity(motion: GlowMotion(reduceMotion: reduceMotion), period: period))
                        .environment(\.glowMotion, GlowMotion(reduceMotion: reduceMotion))
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: isActive)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct LayerIdentity: Hashable {
    var motion: GlowMotion
    var period: Double
}

extension EnvironmentValues {
    @Entry var glowMotion: GlowMotion = .spinning
}

/// The drawn glow, sized to the canvas (the view plus the halo outset).
struct GlowLayer: View {
    var geometry: GlowGeometry
    var colors: [Color]
    var highlightOpacity: Double
    var period: Double

    @Environment(\.displayScale) private var displayScale
    @Environment(\.glowMotion) private var motion
    @State private var glowMask: Image?
    @State private var edgeMask: Image?
    @State private var turned = false

    private static let highlightStops: [Gradient.Stop] = [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: 0.42),
        .init(color: .white, location: 0.5),
        .init(color: .clear, location: 0.58),
        .init(color: .clear, location: 1),
    ]

    var body: some View {
        let canvas = geometry.canvasSize
        ZStack {
            rotating(AngularGradient(colors: colors, center: .center))
                .mask { glowMask?.resizable() }
            if motion == .spinning {
                rotating(AngularGradient(stops: Self.highlightStops, center: .center))
                    .mask { edgeMask?.resizable() }
                    .opacity(highlightOpacity)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .onChange(of: MaskRequest(geometry: geometry, scale: displayScale), initial: true) { _, request in
            glowMask = Self.image(GlowMask.image(for: request.geometry, kind: .glow, scale: request.scale), request.scale)
            edgeMask = Self.image(GlowMask.image(for: request.geometry, kind: .edge, scale: request.scale), request.scale)
        }
        .onAppear {
            guard motion == .spinning, period > 0 else { return }
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                turned = true
            }
        }
        .onDisappear {
            // A view that keeps its state (a lazy row scrolled back, a tab switched back) appears again with `turned`
            // still true, and setting it to true again would not restart a rotation the system dropped meanwhile.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { turned = false }
        }
    }

    /// A square gradient larger than the canvas, turned by Core Animation's repeating rotation. Both gradients use
    /// the same state and animation, so the highlight stays locked to the band.
    private func rotating(_ gradient: AngularGradient) -> some View {
        let side = geometry.gradientSide
        return gradient
            .frame(width: side, height: side)
            .rotationEffect(.degrees(turned ? 360 : 0))
            .frame(width: geometry.canvasSize.width, height: geometry.canvasSize.height)
    }

    private static func image(_ cgImage: CGImage?, _ scale: CGFloat) -> Image? {
        cgImage.map { Image(decorative: $0, scale: scale) }
    }

    private struct MaskRequest: Equatable {
        var geometry: GlowGeometry
        var scale: CGFloat
    }
}
