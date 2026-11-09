import SwiftUI

/// Pre-rendered alpha masks. The blurred halos are drawn once per size into an image; every frame afterwards only
/// rotates a gradient behind that image, so no blur runs while the glow is moving.
@MainActor
enum GlowMask {
    enum Kind: Hashable, Sendable {
        /// Band plus both halos.
        case glow
        /// Only the sharp band, used for the edge highlight.
        case edge
    }

    private struct Key: Hashable {
        var geometry: GlowGeometry
        var kind: Kind
        var scale: CGFloat
    }

    private static var cache: [Key: CGImage] = [:]
    private static var order: [Key] = []
    private static let cacheLimit = 12

    /// A white image whose alpha is the mask, sized `geometry.canvasSize` points at `scale`.
    static func image(for geometry: GlowGeometry, kind: Kind, scale: CGFloat) -> CGImage? {
        guard geometry.isDrawable else { return nil }
        let key = Key(geometry: geometry, kind: kind, scale: scale)
        if let hit = cache[key] { return hit }
        let renderer = ImageRenderer(content: content(for: geometry, kind: kind))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        cache[key] = image
        order.append(key)
        if order.count > cacheLimit {
            cache[order.removeFirst()] = nil
        }
        return image
    }

    @ViewBuilder
    static func content(for g: GlowGeometry, kind: Kind) -> some View {
        let shape = RoundedRectangle(cornerRadius: g.resolvedCornerRadius, style: .continuous)
        let wide = g.wideHalo
        let narrow = g.narrowHalo
        ZStack {
            switch (kind, g.placement) {
            case (.glow, .outside):
                Group {
                    shape.stroke(.white, lineWidth: wide.width).blur(radius: wide.blur).opacity(wide.opacity)
                    shape.stroke(.white, lineWidth: narrow.width).blur(radius: narrow.blur).opacity(narrow.opacity)
                    shape.fill(.black).blendMode(.destinationOut)
                    shape.stroke(.white, lineWidth: g.lineWidth)
                }
                .frame(width: g.size.width, height: g.size.height)
            case (.glow, .inside):
                Group {
                    shape.strokeBorder(.white, lineWidth: wide.width).blur(radius: wide.blur).opacity(wide.opacity)
                    shape.strokeBorder(.white, lineWidth: narrow.width).blur(radius: narrow.blur).opacity(narrow.opacity)
                    shape.strokeBorder(.white, lineWidth: g.lineWidth)
                }
                .frame(width: g.size.width, height: g.size.height)
            case (.edge, .outside):
                shape.stroke(.white, lineWidth: g.lineWidth)
                    .frame(width: g.size.width, height: g.size.height)
            case (.edge, .inside):
                shape.strokeBorder(.white, lineWidth: g.lineWidth)
                    .frame(width: g.size.width, height: g.size.height)
            }
        }
        .frame(width: g.canvasSize.width, height: g.canvasSize.height)
        .compositingGroup()
    }
}
