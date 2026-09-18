#!/usr/bin/env python3
"""Rewrites the game text in Resources/Abyss/artifact-sets.json from the game's
own localisation.

Every set carries a name and a 2-piece / 4-piece effect description in two
languages. None of that is ours to write: Genshin ships an official Vietnamese
localisation, and a set description paraphrased by hand — or by a model — reads
differently from what the player sees in game, uses different terms for the
same mechanic ("Xoáy cuốn" where the game says "Khuếch Tán"), and quietly drops
or adds conditions. So this script owns those fields and nothing else:

    name                      <- gi.yatta.moe/api/v2/en  reliquary name
    nameVI                    <- gi.yatta.moe/api/v2/vi  reliquary name
    twoPiece.description      <- en affix 0
    twoPiece.descriptionVI    <- vi affix 0
    fourPiece.description     <- en affix 1
    fourPiece.descriptionVI   <- vi affix 1

`bonuses`, `rarity`, `domain`, `bestCharacters` and the rest are untouched: the
numbers the damage model reads are structured data kept separately, and are not
derived from this prose.

Sets are matched by the game's numeric id through `game-ids.json`, not by name,
so a renamed set cannot be matched to the wrong entry. The four Prayers sets are
one-piece circlets and carry a single affix; it goes in `twoPiece` (the slot the
data has always used for them) and `fourPiece` is left empty.

    python3 scripts/sync-abyss-artifact-text.py

Run it after adding artifact sets, and after `generate-abyss-game-ids.py` so the
id table knows the new ones. Network access required. The script refuses to
write if any set in our data fails to resolve in either language — a partial
sync would leave a mix of official and unofficial text, which is the state this
script exists to end.
"""

from __future__ import annotations

import collections
import json
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
SETS = os.path.join(DATA, "artifact-sets.json")
GAME_IDS = os.path.join(DATA, "game-ids.json")

YATTA = "https://gi.yatta.moe/api/v2/{lang}/reliquary"


def fetch(url: str) -> dict:
    """Fetches JSON with curl — Yatta answers urllib with a 403."""
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "60", "-A",
         "ns-launcher/artifact-text (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def clean(text: str) -> str:
    """The game's text format writes a line break as the two characters `\\n`."""
    return text.replace("\\n", "\n").strip()


def affixes(item: dict) -> list[str]:
    """A set's effects in piece order. Affix ids end in 0 for the first bonus
    and 1 for the second, so sorting the ids sorts the pieces."""
    return [clean(item["affixList"][key]) for key in sorted(item.get("affixList") or {})]


def main() -> int:
    with open(SETS, encoding="utf-8") as handle:
        sets = json.load(handle, object_pairs_hook=collections.OrderedDict)
    with open(GAME_IDS, encoding="utf-8") as handle:
        slug_by_game_id = json.load(handle)["artifactSets"]
    game_id_by_slug = {slug: game_id for game_id, slug in slug_by_game_id.items()}

    upstream = {lang: fetch(YATTA.format(lang=lang))["data"]["items"] for lang in ("en", "vi")}

    problems = []
    for record in sets:
        game_id = game_id_by_slug.get(record["id"])
        if game_id is None:
            problems.append(f"{record['id']}: not in game-ids.json (run generate-abyss-game-ids.py)")
            continue
        for lang, items in upstream.items():
            if game_id not in items:
                problems.append(f"{record['id']}: game id {game_id} missing from Yatta '{lang}'")
            elif not affixes(items[game_id]):
                problems.append(f"{record['id']}: Yatta '{lang}' has no effect text")
    if problems:
        print("refusing to write; nothing was changed:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    changed = 0
    for record in sets:
        game_id = game_id_by_slug[record["id"]]
        en, vi = upstream["en"][game_id], upstream["vi"][game_id]
        en_affixes, vi_affixes = affixes(en), affixes(vi)
        before = json.dumps(record, ensure_ascii=False, sort_keys=True)

        record["name"] = en["name"]
        record["nameVI"] = vi["name"]
        for index, piece in enumerate(("twoPiece", "fourPiece")):
            effect = record[piece]
            english = en_affixes[index] if index < len(en_affixes) else ""
            vietnamese = vi_affixes[index] if index < len(vi_affixes) else ""
            # Rebuilt rather than assigned, so `descriptionVI` sits next to
            # `description` in the file instead of after `bonuses`.
            rebuilt = collections.OrderedDict()
            rebuilt["description"] = english
            rebuilt["descriptionVI"] = vietnamese
            for key, value in effect.items():
                if key not in rebuilt:
                    rebuilt[key] = value
            record[piece] = rebuilt

        if json.dumps(record, ensure_ascii=False, sort_keys=True) != before:
            changed += 1

    with open(SETS, "w", encoding="utf-8") as handle:
        json.dump(sets, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"artifact sets: {len(sets)} synced from gi.yatta.moe (en + vi), {changed} changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
