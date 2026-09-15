#!/usr/bin/env python3
"""Writes Resources/Abyss/passive-text.json: the game's English text of every
weapon passive (with its numbers at each refinement) and every artifact set
bonus, from gi.yatta.moe.

## Why this exists

Phase 5 of docs/redesign.md replaces three guesses with a timeline:
`conditionalUptime` (every qualified bonus at 60%), `assumedStacks` (every
"per stack" line at 2.5 stacks) and `setEffectApprox` (34 hand-estimated %DMG
figures for four-piece sets). A timeline needs to know, per effect, what starts
it and for how long. That is written in the game text and nowhere in the weapon
data the app had, whose effect lines were a prose summary: The Catch at 12%
Burst DMG where the game says 16%, Kitain Cross Spear carrying another weapon's
lines, The Widsith, The Stringless and Wandering Evenstar with no lines at all.

## Split: text here, meaning in passives.json

What an effect *means* — which stat, what triggers it, for whom — is written
by hand in Resources/Abyss/passives.json, the way character-kits.json writes a
kit. A parser for the prose was tried first and got the meaning quietly wrong
in the way that matters ("Taking DMG disables this effect for 5s" read as a 5s
buff). What an effect is *worth* comes from here: a passives.json value is the
R1 number, and the Swift side finds the column of this file whose R1 it is and
reads R2–R5 from that column. A value that is in no column, or a duration or
stack count that is not in the text, is reported — never guessed.

## What is written

Per weapon: `text` (R1, tags removed) and `values`, one column per number the
game tags as changing with refinement, R1–R5, as fractions for percentages.
The wording is read from R1: the game's own text drifts between refinements
("opponents" / "opponent"), but the tagged numbers line up by position; a
refinement with a different count of them is listed under `unaligned`.
Per artifact set: `twoPiece` and `fourPiece` text.

## Usage

    python3 scripts/sync-abyss-passives.py [--cache DIR]

Network access required (one request per weapon and per artifact set).
`--cache` keeps the raw responses so the file can be rebuilt offline.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
OUTPUT = os.path.join(DATA, "passive-text.json")
YATTA = "https://gi.yatta.moe/api/v2/en/{kind}/{id}"
UA = "ns-launcher/passives (github.com/ngosangns/ns-launcher)"
TAG = re.compile(r"<color=[^>]*>(.*?)</color>")


def fetch(kind: str, identifier: str, cache: str | None) -> dict:
    path = os.path.join(cache, f"{kind}-{identifier}.json") if cache else None
    if path and os.path.exists(path):
        with open(path) as handle:
            return json.load(handle)
    url = YATTA.format(kind=kind, id=identifier)
    for _ in range(3):
        result = subprocess.run(["curl", "-sSL", "--max-time", "60", "-A", UA, url],
                                capture_output=True, text=True)
        try:
            data = json.loads(result.stdout)["data"]
            break
        except (ValueError, KeyError, TypeError):
            continue
    else:
        sys.exit(f"could not read {url}")
    if path:
        os.makedirs(cache, exist_ok=True)
        with open(path, "w") as handle:
            json.dump(data, handle)
    return data


def clean(text: str) -> str:
    text = text.replace("\\n", " ").replace("\n", " ")
    return re.sub(r"\s+", " ", text).strip()


def number(text: str) -> float | None:
    """A tagged value: "16%" → 0.16, "1,000" → 1000. Tags that hold more than
    one number ("8/16/28%", "7.5%/12.5%/17.5%") are not a single value."""
    text = text.strip().replace(",", "")
    match = re.fullmatch(r"(\d+(?:\.\d+)?)(%?)", text)
    if not match:
        return None
    value = float(match.group(1))
    return round(value / 100, 8) if match.group(2) else value


def weapon_entry(affix: dict) -> dict:
    upgrade = next(iter(affix.values()))["upgrade"]
    texts = [clean(text) for _, text in sorted(upgrade.items(), key=lambda item: int(item[0]))]
    tagged = [TAG.findall(text) for text in texts]
    entry = {"text": TAG.sub(r"\1", texts[0])}
    if any(len(row) != len(tagged[0]) for row in tagged):
        entry["unaligned"] = [TAG.sub(r"\1", text) for text in texts]
        entry["values"] = []
        return entry
    columns = []
    for k in range(len(tagged[0])):
        column = [number(row[k]) for row in tagged]
        # A tag holding a list of numbers is kept as its strings: a hand entry
        # cannot reference it by value, and saying so is the point.
        columns.append(column if all(v is not None for v in column) else [row[k] for row in tagged])
    entry["values"] = columns
    return entry


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache")
    arguments = parser.parse_args()

    with open(os.path.join(DATA, "game-ids.json")) as handle:
        ids = json.load(handle)

    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        weapon_data = dict(zip(ids["weapons"].values(),
                               pool.map(lambda g: fetch("weapon", g, arguments.cache), ids["weapons"].keys())))
        set_data = dict(zip(ids["artifactSets"].values(),
                            pool.map(lambda g: fetch("reliquary", g, arguments.cache),
                                     ids["artifactSets"].keys())))

    weapons = {slug: weapon_entry(data["affix"]) for slug, data in sorted(weapon_data.items())
               if data.get("affix")}
    sets = {}
    for slug, data in sorted(set_data.items()):
        bonuses = [clean(text) for _, text in sorted((data.get("affixList") or {}).items())]
        if not bonuses:
            continue
        sets[slug] = ({"fourPiece": bonuses[0]} if len(bonuses) == 1
                      else {"twoPiece": bonuses[0], "fourPiece": bonuses[-1]})

    lines = ["{"]
    lines.append('  "_doc": ' + json.dumps(
        "The game's English text for every weapon passive and artifact set bonus, from gi.yatta.moe. "
        "Generated by scripts/sync-abyss-passives.py — do not edit. `values` holds one column per number "
        "the game tags as changing with refinement, R1–R5, percentages as fractions; a column of strings "
        "is a tag holding several numbers. passives.json writes what each effect means and references "
        "these columns by their R1 value; AbyssPassiveTests pins that every reference resolves.",
        ensure_ascii=False) + ",")
    lines.append('  "source": "https://gi.yatta.moe/api/v2/en/weapon/{id}, /reliquary/{id}",')
    lines.append(f'  "fetchedOn": "{datetime.date.today().isoformat()}",')
    for group, items in (("weapons", weapons), ("sets", sets)):
        lines.append(f'  "{group}": {{')
        for index, (slug, entry) in enumerate(items.items()):
            comma = "," if index < len(items) - 1 else ""
            lines.append(f"    {json.dumps(slug)}: {json.dumps(entry, ensure_ascii=False)}{comma}")
        lines.append("  }" + ("," if group == "weapons" else ""))
    lines.append("}")
    with open(OUTPUT, "w") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"{len(weapons)} weapons, {len(sets)} sets; "
          f"{sum(1 for e in weapons.values() if 'unaligned' in e)} weapons with unaligned refinements")


if __name__ == "__main__":
    main()
