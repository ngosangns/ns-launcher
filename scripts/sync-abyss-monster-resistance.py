#!/usr/bin/env python3
"""Writes each Abyss monster's real elemental resistance into
Resources/Abyss/abyss-monsters/*.json, from the game's own files.

## Why this exists

The engine used to have no idea what an Abyss monster actually resists: the
wiki text this data was transcribed from carries a resistance note only when
something is unusual enough to call out, so on a typical rotation not one
monster has one. Without a note, the model *inferred* — every element a
monster's `elements` field named got a single flat bonus
(`AbyssTuning.enemyOwnElementResistance`, 30 percentage points) on the theory
that an enemy resists what it attacks or shields with.

That theory is directionally right and quantitatively wrong, in both
directions, and this script is what proved it: matching this rotation's floor
12 against `gi.yatta.moe`'s monster data (the game's own files) shows —

    Cryo Abyss Mage        Cryo    real +0pp   (inference said +30pp — invented)
    Iniquitous Baptist     4 elems real +0pp   (inference said +30pp each — invented)
    Icewind Suite          Anemo   real +60pp  (inference said +30pp — half the truth)
    Icewind Suite          Cryo    real +60pp  (inference said +30pp — half the truth)
    Gluttonous Yumkasaur   Dendro  real +60pp  (inference said +30pp — half the truth)
    Gluttonous Yumkasaur   Pyro    real +0pp   (inference said +30pp — invented)
    Chimeric Horned Bear   Pyro    real +20pp  (inference said +30pp — close but wrong)
    Chimeric Winged Lion   Anemo   real +40pp  (inference said +30pp — understated)
    Chimeric Winged Lion   Electro real +40pp  (inference said +30pp — understated)

A flat constant cannot be all of "invented", "half the truth" and "close but
wrong" at once for different monsters — the flat model was never going to be
right, because the game does not have a flat rule here. What it has is a
number per monster, and this script goes and gets it.

## What this does not fix

The game's own resistance table also carries a real, sometimes large
Physical resistance (Ruin Cruiser 30%, Perpetual Mechanical Array 70%) that
this script writes down (`physicalResistance`) and the engine still cannot
use: no playable character's damage is modelled as Physical. Writing the
number is still worth doing — it is a fact, and a future fix should not have
to re-fetch it — but it is decoded and unconsumed until that gap closes.

## Usage

    python3 scripts/sync-abyss-monster-resistance.py
    python3 scripts/sync-abyss-monster-resistance.py ~/Library/Application\ Support/NSLauncher/abyss-cycles/*.json

Network access required. Matches each monster in every bundled
`abyss-monsters/*.json` (or in the files given on the command line) against `gi.yatta.moe`'s monster list, by exact name
first and then a small hand-checked alias table below (a wiki-transcribed
elite-tier name like "Battle-Hardened Chimeric Volkodlak Archer" does not
always appear verbatim in the game's own monster list, which names the base
creature). A monster this script cannot resolve is left exactly as it was —
no `gameId`, no `resistances` — and printed so a human can add an alias or
confirm there really is none to add; this script never guesses.

A monster the script *did* resolve gets every one of the seven elements
written, including the ones sitting at the 10% baseline: that a monster does
*not* specially resist Dendro is itself real information the old inference
could never state, only assume by omission.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CYCLES = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss", "abyss-monsters")

YATTA_LIST = "https://gi.yatta.moe/api/v2/en/monster"
YATTA_DETAIL = "https://gi.yatta.moe/api/v2/en/monster/{id}"

# Yatta's `resistance` field names -> our GenshinElement raw values.
ELEMENT_KEYS = {
    "fireSubHurt": "Pyro",
    "waterSubHurt": "Hydro",
    "elecSubHurt": "Electro",
    "windSubHurt": "Anemo",
    "iceSubHurt": "Cryo",
    "rockSubHurt": "Geo",
    "grassSubHurt": "Dendro",
}
PHYSICAL_KEY = "physicalSubHurt"

# A wiki-transcribed rotation name that does not appear verbatim in Yatta's
# monster list, mapped to the game id it actually is. Each entry is a
# judgement call — this is game knowledge, not a string-matching rule — so
# every one carries the reasoning and the resistance table that confirmed it,
# checked by hand against the cycle data's own `elements` field.
MONSTER_ALIASES: dict[str, int] = {
    # Cycle data: "Icewind Suite: Nemesis of Coppelius", elements
    # [Anemo, Cryo]. "Nemesis of Coppelius" is this specific rotation's title
    # for the boss, not part of its name in the game's own files. Confirmed:
    # Yatta's "Icewind Suite" (24070301) resists exactly Anemo and Cryo at
    # 70% each and nothing else, which matches the cycle data's own element
    # list precisely enough to be confident this is the same monster.
    "Icewind Suite: Nemesis of Coppelius": 24070301,
}

# Deliberately left unresolved, with the reasoning: "Battle-Hardened Chimeric
# Volkodlak Archer" (cycle data element: Cryo) has four candidate Yatta
# entries sharing the title "Volkodlak Brute" (Lobber/Basher/Raider/
# Sharpshooter). "Sharpshooter" is the archer-flavoured one by name, but none
# of the four shows any elevated resistance in Yatta's data, so there is no
# way to confirm the guess against anything — unlike the Icewind Suite alias
# above, which the resistance table itself corroborated. Guessing here would
# put an unconfirmed number in a file whose whole point is being more
# trustworthy than a guess. Left out; this monster keeps using the flat
# inference until someone can confirm it by hand (e.g. by checking its
# in-game resistance panel).


def fetch(url: str) -> dict:
    """Fetches JSON with curl — Yatta answers urllib with a 403."""
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "60", "-A",
         "ns-launcher/monster-resistance (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def resistance_table(game_id: int) -> tuple[dict[str, float], float]:
    """This monster's (elemental resistances, physical resistance), from its
    canonical entry.

    A monster's `entries` are not tiers of one thing: they are variants, and
    they do *not* all agree. Checked across every monster this rotation
    resolves: 23 of 39 have entries with different resistance tables — a
    Frostarm Lawachurl's `...49x` entries carry none of the base form's Cryo
    70% / Physical 50%, and the Oprichniki all have a `2307xxxx` entry with no
    Physical weakness next to the real `2307910x` ones at -20%. An earlier
    version of this read whichever entry the API listed first and wrote three
    Oprichniki with the wrong Physical value on the strength of a claim that
    the entries always agreed, which had been checked on exactly one monster.

    The entry whose id is the monster's own id is the base form the rotation
    data names; that is the one read. Every monster this rotation resolves has
    one; a monster that did not would be a new situation, reported rather
    than guessed around."""
    detail = fetch(YATTA_DETAIL.format(id=game_id))["data"]
    entries = detail["entries"]
    canonical = entries.get(str(game_id))
    if canonical is None:
        raise SystemExit(
            f"{detail['name']} ({game_id}): no entry carries the monster's own id — "
            f"entries are {sorted(entries)}; decide which is the base form and teach this script")
    raw = canonical["resistance"]
    elements = {name: raw[key] for key, name in ELEMENT_KEYS.items() if key in raw}
    physical = raw.get(PHYSICAL_KEY, 0.0)
    return elements, physical


def patch_line(line: str, name: str, game_id: int, elements: dict[str, float], physical: float) -> str | None:
    """Splices `gameId`/`resistances`/`physicalResistance` onto this monster's
    one-line JSON object, if `line` is that monster's line.

    A text edit, not a parse-and-reserialize: every `abyss-monsters/*.json`
    file is hand-authored one monster per line, and `json.dump` would explode
    that into several lines per field — the exact mistake this session's
    schema edits made once already, there a ~190-line diff for one real
    change. The insertion point is anchored on `"hpRatio"`, the struct's last
    field, so field order elsewhere on the line is never disturbed; a
    previous run's own insertion (if any) is matched and replaced so the
    script is safe to run again without piling up duplicates.
    """
    # `ensure_ascii=False`, or a name with a non-ASCII character would be
    # searched for as `\\u00e1` in a file that was written with the real one.
    quoted = json.dumps(name, ensure_ascii=False)
    if f'"name": {quoted}' not in line and f'"name":{quoted}' not in line:
        return None

    pattern = re.compile(
        r'("name":\s*' + re.escape(quoted) + r'.*?"hpRatio":\s*(?:null|"(?:[^"\\]|\\.)*"))'
        r'(?:,\s*"gameId":\s*\d+,\s*"resistances":\s*\{[^}]*\},\s*"physicalResistance":\s*[0-9.]+)?'
        r'(\s*\})'
    )
    if not pattern.search(line):
        return None

    resistances_json = json.dumps(elements, sort_keys=True)
    suffix = f', "gameId": {game_id}, "resistances": {resistances_json}, "physicalResistance": {physical}'
    return pattern.sub(lambda m: m.group(1) + suffix + m.group(2), line, count=1)


def main() -> int:
    by_name = {entry["name"]: int(game_id) for game_id, entry in fetch(YATTA_LIST)["data"]["items"].items()}

    # Bundled cycles by default; explicit paths (an override file dropped
    # into Application Support, say) when given, so a cycle the app reads
    # from outside the repo can be synced the same way.
    cycle_paths = sorted(os.path.abspath(p) for p in sys.argv[1:]) or sorted(
        os.path.join(CYCLES, name) for name in os.listdir(CYCLES) if name.endswith(".json")
    )
    if not cycle_paths:
        raise SystemExit(f"no cycle files found under {CYCLES}")

    resolved = 0
    unresolved: set[str] = set()
    cache: dict[int, tuple[dict[str, float], float]] = {}

    for path in cycle_paths:
        # Parsed once, read-only, to enumerate every monster name the file
        # actually holds — the file itself is edited as text below.
        with open(path, encoding="utf-8") as handle:
            names: set[str] = set()
            cycle = json.load(handle)
        for floor in cycle.get("floors", []):
            for chamber in floor.get("chambers", []):
                for wave in chamber.get("waves", []):
                    for monster in wave.get("monsters", []):
                        names.add(monster["name"])

        resolutions: dict[str, tuple[int, dict[str, float], float]] = {}
        for name in names:
            game_id = by_name.get(name) or MONSTER_ALIASES.get(name)
            if game_id is None:
                unresolved.add(name)
                continue
            if game_id not in cache:
                cache[game_id] = resistance_table(game_id)
            elements, physical = cache[game_id]
            resolutions[name] = (game_id, elements, physical)
            resolved += 1

        with open(path, encoding="utf-8") as handle:
            lines = handle.readlines()
        changed = False
        for index, line in enumerate(lines):
            for name, (game_id, elements, physical) in resolutions.items():
                patched = patch_line(line, name, game_id, elements, physical)
                if patched is not None and patched != line:
                    lines[index] = patched
                    changed = True
                    break

        if changed:
            with open(path, "w", encoding="utf-8") as handle:
                handle.writelines(lines)
            print(f"wrote {os.path.basename(path)}")

    print(f"resolved {resolved} distinct monster names against {len(cache)} distinct game ids")
    if unresolved:
        print(f"unresolved ({len(unresolved)}), left on the flat inference:", file=sys.stderr)
        for name in sorted(unresolved):
            print(f"  {name}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
