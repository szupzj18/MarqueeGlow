import SwiftUI

/// The first version of the effect, kept only to measure against. Every frame it rebuilds the gradient at a new
/// angle and blurs two full-screen strokes, which drops an iPhone simulator to about 20 fps.
/// Don't copy this; use `.marqueeGlow`.
struct LegacyMarquee: View {
    let colors: [Color]
    var cornerRadius: CGFloat = 55
    var lineWidth: CGFloat = 3
    var period: Double = 3

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = Angle.degrees((t / period).truncatingRemainder(dividingBy: 1) * 360)
            let gradient = AngularGradient(colors: colors, center: .center, angle: angle)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                shape.strokeBorder(gradient, lineWidth: lineWidth * 10).blur(radius: 28).opacity(0.55)
                shape.strokeBorder(gradient, lineWidth: lineWidth * 4).blur(radius: 10).opacity(0.8)
                shape.strokeBorder(gradient, lineWidth: lineWidth)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
