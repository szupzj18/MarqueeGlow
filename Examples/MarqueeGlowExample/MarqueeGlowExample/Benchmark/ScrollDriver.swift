import UIKit

/// Scrolls the screen's main `UIScrollView` up and down (one round trip every 2 seconds) by setting its
/// `contentOffset` every frame, standing in for a finger dragging the list.
@MainActor
final class ScrollDriver: NSObject {
    static let shared = ScrollDriver()
    private var link: CADisplayLink?
    private weak var scrollView: UIScrollView?
    private var startTime: CFTimeInterval = 0
    var period: Double = 2

    func start(after delay: Double = 0.5) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow),
                  let scrollView = Self.largestScrollView(in: window) else { return }
            self.scrollView = scrollView
            startTime = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.link = link
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let sv = scrollView else { link.invalidate(); return }
        let inset = sv.adjustedContentInset
        let range = max(0, sv.contentSize.height + inset.top + inset.bottom - sv.bounds.height)
        let phase = (link.timestamp - startTime) / period * 2 * .pi
        sv.contentOffset = CGPoint(x: 0, y: -inset.top + range * (1 - cos(phase)) / 2)
    }

    private static func largestScrollView(in view: UIView) -> UIScrollView? {
        var best: UIScrollView?
        func walk(_ v: UIView) {
            if let sv = v as? UIScrollView, sv.contentSize.height > sv.bounds.height + 1,
               sv.bounds.width * sv.bounds.height > (best.map { $0.bounds.width * $0.bounds.height } ?? 0) {
                best = sv
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return best
    }
}
