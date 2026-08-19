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
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, role == .quiet ? 12 : 18)
            .padding(.vertical, role == .quiet ? 9 : 13)
            .background(background(configuration.isPressed), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(border, lineWidth: role == .quiet ? 0.8 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
        case .secondary: LauncherPalette.gold.opacity(0.62)
        case .quiet: LauncherPalette.mist.opacity(0.34)
        }
    }

    private func background(_ isPressed: Bool) -> Color {
        switch role {
        case .primary: isPressed ? LauncherPalette.gold : LauncherPalette.goldHighlight
        case .secondary: isPressed ? LauncherPalette.sky.opacity(0.44) : LauncherPalette.twilight.opacity(0.70)
        case .quiet: isPressed ? LauncherPalette.mist.opacity(0.18) : LauncherPalette.night.opacity(0.32)
        }
    }
}

struct StatusPill: View {
    let title: String
    var tint: Color = LauncherPalette.success

    var body: some View {
        Label(title, systemImage: "circle.fill")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
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
