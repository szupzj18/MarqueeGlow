import CoreGraphics
import SwiftUI
import Testing
@testable import MarqueeGlow

@Suite struct ColorsTests {
    @Test func presetsHaveFourColorsInBothModes() {
        #expect(MarqueeGlowColors.presets.map(\.name) == ["Nebula", "Ember", "Lagoon", "Dusk"])
        for preset in MarqueeGlowColors.presets {
            #expect(preset.colors.light.count == 4, "\(preset.name) light")
            #expect(preset.colors.dark.count == 4, "\(preset.name) dark")
            #expect(preset.colors.light != preset.colors.dark, "\(preset.name) should differ between modes")
        }
    }

    @Test func gradientClosesTheLoop() {
        let colors: MarqueeGlowColors = [.red, .green, .blue]
        let resolved = colors.gradientColors(for: .light)
        #expect(resolved == [.red, .green, .blue, .red])
    }

    @Test func picksTheSetForTheColorScheme() {
        let colors = MarqueeGlowColors(light: [.red, .green], dark: [.blue, .yellow])
        #expect(colors.gradientColors(for: .light) == [.red, .green, .red])
        #expect(colors.gradientColors(for: .dark) == [.blue, .yellow, .blue])
    }

    @Test func emptyFallsBackToNebula() {
        let empty = MarqueeGlowColors([])
        #expect(empty.gradientColors(for: .dark) == MarqueeGlowColors.nebula.gradientColors(for: .dark))
    }

    @Test func singleColorBecomesTwoTone() {
        let resolved = MarqueeGlowColors([.red]).gradientColors(for: .light)
        #expect(resolved.count == 3)
        #expect(resolved.first == .red && resolved.last == .red)
        #expect(resolved[1] != .red)
    }
}

@Suite struct GeometryTests {
    @Test func outsideExtendsPastTheBounds() {
        let g = GlowGeometry(size: CGSize(width: 300, height: 50), lineWidth: 2, cornerRadius: 20, placement: .outside)
        #expect(g.outset == 24)
        #expect(g.canvasSize == CGSize(width: 348, height: 98))
    }

    @Test func insideStaysInTheBounds() {
        let g = GlowGeometry(size: CGSize(width: 390, height: 844), lineWidth: 3, cornerRadius: 55, placement: .inside)
        #expect(g.outset == 0)
        #expect(g.canvasSize == g.size)
    }

    @Test func cornerRadiusIsClampedToACapsule() {
        let g = GlowGeometry(size: CGSize(width: 300, height: 50), lineWidth: 2, cornerRadius: .infinity, placement: .outside)
        #expect(g.resolvedCornerRadius == 25)
        let negative = GlowGeometry(size: CGSize(width: 300, height: 50), lineWidth: 2, cornerRadius: -4, placement: .outside)
        #expect(negative.resolvedCornerRadius == 0)
    }

    @Test func rotatingGradientCoversTheCanvasAtEveryAngle() {
        let g = GlowGeometry(size: CGSize(width: 300, height: 50), lineWidth: 2, cornerRadius: 20, placement: .outside)
        let half = g.gradientSide / 2
        let corner = (pow(g.canvasSize.width / 2, 2) + pow(g.canvasSize.height / 2, 2)).squareRoot()
        #expect(half >= corner - 0.001)
    }

    @Test func emptyOrInvalidSizesAreNotDrawn() {
        #expect(!GlowGeometry(size: .zero, lineWidth: 2, cornerRadius: 8, placement: .outside).isDrawable)
        #expect(!GlowGeometry(size: CGSize(width: 10, height: 10), lineWidth: 0, cornerRadius: 8, placement: .outside).isDrawable)
        #expect(!GlowGeometry(size: CGSize(width: CGFloat.infinity, height: 10), lineWidth: 2, cornerRadius: 8, placement: .outside).isDrawable)
    }
}

@Suite struct MotionTests {
    @Test func reduceMotionKeepsTheGlowStill() {
        #expect(GlowMotion(reduceMotion: true) == .still)
        #expect(GlowMotion(reduceMotion: false) == .spinning)
    }
}

/// Renders the real masks and reads their alpha, so a change to the layer stack that empties the glow, lets the
/// halo cover the view's content or pushes it outside the canvas fails here.
@MainActor @Suite struct MaskTests {
    let size = CGSize(width: 200, height: 60)

    @Test func outsideGlowSurroundsTheViewAndLeavesItsContentClear() throws {
        let g = GlowGeometry(size: size, lineWidth: 2, cornerRadius: 16, placement: .outside)
        let mask = try #require(GlowMask.image(for: g, kind: .glow, scale: 2))
        #expect(mask.width == Int(g.canvasSize.width * 2))
        #expect(mask.height == Int(g.canvasSize.height * 2))
        let o = g.outset
        #expect(alpha(mask, x: o + 100, y: o + 30, scale: 2) < 0.02, "content area must stay clear")
        #expect(alpha(mask, x: o + 100, y: o, scale: 2) > 0.8, "band on the top edge")
        #expect(alpha(mask, x: o + 100, y: o - 6, scale: 2) > 0.1, "halo just outside the top edge")
        #expect(alpha(mask, x: 1, y: 1, scale: 2) < 0.05, "fades out before the canvas corner")
    }

    @Test func insideGlowStaysInsideTheEdge() throws {
        let g = GlowGeometry(size: size, lineWidth: 2, cornerRadius: 16, placement: .inside)
        let mask = try #require(GlowMask.image(for: g, kind: .glow, scale: 2))
        #expect(alpha(mask, x: 100, y: 0.5, scale: 2) > 0.8, "band on the inner top edge")
        #expect(alpha(mask, x: 100, y: 8, scale: 2) > 0.1, "halo inside the edge")
    }

    @Test func edgeMaskIsOnlyTheBand() throws {
        let g = GlowGeometry(size: size, lineWidth: 2, cornerRadius: 16, placement: .outside)
        let mask = try #require(GlowMask.image(for: g, kind: .edge, scale: 2))
        let o = g.outset
        #expect(alpha(mask, x: o + 100, y: o, scale: 2) > 0.8)
        #expect(alpha(mask, x: o + 100, y: o - 6, scale: 2) < 0.02, "no halo in the edge mask")
    }

    @Test func masksAreCachedPerSizeAndScale() throws {
        let g = GlowGeometry(size: CGSize(width: 123, height: 45), lineWidth: 2, cornerRadius: 10, placement: .outside)
        let first = try #require(GlowMask.image(for: g, kind: .glow, scale: 2))
        let second = try #require(GlowMask.image(for: g, kind: .glow, scale: 2))
        #expect(first === second)
        let other = try #require(GlowMask.image(for: g, kind: .glow, scale: 3))
        #expect(other !== first)
    }

    @Test func undrawableGeometryGivesNoMask() {
        let g = GlowGeometry(size: .zero, lineWidth: 2, cornerRadius: 10, placement: .outside)
        #expect(GlowMask.image(for: g, kind: .glow, scale: 2) == nil)
    }

    /// Alpha (0...1) at a point given in canvas points.
    private func alpha(_ image: CGImage, x: CGFloat, y: CGFloat, scale: CGFloat) -> Double {
        let px = min(image.width - 1, max(0, Int(x * scale)))
        let py = min(image.height - 1, max(0, Int(y * scale)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let space = CGColorSpaceCreateDeviceRGB()
        pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            // CGContext's origin is bottom-left; shift so the wanted pixel lands on (0, 0).
            context.translateBy(x: CGFloat(-px), y: CGFloat(py - image.height + 1))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return Double(pixel[3]) / 255
    }
}
