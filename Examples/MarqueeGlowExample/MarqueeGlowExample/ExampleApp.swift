import MarqueeGlow
import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup { ChatDemoView() }
    }
}

/// A chat screen: send a message and the input bar glows while the reply is "generating".
///
/// Launch arguments, used for recordings and frame-rate measurements:
/// - `-generating YES`: keep the input bar glowing.
/// - `-edgeGlow YES`: glow around the screen edge.
/// - `-palette Lagoon`: start with a preset (Nebula, Ember, Lagoon, Dusk).
/// - `-scenario glow-scroll | legacy-scroll | scrollonly` and `-measure 10`: see `Benchmark/`.
struct ChatDemoView: View {
    @State private var messages: [Message] = Message.samples
    @State private var draft = ""
    @State private var generating = UserDefaults.standard.bool(forKey: "generating")
    @State private var edgeGlow = UserDefaults.standard.bool(forKey: "edgeGlow")
    @State private var paletteName = UserDefaults.standard.string(forKey: "palette") ?? "Nebula"
    @State private var scenario = Scenario.fromArguments()

    private var colors: MarqueeGlowColors {
        MarqueeGlowColors.presets.first { $0.name == paletteName }?.colors ?? .nebula
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                inputBar
            }
            .navigationTitle("MarqueeGlow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { settingsMenu }
        }
        .overlay {
            if scenario == .legacyScroll {
                LegacyMarquee(colors: colors.gradientColors(for: .dark))
            } else {
                Color.clear
                    .marqueeGlow(isActive: edgeGlow, colors: colors, lineWidth: 3, cornerRadius: 55, placement: .inside)
                    .ignoresSafeArea()
            }
        }
        .task { scenario.start(edgeGlow: $edgeGlow, generating: $generating) }
    }

    private var transcript: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask anything", text: $draft)
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: generating ? "stop.fill" : "arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor, in: .circle)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(generating ? "Stop" : "Send")
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .capsule)
        .marqueeGlow(isActive: generating, colors: colors, lineWidth: 2, cornerRadius: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var settingsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Colors", selection: $paletteName) {
                    ForEach(MarqueeGlowColors.presets, id: \.name) { Text($0.name).tag($0.name) }
                }
                Toggle("Screen edge glow", isOn: $edgeGlow)
                Toggle("Generating", isOn: $generating)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    private func send() {
        if generating {
            generating = false
            return
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(Message(text: text, fromUser: true))
        draft = ""
        generating = true
        Task {
            try? await Task.sleep(for: .seconds(4))
            messages.append(Message(text: "Here is a reply. The glow stops as soon as it finishes.", fromUser: false))
            generating = false
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    var text: String
    var fromUser: Bool

    static let samples: [Message] = (0..<30).map { i in
        i.isMultiple(of: 2)
            ? Message(text: "Question \(i / 2 + 1): how does the glow stay smooth while the list scrolls?", fromUser: true)
            : Message(text: "The halo is blurred once into a mask. Each frame only rotates a gradient behind it, so nothing is re-rendered.", fromUser: false)
    }
}

struct MessageBubble: View {
    var message: Message

    var body: some View {
        HStack {
            if message.fromUser { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.fromUser ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(.quaternary),
                    in: .rect(cornerRadius: 18)
                )
            if !message.fromUser { Spacer(minLength: 48) }
        }
    }
}
