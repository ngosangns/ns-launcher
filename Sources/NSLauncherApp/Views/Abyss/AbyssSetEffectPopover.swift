// AbyssSetEffectPopover.swift
//
// What a recommended artifact set actually does, shown on hover.
//
// The team panel could only ever afford the set's *name*, which is the least
// useful thing about it: "Obsidian Codex" says nothing about why it won, and a
// player who has not farmed it has no way to judge whether it is worth the
// resin. The popover carries the game's own effect text — and, next to it, what
// the model did with that text, which is not always the same thing. A third of
// the 4-piece effects are too conditional to read mechanically and are priced by
// a hand-written estimate in `tuning.json`; some are not priced at all. Saying so
// here is the honest place to say it, because this is where the recommendation
// is being made.
//
// Only the effects actually in force are shown: one set is a 4-piece and gets
// both its bonuses, two sets are 2+2 and get one each. Printing a 4-piece effect
// next to a set worn as two pieces would describe a build nobody is wearing.

import SwiftUI

/// How the model came by the number it credited a 4-piece set with.
///
/// Pulled out of the view because it is the one claim in the popover that can be
/// quietly wrong: `unpriced` says the recommendation was made without the set's
/// headline effect, and printing "the model applies …" over a set the model
/// applies nothing for would be worse than printing nothing.
enum AbyssSetPricing: Equatable {
    /// The data's own parsed numbers went into the stat sheet.
    case fromData
    /// Too conditional to read mechanically; `tuning.json` credits this much
    /// effective %DMG by hand.
    case estimated(AbyssTuning.SetEffectApproximation)
    /// Neither. The set was ranked on its 2-piece alone.
    case unpriced

    static func == (lhs: AbyssSetPricing, rhs: AbyssSetPricing) -> Bool {
        switch (lhs, rhs) {
        case (.fromData, .fromData), (.unpriced, .unpriced): return true
        case (.estimated(let a), .estimated(let b)): return a.setId == b.setId
        default: return false
        }
    }

    static func of(_ fourPiece: AbyssArtifactSet.Effect,
                   approximation: AbyssTuning.SetEffectApproximation?) -> AbyssSetPricing {
        // The estimate wins when there is one: `AbyssBuildAssembler` applies the
        // table's figure, and the parsed bonuses of such a set are usually the
        // uninteresting half of the effect.
        if let approximation { return .estimated(approximation) }
        return fourPiece.bonuses.isEmpty ? .unpriced : .fromData
    }
}

extension AbyssArtifactSet.Effect {
    /// The game's own text for the viewer's language. Falls back to English
    /// rather than to nothing when a data file carries no Vietnamese.
    func description(in text: AppText) -> String {
        text.pick(en: description, vi: descriptionVI ?? description)
    }
}

extension AbyssArtifactSet.Bonus {
    /// `0.15` reads as a percentage and `80` as a flat number. That split holds
    /// for every bonus in `artifact-sets.json` — the flat ones are Elemental
    /// Mastery, DEF and Max HP, and none of them is below 1.
    var displayText: String {
        let sign = value < 0 ? "-" : "+"
        let magnitude = abs(value)
        let amount = magnitude < 1
            ? "\(sign)\(Int((magnitude * 100).rounded()))%"
            : "\(sign)\(Int(magnitude.rounded()))"
        return "\(amount) \(stat)"
    }
}

struct AbyssArtifactSetLabel: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText
    /// Already formatted by the caller, so the label reads exactly as it did
    /// before the popover existed.
    let title: String
    /// One id is a 4-piece; two ids are two 2-piece sets.
    let setIDs: [String]

    @State private var isShowingEffects = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(LauncherPalette.parchment.opacity(0.82))
            .lineLimit(1)
            .onHover { hovering in
                // A delay in both directions. Opening at once fires a popover at
                // every set the pointer crosses on its way somewhere else;
                // closing at once means the popover cannot be moved into, and
                // makes it flicker if it lands under the pointer.
                hoverTask?.cancel()
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(hovering ? 260 : 160))
                    guard !Task.isCancelled else { return }
                    isShowingEffects = hovering
                }
            }
            .onDisappear { hoverTask?.cancel() }
            .popover(isPresented: $isShowingEffects, arrowEdge: .bottom) {
                AbyssSetEffectCard(entries: entries, text: text)
                    .onHover { hovering in
                        // Reading the popover keeps it open; leaving it closes
                        // it the same way leaving the label does.
                        hoverTask?.cancel()
                        guard !hovering else { return }
                        hoverTask = Task {
                            try? await Task.sleep(for: .milliseconds(160))
                            guard !Task.isCancelled else { return }
                            isShowingEffects = false
                        }
                    }
            }
    }

    private var entries: [AbyssSetEffectCard.Entry] {
        setIDs.compactMap { id in
            guard let set = viewModel.artifactSet(id) else { return nil }
            return AbyssSetEffectCard.Entry(
                artifactSet: set,
                pieces: setIDs.count == 1 ? 4 : 2,
                approximation: viewModel.setEffectApproximation(id))
        }
    }
}

/// The popover itself.
private struct AbyssSetEffectCard: View {
    struct Entry: Identifiable {
        var id: String { artifactSet.id }
        /// Named in full because `set` is a setter keyword in a property body.
        let artifactSet: AbyssArtifactSet
        /// 4 or 2. Decides whether the 4-piece effect is in force.
        let pieces: Int
        /// Present when the model prices this set's 4-piece by hand.
        let approximation: AbyssTuning.SetEffectApproximation?
    }

    let entries: [Entry]
    let text: AppText

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Text(text.pick(en: entry.artifactSet.name, vi: entry.artifactSet.nameVI))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(LauncherPalette.goldHighlight)
                        Text(text.abyssSetPieces(entry.pieces))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.6))
                    }

                    effect(text.abyssSetPieces(2), entry.artifactSet.twoPiece, modelNote: nil)
                    if entry.pieces == 4 {
                        effect(text.abyssSetPieces(4), entry.artifactSet.fourPiece,
                               modelNote: fourPieceNote(entry))
                    }
                }
            }
        }
        .frame(width: 330, alignment: .leading)
        .padding(14)
        .background(LauncherPalette.night.opacity(0.96))
    }

    /// One bonus block: what the game says, then what the model took from it.
    @ViewBuilder
    private func effect(_ label: String,
                        _ effect: AbyssArtifactSet.Effect,
                        modelNote: ModelNote?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(LauncherPalette.gold.opacity(0.7))
            Text(effect.description(in: text))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(LauncherPalette.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // What the engine actually added to the stat sheet. For most sets
            // that is the parsed bonuses; where those are empty the model either
            // has a hand-written estimate or nothing at all, and both are worth
            // saying out loud next to a recommendation.
            if let modelNote {
                Text(modelNote.line)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(modelNote.isMissing
                        ? LauncherPalette.mist.opacity(0.5)
                        : LauncherPalette.success.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = modelNote.detail {
                    Text(detail)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if !effect.bonuses.isEmpty {
                Text(text.abyssSetModelled(
                    effect.bonuses.map(\.displayText).joined(separator: ", ")))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(LauncherPalette.success.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private struct ModelNote {
        let line: String
        var detail: String?
        var isMissing = false
    }

    private func fourPieceNote(_ entry: Entry) -> ModelNote {
        switch AbyssSetPricing.of(entry.artifactSet.fourPiece,
                                  approximation: entry.approximation) {
        case .estimated(let approximation):
            var line = text.abyssSetModelled(
                text.abyssSetApproximateBonus(approximation.damageBonus,
                                              scope: text.abyssSetScope(approximation.scope)))
            if approximation.party == true { line += " · " + text.abyssSetPartyWide }
            if let requirement = approximation.requirement {
                line += " · " + text.abyssSetRequirement(requirement)
            }
            return ModelNote(line: line, detail: text.abyssSetEstimated + " " + approximation.note)
        case .fromData:
            return ModelNote(line: text.abyssSetModelled(
                entry.artifactSet.fourPiece.bonuses.map(\.displayText).joined(separator: ", ")))
        case .unpriced:
            return ModelNote(line: text.abyssSetNotModelled, isMissing: true)
        }
    }
}
