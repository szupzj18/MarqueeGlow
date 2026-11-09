import SwiftUI

/// Where the halo spreads relative to the view's edge.
public enum MarqueeGlowPlacement: Hashable, Sendable {
    /// Around a control such as a text field or a card: the band sits on the edge and the halo spreads outward,
    /// leaving the view's content untouched.
    case outside
    /// Along the inner edge of a container such as the whole screen: the band and halo stay inside the bounds.
    case inside
}

/// Whether the band moves. Reduce Motion turns it into a still glow.
enum GlowMotion: Equatable, Sendable {
    case spinning
    case still

    init(reduceMotion: Bool) {
        self = reduceMotion ? .still : .spinning
    }
}

/// Sizes of the glow layers for one view size. Everything is derived from the line width so a thin band gets a
/// tight halo and a thick one a wide halo.
struct GlowGeometry: Hashable, Sendable {
    var size: CGSize
    var lineWidth: CGFloat
    var cornerRadius: CGFloat
    var placement: MarqueeGlowPlacement

    /// How far the drawing extends past the view's bounds on each side.
    var outset: CGFloat {
        placement == .outside ? lineWidth * 12 : 0
    }

    /// Size of the mask image and of the layer that draws the glow.
    var canvasSize: CGSize {
        CGSize(width: size.width + outset * 2, height: size.height + outset * 2)
    }

    /// The corner radius actually drawn: at most half the shorter side, so `.infinity` gives a capsule.
    var resolvedCornerRadius: CGFloat {
        max(0, min(cornerRadius, min(size.width, size.height) / 2))
    }

    /// Side of the square gradient that rotates behind the mask. It covers the canvas's diagonal so no corner of
    /// the canvas is ever left uncovered while it turns.
    var gradientSide: CGFloat {
        (canvasSize.width * canvasSize.width + canvasSize.height * canvasSize.height).squareRoot()
    }

    /// The soft outer halo. Inside a container it is wider, matching a screen-edge glow.
    var wideHalo: Halo {
        placement == .outside
            ? Halo(width: lineWidth * 6, blur: lineWidth * 4, opacity: 0.55)
            : Halo(width: lineWidth * 10, blur: lineWidth * 9, opacity: 0.55)
    }

    /// The brighter halo close to the band.
    var narrowHalo: Halo {
        placement == .outside
            ? Halo(width: lineWidth * 2.5, blur: lineWidth * 1.5, opacity: 0.8)
            : Halo(width: lineWidth * 4, blur: lineWidth * 3.3, opacity: 0.8)
    }

    struct Halo: Hashable, Sendable {
        var width: CGFloat
        var blur: CGFloat
        var opacity: Double
    }

    var isDrawable: Bool {
        size.width > 0 && size.height > 0 && lineWidth > 0 && size.width.isFinite && size.height.isFinite
    }
}
