// AbyssSetEffectPopover.swift
//
// What a recommended artifact set actually does, shown on hover.
//
// The team panel could only ever afford the set's *name*, which is the least
// useful thing about it: "Obsidian Codex" says nothing about why it won, and a
// player who has not farmed it has no way to judge whether it is worth the
// resin. The popover carries the game's own effect text — and, next to it, what
// the model did with that text, which is not always the same thing. Each effect
// is a structured buff read from the game text (`passives.json`), timed over the
// wearer's rotation; some are not priced at all. Saying so here is the honest
// place to say it, because this is where the recommendation is being made.
//
// Only the effects actually in force are shown: one set is a 4-piece and gets
// both its bonuses, two sets are 2+2 and get one each. Printing a 4-piece effect
// next to a set worn as two pieces would describe a build nobody is wearing.

import SwiftUI

/// What the model credits a set's bonus with.
///
/// Pulled out of the view because it is the one claim in the popover that can be
/// quietly wrong: `unpriced` says the recommendation was made without the
/// effect, and printing "the model applies …" over a set the model applies
/// nothing for would be worse than printing nothing.
enum AbyssSetPricing: Equatable {
    /// These buffs went into the stat sheet, each at its standing on the
    /// wearer's rotation.
    case modelled([AbyssBuff])
    /// None of the effect is priced.
    case unpriced

    static func of(_ buffs: [AbyssBuff]) -> AbyssSetPricing {
        let priced = buffs.filter { buff in
            !buff.conditions.contains { condition in
                switch condition {
                case .unmodelled, .defeat, .energyFull, .energyEmpty, .hpBelow, .enemiesAtLeast: return true
                default: return false
                }
            }
        }
        return priced.isEmpty ? .unpriced : .modelled(priced)
    }
}

extension AbyssArtifactSet.Effect {
    /// The game's own text for the viewer's language. Falls back to English
    /// rather than to nothing when a data file carries no Vietnamese.
    func description(in text: AppText) -> String {
        text.pick(en: description, vi: descriptionVI ?? description)
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
                AbyssSetEffectCard(entries: entries, text: text, viewModel: viewModel)
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
                buffs: viewModel.setBuffs(id))
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
        /// What the model read from each piece.
        let buffs: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])
    }

    let entries: [Entry]
    let text: AppText
    @ObservedObject var viewModel: AbyssViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        AbyssPortraitImage(url: viewModel.artifactSetIconURL(entry.artifactSet.id),
                                           systemImage: "seal.fill",
                                           tint: LauncherPalette.gold.opacity(0.7),
                                           size: 26, cornerRadius: 6)
                        Text(text.pick(en: entry.artifactSet.name, vi: entry.artifactSet.nameVI))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(LauncherPalette.goldHighlight)
                        Text(text.abyssSetPieces(entry.pieces))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.6))
                    }

                    effect(text.abyssSetPieces(2), entry.artifactSet.twoPiece,
                           modelNote: note(entry.buffs.twoPiece))
                    if entry.pieces == 4 {
                        effect(text.abyssSetPieces(4), entry.artifactSet.fourPiece,
                               modelNote: note(entry.buffs.fourPiece))
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
                        modelNote: ModelNote) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(LauncherPalette.gold.opacity(0.7))
            Text(effect.description(in: text))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(LauncherPalette.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // What the engine actually added to the stat sheet, and — for a
            // triggered effect — that it is worth what the rotation keeps up
            // rather than its full number.
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
        }
    }

    private struct ModelNote {
        let line: String
        var detail: String?
        var isMissing = false
    }

    private func note(_ buffs: [AbyssBuff]) -> ModelNote {
        switch AbyssSetPricing.of(buffs) {
        case .modelled(let priced):
            let line = text.abyssSetModelled(priced.map(text.abyssBuffLine).joined(separator: ", "))
            let timed = priced.contains { !$0.isAlwaysOn }
            return ModelNote(line: line, detail: timed ? text.abyssSetTimed : nil)
        case .unpriced:
            return ModelNote(line: text.abyssSetNotModelled, isMissing: true)
        }
    }
}
