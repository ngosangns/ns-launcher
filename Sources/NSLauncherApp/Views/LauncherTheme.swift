import SwiftUI

enum LauncherPalette {
    static let night = Color(red: 0.055, green: 0.085, blue: 0.18)
    static let twilight = Color(red: 0.12, green: 0.22, blue: 0.43)
    static let sky = Color(red: 0.30, green: 0.55, blue: 0.79)
    static let parchment = Color(red: 0.94, green: 0.92, blue: 0.83)
    static let ink = Color(red: 0.09, green: 0.12, blue: 0.20)
    static let gold = Color(red: 0.90, green: 0.72, blue: 0.36)
    static let goldHighlight = Color(red: 0.98, green: 0.86, blue: 0.56)
    static let mist = Color(red: 0.78, green: 0.87, blue: 0.94)
    static let success = Color(red: 0.49, green: 0.82, blue: 0.66)
    static let warning = Color(red: 0.95, green: 0.64, blue: 0.30)
}

struct CelestialBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LauncherPalette.night, LauncherPalette.twilight, LauncherPalette.sky.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [LauncherPalette.gold.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 640
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                Group {
                    Circle()
                        .fill(LauncherPalette.mist.opacity(0.12))
                        .frame(width: width * 0.72, height: width * 0.30)
                        .blur(radius: 28)
                        .offset(x: -width * 0.26, y: height * 0.49)

                    Circle()
                        .fill(LauncherPalette.parchment.opacity(0.09))
                        .frame(width: width * 0.66, height: width * 0.20)
                        .blur(radius: 38)
                        .offset(x: width * 0.40, y: -height * 0.36)
                }

                ConstellationField(size: proxy.size)
            }
        }
        .ignoresSafeArea()
    }
}

private struct ConstellationField: View {
    let size: CGSize

    private let stars: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.16), CGPoint(x: 0.18, y: 0.31), CGPoint(x: 0.28, y: 0.12),
        CGPoint(x: 0.42, y: 0.24), CGPoint(x: 0.55, y: 0.10), CGPoint(x: 0.68, y: 0.21),
        CGPoint(x: 0.82, y: 0.09), CGPoint(x: 0.91, y: 0.30), CGPoint(x: 0.73, y: 0.47),
        CGPoint(x: 0.12, y: 0.62), CGPoint(x: 0.34, y: 0.73), CGPoint(x: 0.62, y: 0.81)
    ]

    var body: some View {
        Canvas { context, canvasSize in
            for (index, star) in stars.enumerated() {
                let point = CGPoint(x: star.x * canvasSize.width, y: star.y * canvasSize.height)
                let radius: CGFloat = index.isMultiple(of: 3) ? 2.2 : 1.2
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(LauncherPalette.parchment.opacity(index.isMultiple(of: 3) ? 0.72 : 0.34))
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

struct OrnamentalPanel<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let tone: Color
    /// Panels whose top-right corner carries its own controls opt out of the mark so the two don't
    /// overlap — and so only one mark shows per screen.
    private let showsMark: Bool

    init(
        padding: CGFloat = 22,
        tone: Color = LauncherPalette.night.opacity(0.54),
        showsMark: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.tone = tone
        self.showsMark = showsMark
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [LauncherPalette.gold.opacity(0.72), LauncherPalette.mist.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if showsMark {
                    CelestialMark()
                        .padding(14)
                        .opacity(0.66)
                }
            }
            .shadow(color: LauncherPalette.night.opacity(0.26), radius: 24, y: 12)
    }
}

struct CelestialMark: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(LauncherPalette.gold.opacity(0.62), lineWidth: 1)
                .frame(width: 21, height: 21)
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(LauncherPalette.goldHighlight)
        }
    }
}

struct QuestButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
        case quiet
    }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        QuestButtonBody(role: role, configuration: configuration)
    }
}

/// Separated from `QuestButtonStyle` so hover state can live in `@State` — `ButtonStyle.makeBody`
/// itself can't hold state across renders.
private struct QuestButtonBody: View {
    let role: QuestButtonStyle.Role
    let configuration: QuestButtonStyle.Configuration
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, role == .quiet ? 14 : 18)
            .padding(.vertical, role == .quiet ? 10 : 13)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(border, lineWidth: role == .quiet ? 0.8 : 1)
            }
            .shadow(color: shadowColor, radius: isHovering ? 10 : 6, y: 3)
            .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        switch role {
        case .primary: LauncherPalette.ink
        case .secondary, .quiet: LauncherPalette.parchment
        }
    }

    private var border: Color {
        switch role {
        case .primary: LauncherPalette.goldHighlight.opacity(0.92)
        case .secondary: LauncherPalette.gold.opacity(isHovering ? 0.9 : 0.62)
        case .quiet: LauncherPalette.mist.opacity(isHovering ? 0.55 : 0.34)
        }
    }

    private var shadowColor: Color {
        switch role {
        case .primary: LauncherPalette.gold.opacity(isHovering ? 0.55 : 0.28)
        case .secondary: LauncherPalette.twilight.opacity(isHovering ? 0.6 : 0.3)
        case .quiet: .clear
        }
    }

    private var background: Color {
        switch role {
        case .primary: configuration.isPressed ? LauncherPalette.gold : LauncherPalette.goldHighlight
        case .secondary:
            configuration.isPressed
                ? LauncherPalette.sky.opacity(0.44)
                : LauncherPalette.twilight.opacity(isHovering ? 0.88 : 0.70)
        case .quiet:
            configuration.isPressed
                ? LauncherPalette.mist.opacity(0.18)
                : LauncherPalette.night.opacity(isHovering ? 0.48 : 0.32)
        }
    }
}

extension View {
    /// Applies the quest button chrome and its matching pointer/disabled state in one call —
    /// every call site paired `.disabled(x)` with `.pointerOnHover(enabled: !x)` by hand before.
    func quest(_ role: QuestButtonStyle.Role, disabled: Bool = false) -> some View {
        buttonStyle(QuestButtonStyle(role: role))
            .disabled(disabled)
            .pointerOnHover(enabled: !disabled)
    }
}

/// Thin gold corner brackets framing the whole window, echoing a HUD/quest-log border.
struct WindowFrameOrnament: View {
    /// Distance from the true window edge. Deliberately NOT `.ignoresSafeArea()`: that made this
    /// view's `GeometryReader` measure a taller region than the `ZStack` it sits in actually
    /// renders at (the window's own titlebar already claims that space), so the bottom pair of
    /// brackets landed below the visible window and the top pair sat too high — both effectively
    /// off-window. Matching the same bounds every other child of that `ZStack` gets keeps all four
    /// brackets anchored to the corners actually on screen.
    private let inset: CGFloat = 16
    private let length: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let corners: [(CGPoint, (CGFloat, CGFloat), (CGFloat, CGFloat))] = [
                (CGPoint(x: inset, y: inset), (1, 0), (0, 1)),
                (CGPoint(x: proxy.size.width - inset, y: inset), (-1, 0), (0, 1)),
                (CGPoint(x: inset, y: proxy.size.height - inset), (1, 0), (0, -1)),
                (CGPoint(x: proxy.size.width - inset, y: proxy.size.height - inset), (-1, 0), (0, -1))
            ]
            Canvas { context, _ in
                for (origin, dx, dy) in corners {
                    var path = Path()
                    path.move(to: CGPoint(x: origin.x + length * dx.0, y: origin.y + length * dx.1))
                    path.addLine(to: origin)
                    path.addLine(to: CGPoint(x: origin.x + length * dy.0, y: origin.y + length * dy.1))
                    context.stroke(path, with: .color(LauncherPalette.gold.opacity(0.55)), lineWidth: 1.4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A pill-shaped tab used for the app's Home/Settings switch and the settings sidebar list.
struct SidebarTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    /// When false, this button shows only its icon while inactive — the label
    /// returns the moment it becomes the active tab.
    ///
    /// Default `true` keeps every existing call site unchanged: this only
    /// belongs on a tight row of two or three peers switching one another out
    /// (the Abyss Roster/Results toggle is the case it was built for), never on
    /// a vertical navigation list, where a reader has nothing but an icon to
    /// recognise an item they have not learned the icon for yet.
    var showsLabelWhenInactive: Bool = true
    let action: () -> Void

    @State private var isHovering = false

    private var showsLabel: Bool { isSelected || showsLabelWhenInactive }

    var body: some View {
        Button(action: action) {
            Group {
                if showsLabel {
                    Label(title, systemImage: systemImage)
                } else {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? LauncherPalette.ink : LauncherPalette.parchment.opacity(0.86))
            .padding(.horizontal, showsLabel ? 14 : 10)
            .padding(.vertical, 9)
            .frame(maxWidth: showsLabel ? .infinity : nil, minHeight: 22,
                   alignment: showsLabel ? .leading : .center)
            .background(
                isSelected
                    ? LauncherPalette.goldHighlight
                    : LauncherPalette.night.opacity(isHovering ? 0.48 : 0.30),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .pointerOnHover()
        .onHover { isHovering = $0 }
        // The icon-only state still needs the name to reach a reader —
        // a hover tooltip for a sighted user, and always for VoiceOver.
        .help(title)
        .accessibilityLabel(title)
    }
}

/// A large circular action button (Play/Stop) with a gold progress ring — the launcher's primary
/// call to action, styled after a game launcher's single "start" control rather than a toolbar pill.
struct CircularActionButton: View {
    let systemImage: String
    let title: String
    /// Progress fraction 0...1, or nil for an indeterminate spinner ring.
    let progress: Double?
    let isActive: Bool
    let action: () -> Void

    private let diameter: CGFloat = 92

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(LauncherPalette.mist.opacity(0.14), lineWidth: 4)

                if let progress {
                    Circle()
                        .trim(from: 0, to: max(0.02, min(progress, 1)))
                        .stroke(
                            LinearGradient(colors: [LauncherPalette.gold, LauncherPalette.goldHighlight], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                } else if isActive {
                    Circle()
                        .stroke(LauncherPalette.goldHighlight.opacity(0.85), lineWidth: 4)
                }

                Circle()
                    .fill(LauncherPalette.goldHighlight)
                    .frame(width: diameter - 16, height: diameter - 16)
                    .shadow(color: LauncherPalette.gold.opacity(isHovering ? 0.65 : 0.5), radius: isHovering ? 14 : 12, y: 4)

                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .bold))
                    Text(title.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.0)
                }
                .foregroundStyle(LauncherPalette.ink)
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
        .opacity(isPressed ? 0.92 : 1)
        .pointerOnHover()
        .onHover { isHovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

/// Generic icon + title + subtitle-lines row used across Settings for cache, voice-pack, and
/// storage listings — the three used to be near-identical copies of the same layout.
struct InventoryRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitleLines: [String]
    @ViewBuilder let trailing: () -> Trailing

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(LauncherPalette.goldHighlight)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                ForEach(subtitleLines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            LauncherPalette.gold.opacity(isHovering ? 0.08 : 0),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

private struct HoverLiftModifier: ViewModifier {
    let scale: CGFloat
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    /// A subtle hover scale for non-button cards (toggles, fields) so the whole surface feels
    /// interactive without borrowing `QuestButtonStyle`'s button chrome.
    func hoverLift(scale: CGFloat = 1.012) -> some View {
        modifier(HoverLiftModifier(scale: scale))
    }
}

struct GoldenProgressBar: View {
    let value: Double?

    var body: some View {
        Group {
            if let value {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(LauncherPalette.mist.opacity(0.14))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [LauncherPalette.gold, LauncherPalette.goldHighlight],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(6, proxy.size.width * min(max(value, 0), 1)))
                    }
                }
            } else {
                Capsule()
                    .fill(LauncherPalette.mist.opacity(0.14))
            }
        }
        .frame(height: 8)
    }
}

/// How a rarity tier looks: an accent for glyphs and edges on the dark ground,
/// and a light fill for when the tile is selected and its text turns to ink.
///
/// Two colours rather than one because the tile inverts when selected — a single
/// accent saturated enough to read against the backdrop is too dark to put ink
/// text on. The mapping from a game's own rarity scale lives with that game's
/// presentation code, not here.
struct RarityAppearance: Equatable {
    let stars: Int
    let accent: Color
    let fill: Color
    /// The top tier gets a sheen the others do not, so it reads at a glance in a
    /// grid of a hundred tiles.
    var isTopTier: Bool = false
}

/// A compact own/don't-own tile for grid pickers, with an optional level stepper
/// once the item is owned.
///
/// `InventoryRow` above is a full-width row; a roster picker shows 125 entries at
/// once and needs a tile. Kept here with the rest of the design system rather
/// than private to the Abyss views so the next grid picker does not invent a
/// third look.
struct RosterCard<Icon: View>: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    /// Current level and its range, shown only while selected. nil hides the stepper.
    let level: (value: Int, range: ClosedRange<Int>, label: String)?
    /// Rarity tier, drawn as pips and as the tile's own colour. nil for pickers
    /// whose items have no rarity.
    var rarity: RarityAppearance?
    /// The leading glyph — an SF Symbol, a portrait, whatever the caller has.
    /// A closure rather than a fixed `systemImage`/`accent` pair so a picker
    /// that has real artwork (`AbyssPortraitImage`) is not stuck drawing a
    /// generic glyph just because this type was written for one.
    @ViewBuilder let icon: () -> Icon
    let onToggle: () -> Void
    let onLevelChange: (Int) -> Void

    @State private var isHovering = false

    private var tint: Color { rarity?.accent ?? LauncherPalette.gold }
    private var selectedFill: Color { rarity?.fill ?? LauncherPalette.goldHighlight }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                icon()

                // Title, stars, and the level stepper share this column so the
                // stepper lands directly under the stars it is levelling —
                // not under the portrait, which is a wider, unrelated anchor.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(isSelected ? LauncherPalette.ink : LauncherPalette.parchment)
                        .lineLimit(1)

                    HStack(spacing: 3) {
                        if let rarity {
                            starPips(rarity)
                        }
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(isSelected
                                    ? LauncherPalette.ink.opacity(0.62)
                                    : LauncherPalette.mist.opacity(0.62))
                                .lineLimit(1)
                        }
                    }

                    if isSelected, let level {
                        HStack(spacing: 6) {
                            Text("\(level.label)\(level.value)")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(LauncherPalette.ink.opacity(0.78))
                                .frame(minWidth: 26, alignment: .leading)
                            Stepper("", value: Binding(
                                get: { level.value },
                                set: { onLevelChange($0) }
                            ), in: level.range)
                            .labelsHidden()
                            .controlSize(.mini)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? LauncherPalette.ink.opacity(0.72) : LauncherPalette.mist.opacity(0.34))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? Color.clear : tint.opacity(isHovering ? 0.55 : 0.32),
                              lineWidth: 1)
        )
        .overlay(alignment: .top) { sheen }
        .pointerOnHover()
        .onHover { isHovering = $0 }
    }

    /// Rarity tints the tile itself in both states, so it survives selection —
    /// which is the state the player spends most of their time looking at.
    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if isSelected {
            shape.fill(selectedFill.opacity(0.92))
        } else {
            shape.fill(LauncherPalette.night.opacity(isHovering ? 0.52 : 0.34))
                .overlay(
                    shape.fill(
                        LinearGradient(colors: [tint.opacity(isHovering ? 0.22 : 0.14), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)))
        }
    }

    /// A hairline of light along the top edge, for the top rarity only.
    ///
    /// Deliberately faint. It has to survive being one tile among a hundred
    /// without turning the card muddy, so it reads as a lit edge rather than as
    /// a band of colour.
    @ViewBuilder
    private var sheen: some View {
        if rarity?.isTopTier == true {
            LinearGradient(
                colors: [(isSelected ? LauncherPalette.parchment : tint).opacity(isSelected ? 0.30 : 0.38), .clear],
                startPoint: .top, endPoint: .bottom)
                .frame(height: 5)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12,
                                                  style: .continuous))
                .allowsHitTesting(false)
        }
    }

    /// Filled pips up to the rarity, hollow after — readable at a glance and
    /// narrower than five glyphs of text.
    private func starPips(_ rarity: RarityAppearance) -> some View {
        HStack(spacing: 1.5) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= rarity.stars
                        ? (isSelected ? LauncherPalette.ink.opacity(0.7) : rarity.accent)
                        : (isSelected ? LauncherPalette.ink.opacity(0.16)
                                      : LauncherPalette.mist.opacity(0.18)))
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.trailing, subtitle.isEmpty ? 0 : 2)
        .accessibilityLabel("\(rarity.stars) star")
    }
}
