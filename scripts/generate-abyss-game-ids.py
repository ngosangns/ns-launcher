#!/usr/bin/env python3
"""Regenerates Resources/Abyss/game-ids.json.

The Abyss data names everything with slugs ("hu-tao", "staff-of-homa"); the game
— and so Enka.Network, which is where a showcase import comes from — names
everything with numeric ids. This builds the table between them.

Everything is matched by English name against the same source the Abyss data was
transcribed from (gi.yatta.moe), so a mismatch here means the two disagree about
a name, which is worth knowing. The one exception is the Traveler: Enka reports
a Traveler as avatar 10000005/10000007 plus a *skill depot* id that says which
element they are currently attuned to, and only Enka's own store publishes what
those depots mean.

Run it after adding characters, weapons or artifact sets to the data:

    python3 scripts/generate-abyss-game-ids.py

Network access required. The script refuses to write a table that lost entries
the committed one already had, so a bad day at either upstream cannot silently
shrink the mapping.
"""

from __future__ import annotations

import datetime
import glob
import json
import os
import re
import subprocess
import sys
import unicodedata

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
OUTPUT = os.path.join(DATA, "game-ids.json")

YATTA = "https://gi.yatta.moe/api/v2/en"
ENKA_STORE = "https://raw.githubusercontent.com/EnkaNetwork/API-docs/master/store/characters.json"

# Enka's element names for the Traveler's skill depots.
ENKA_ELEMENTS = {
    "Wind": "anemo",
    "Rock": "geo",
    "Electric": "electro",
    "Grass": "dendro",
    "Water": "hydro",
    "Fire": "pyro",
    "Ice": "cryo",
}


def fetch(url: str) -> dict:
    """Fetches JSON with curl.

    Not urllib: Yatta answers it with a 403, and the whole Abyss data set was
    collected with curl for the same reason.
    """
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "60", "-A", "ns-launcher/game-ids (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def normalize(name: str) -> str:
    """Folds a display name to something two sources can agree on.

    Accents, punctuation and case all vary between the wiki text the Abyss data
    came from and the API. A trailing parenthetical is dropped so our
    "Tartaglia (Childe)" matches the game's "Tartaglia".
    """
    name = re.sub(r"\s*\([^)]*\)\s*$", "", name or "")
    name = unicodedata.normalize("NFKD", name)
    name = "".join(c for c in name if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "", name.lower().replace("’", "'"))


def load_records(pattern: str, key: str) -> list[dict]:
    records: list[dict] = []
    for path in sorted(glob.glob(os.path.join(DATA, pattern))):
        payload = json.load(open(path, encoding="utf-8"))
        records += payload[key] if isinstance(payload, dict) and key in payload else payload
    return records


def build_table(ours: list[dict], theirs: dict, label: str, skip: set[str] = frozenset()) -> dict:
    """Maps game id -> our slug by name.

    `skip` drops normalized names that cannot be told apart this way — the seven
    Travelers all shorten to "Traveler", so matching them here would file every
    one of them under whichever variant happened to be read last.
    """
    by_name: dict[str, str] = {}
    for record in ours:
        key = normalize(record["name"])
        if key in skip:
            continue
        if key in by_name:
            raise SystemExit(f"{label}: '{record['name']}' collides with '{by_name[key]}' after normalizing")
        by_name[key] = record["id"]

    table = {}
    for game_id, entry in theirs.items():
        key = normalize(entry.get("name", ""))
        if key in skip:
            continue
        if slug := by_name.get(key):
            table[str(game_id)] = slug

    missing = sorted({record["id"] for record in ours} - set(table.values()) - {
        record["id"] for record in ours if normalize(record["name"]) in skip
    })
    print(f"{label}: mapped {len(table)}, {len(missing)} of ours unmapped")
    if missing:
        print(f"  unmapped: {', '.join(missing)}")
    return table


def main() -> int:
    characters = load_records("characters/*.json", "characters")
    weapons = load_records("weapons/*.json", "weapons")
    sets_payload = json.load(open(os.path.join(DATA, "artifact-sets.json"), encoding="utf-8"))
    artifact_sets = (
        sets_payload["artifactSets"]
        if isinstance(sets_payload, dict) and "artifactSets" in sets_payload
        else sets_payload
    )

    character_table = build_table(characters, fetch(f"{YATTA}/avatar")["data"]["items"], "characters",
                                  skip={"traveler"})
    weapon_table = build_table(weapons, fetch(f"{YATTA}/weapon")["data"]["items"], "weapons")
    set_table = build_table(artifact_sets, fetch(f"{YATTA}/reliquary")["data"]["items"], "artifact sets")

    # The Traveler: Enka keys its store by "<avatarId>-<skillDepotId>" and names
    # the element there. Depot 501 (and 701) is the un-attuned Traveler, which
    # has no element and no entry in our data.
    slugs = {record["id"] for record in characters}
    depots: dict[str, str] = {}
    for key, entry in fetch(ENKA_STORE).items():
        if "-" not in key:
            continue
        element = ENKA_ELEMENTS.get(entry.get("Element") or "")
        slug = f"traveler-{element}" if element else None
        if slug and slug in slugs:
            depots[key.split("-", 1)[1]] = slug
    missing_travelers = sorted(s for s in slugs if s.startswith("traveler-") and s not in depots.values())
    print(f"traveler depots: mapped {len(depots)}, {len(missing_travelers)} of ours unmapped")
    if missing_travelers:
        print(f"  unmapped: {', '.join(missing_travelers)} (Enka's store has no depot for them yet)")

    table = {
        "generatedAt": datetime.date.today().isoformat(),
        "source": "gi.yatta.moe/api/v2/en; Traveler depots from EnkaNetwork/API-docs store/characters.json",
        "characters": dict(sorted(character_table.items(), key=lambda kv: kv[1])),
        "travelerSkillDepots": dict(sorted(depots.items(), key=lambda kv: kv[1])),
        "weapons": dict(sorted(weapon_table.items(), key=lambda kv: kv[1])),
        "artifactSets": dict(sorted(set_table.items(), key=lambda kv: kv[1])),
    }

    # A table that lost entries means an upstream hiccup, not a data change.
    if os.path.exists(OUTPUT):
        previous = json.load(open(OUTPUT, encoding="utf-8"))
        for section in ("characters", "travelerSkillDepots", "weapons", "artifactSets"):
            lost = set(previous.get(section, {})) - set(table[section])
            if lost:
                print(f"refusing to write: {section} would lose {len(lost)} ids "
                      f"({', '.join(sorted(lost)[:5])}...)", file=sys.stderr)
                return 1

    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(table, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
