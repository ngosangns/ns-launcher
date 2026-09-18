#!/usr/bin/env python3
"""Writes Tests/NSLauncherAppTests/Fixtures/gcsim-benchmark.json: team DPS from
gcsim's public database, for checking the planner's ranking against a
simulator rather than against its own past output.

## Why this exists

`abyss-golden.json` proves the engine today matches the engine yesterday. It
has never shown the engine matches the game, and on 2026-09-16 that gap had a
cost: set bonuses routed into every hit made Scarlet Proof the best set for 95
of 125 characters, and nothing noticed, because the fixture only ever looked at
a 15-character roster.

gcsim (github.com/genshinsim/gcsim) is a frame-level simulator, and
gcsim.app keeps a curated database of submitted team configurations, each run
to a mean DPS. Its API (`/api/db`, routed in backend/pkg/api/server.go) is
public. This script reads every valid entry and keeps, for each four-character
team fought against one target, the best-DPS configuration: the members, their
constellations, weapons and refinements, and the DPS. What it does not keep is
anything about who submitted it.

The planner is not expected to reproduce these numbers — the database's builds,
constellations and rotations differ from the planner's modelled ones. What it
is expected to reproduce, roughly, is the *order*: which teams are stronger
than which. `AbyssBenchmarkTests` measures that.

## Mapping

Characters by game id: gcsim's `ui/packages/db/src/Data/character.dm.json`
(pinned commit) gives each key's avatar id, `game-ids.json` gives our slug.
Weapons by name: gcsim's key is the English name lowercased with everything
but letters and digits removed, and so is ours after the same normalisation.
The Travelers are skipped (gcsim keys them by depot). A name that does not
map is reported and its entries dropped, never guessed.

## Usage

    python3 scripts/sync-abyss-benchmark.py

Network access required (gcsim.app, ~60 paged requests, and one file from
raw.githubusercontent.com).
"""

from __future__ import annotations

import collections
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
OUTPUT = os.path.join(REPO, "Tests", "NSLauncherAppTests", "Fixtures", "gcsim-benchmark.json")
UA = "ns-launcher/benchmark (github.com/ngosangns/ns-launcher)"
GCSIM_COMMIT = "a086a05f8bbd7cac08aee3500a952ec30cd3017f"
CHARACTER_DM = (f"https://raw.githubusercontent.com/genshinsim/gcsim/{GCSIM_COMMIT}"
                "/ui/packages/db/src/Data/character.dm.json")
DB = "https://gcsim.app/api/db"


def curl(*args: str) -> str:
    result = subprocess.run(["curl", "-sS", "--compressed", "--max-time", "120", "-A", UA, *args],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"curl failed: {result.stderr.strip()}")
    return result.stdout


def page(skip: int) -> list[dict]:
    query = json.dumps({
        "query": {"is_db_valid": True}, "limit": 100, "skip": skip, "sort": {"_id": 1},
        "project": {"_id": 1, "summary.mean_dps_per_target": 1, "summary.target_count": 1,
                    "summary.team": 1},
    })
    for attempt in range(6):
        text = curl("-G", DB, "--data-urlencode", "q=" + query)
        try:
            return json.loads(text).get("data", [])
        except json.JSONDecodeError:
            time.sleep(3 * (attempt + 1))
    raise SystemExit(f"gcsim.app returned no JSON at skip {skip}")


def normalise(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def main() -> int:
    with open(os.path.join(DATA, "game-ids.json"), encoding="utf-8") as handle:
        slug_by_id = json.load(handle)["characters"]
    character_dm = json.loads(curl("-L", CHARACTER_DM))
    character_dm = character_dm.get("data", character_dm)
    slug_by_key = {key: slug_by_id[str(entry["id"])] for key, entry in character_dm.items()
                   if str(entry["id"]) in slug_by_id}
    weapon_by_name = {}
    for path in glob.glob(os.path.join(DATA, "weapons", "*.json")):
        with open(path, encoding="utf-8") as handle:
            for weapon in json.load(handle):
                weapon_by_name[normalise(weapon["name"])] = weapon["id"]

    rows, skip = [], 0
    while True:
        batch = page(skip)
        rows += batch
        skip += 100
        if len(batch) < 100:
            break
        time.sleep(0.7)

    unmapped = collections.Counter()
    best: dict[tuple[str, ...], dict] = {}
    entries = collections.Counter()
    for row in rows:
        summary = row["summary"]
        if summary.get("target_count") != 1 or len(summary.get("team", [])) != 4:
            continue
        members, ok = [], True
        for member in summary["team"]:
            slug = slug_by_key.get(member["name"])
            weapon = weapon_by_name.get(normalise(member["weapon"]["name"]))
            if slug is None:
                unmapped[f"character {member['name']}"] += 1
                ok = False
            if weapon is None:
                unmapped[f"weapon {member['weapon']['name']}"] += 1
                ok = False
            members.append(collections.OrderedDict([
                ("id", slug), ("constellation", member.get("cons", 0)),
                ("weapon", weapon), ("refinement", member["weapon"].get("refine", 1)),
            ]))
        if not ok:
            continue
        key = tuple(sorted(m["id"] for m in members))
        entries[key] += 1
        dps = summary["mean_dps_per_target"]
        if key not in best or dps > best[key]["dps"]:
            best[key] = collections.OrderedDict([
                ("dbId", row["_id"]), ("dps", round(dps, 1)),
                ("members", sorted(members, key=lambda m: m["id"])),
            ])

    teams = []
    for key in sorted(best):
        team = best[key]
        team["entries"] = entries[key]
        teams.append(team)

    output = collections.OrderedDict([
        ("_doc", "Team DPS from gcsim.app's public database (single target, four characters), best "
                 "configuration per team. Generated by scripts/sync-abyss-benchmark.py — do not edit. "
                 "Used by AbyssBenchmarkTests to compare the planner's team ORDER with a frame-level "
                 "simulator's; the numbers themselves are not expected to match."),
        ("source", DB + " (gcsim, github.com/genshinsim/gcsim); character ids from " + CHARACTER_DM),
        ("fetchedOn", datetime.date.today().isoformat()),
        ("databaseEntries", len(rows)),
        ("unmapped", dict(sorted(unmapped.items()))),
        ("teams", teams),
    ])
    # One team per line: 4,000 teams at `indent=1` is 2 MB of mostly
    # whitespace, and a line per team keeps a regeneration's diff readable.
    teams_json = output.pop("teams")
    head = json.dumps(output, ensure_ascii=False, indent=1)
    body = ",\n".join("  " + json.dumps(team, ensure_ascii=False, separators=(",", ":"))
                       for team in teams_json)
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        handle.write(head[:-2] + ',\n "teams": [\n' + body + "\n ]\n}\n")
    print(f"wrote {len(teams)} teams from {len(rows)} entries; unmapped: {dict(unmapped)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
