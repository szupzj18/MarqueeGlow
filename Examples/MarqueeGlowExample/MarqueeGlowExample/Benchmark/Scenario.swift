import SwiftUI

/// Scripted scenes for frame-rate measurements. `-scenario <name> -measure <seconds>` starts one; the result is
/// written to the app's `Documents/perf_<name>.json` (see `Scripts/measure.sh`).
enum Scenario: String {
    case none
    /// The list scrolls up and down, no glow. Baseline.
    case scrollOnly = "scrollonly"
    /// Screen-edge glow from this package while the list scrolls.
    case glowScroll = "glow-scroll"
    /// Input-bar glow from this package while the list scrolls.
    case inputScroll = "input-scroll"
    /// The first, naive implementation (`LegacyMarquee`) while the list scrolls.
    case legacyScroll = "legacy-scroll"

    static func fromArguments() -> Scenario {
        UserDefaults.standard.string(forKey: "scenario").flatMap(Scenario.init(rawValue:)) ?? .none
    }

    @MainActor
    func start(edgeGlow: Binding<Bool>, generating: Binding<Bool>) {
        guard self != .none else { return }
        edgeGlow.wrappedValue = self == .glowScroll
        generating.wrappedValue = self == .inputScroll
        FrameMeter.shared.startIfRequested(scenario: rawValue)
        ScrollDriver.shared.start()
    }
}
