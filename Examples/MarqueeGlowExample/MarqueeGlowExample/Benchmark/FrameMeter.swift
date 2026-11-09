import QuartzCore
import UIKit

/// Records frame timestamps with a `CADisplayLink`. With `-measure <seconds>` it waits 2 seconds for the scene to
/// settle, records, and writes `Documents/perf_<scenario>.json`.
///
/// A hitch is a frame whose interval is more than 1.5× the interval the system asked for
/// (`targetTimestamp - timestamp`); hitch time is the sum of the overruns. That judges 60 Hz and 120 Hz screens
/// at their own pace.
@MainActor
final class FrameMeter: NSObject {
    static let shared = FrameMeter()

    private var link: CADisplayLink?
    private var stamps: [CFTimeInterval] = []
    private var expected: [CFTimeInterval] = []
    private var recording = false

    func startIfRequested(scenario: String) {
        let seconds = UserDefaults.standard.double(forKey: "measure")
        guard seconds > 0, link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
        Task {
            try? await Task.sleep(for: .seconds(2))
            stamps.removeAll()
            expected.removeAll()
            recording = true
            try? await Task.sleep(for: .seconds(seconds))
            recording = false
            finish(scenario: scenario)
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard recording else { return }
        stamps.append(link.timestamp)
        expected.append(link.targetTimestamp - link.timestamp)
    }

    private func finish(scenario: String) {
        link?.invalidate()
        link = nil
        guard stamps.count > 2, let first = stamps.first, let last = stamps.last else { return }
        let deltas = zip(stamps.dropFirst(), stamps).map { $0 - $1 }
        let span = last - first
        let screen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen
        let hitches = zip(deltas, expected).filter { $0.0 > $0.1 * 1.5 }
        let hitchTime = hitches.reduce(0) { $0 + ($1.0 - $1.1) }
        let sorted = deltas.sorted()
        func ms(_ seconds: Double) -> Double { (seconds * 100_000).rounded() / 100 }
        func percentile(_ p: Double) -> Double { ms(sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]) }
        let result: [String: Any] = [
            "scenario": scenario,
            "seconds": (span * 100).rounded() / 100,
            "frames": deltas.count,
            "fps": (Double(deltas.count) / span * 10).rounded() / 10,
            "screenMaxFPS": screen?.maximumFramesPerSecond ?? 60,
            "hitches": hitches.count,
            "hitchMsPerSec": (hitchTime * 1000 / span * 10).rounded() / 10,
            "p50ms": percentile(0.5),
            "p95ms": percentile(0.95),
            "p99ms": percentile(0.99),
            "maxms": ms(sorted.last ?? 0),
            "frameMs": deltas.map(ms),
        ]
        let url = URL.documentsDirectory.appending(path: "perf_\(scenario).json")
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }
}
