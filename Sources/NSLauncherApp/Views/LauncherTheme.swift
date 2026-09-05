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

    init(padding: CGFloat = 22, tone: Color = LauncherPalette.night.opacity(0.54), @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tone = tone
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
                CelestialMark()
                    .padding(14)
                    .opacity(0.66)
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
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? LauncherPalette.ink : LauncherPalette.parchment.opacity(0.86))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
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
