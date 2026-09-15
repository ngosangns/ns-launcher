#!/usr/bin/env python3
"""Writes how much HP each Abyss half holds: every monster's spawn count and
HP scaling into Resources/Abyss/abyss-monsters/*.json, each floor's Spiral
Abyss HP multiplier, and the wiki's HP-by-level table into
Resources/Abyss/enemy-hp.json.

## Why this exists

Phase 6 of docs/redesign.md scores a floor by how long it takes to clear. A
plan used to be ranked on the harmonic mean of its two half scores, which is
"minimise t₁ + t₂" only if both halves hold the same HP — an assumption the
data could not check because it recorded no HP at all. This script records it.

## Where the numbers come from

- **Spawn counts**: the cycle's page on the Genshin Impact wiki
  (`Spiral Abyss/Floors/<periodStart>`), whose `Domain Enemies` template
  writes each half as `Name*count`, sub-waves split by `//`. The cycle files'
  own `count` field is a prose transcription ("1 rồi 1 (≈8 tổng cả đợt)") and
  is not read.
- **HP scaling**: the monster's wiki page, `Enemy Stats` template —
  `hp_ratio` and `hp_type` per variant (Normal, Battle-Hardened, Local Legend).
  The variant matters: this rotation's Battle-Hardened Chimeric Volkodlak
  Archer is a Voywolf Hunter at 7× the Normal HP, and gi.yatta.moe carries no
  Battle-Hardened entry at all. HP at a level is `hp_ratio × table[type][level]`,
  the table being `Module:Enemy Stats/HP` — which is the game's monster HP
  curve times 13.584, checked below against Yatta for every monster that has a
  `gameId`.
- **Floor multiplier**: the wiki's Spiral Abyss page, "Enemy HP" section
  ("Floor 12: HP 250% vs open world").

## What is refused

A wiki name that matches no monster line (or a line no wiki name), a monster
page without an `Enemy Stats` block for the variant its name asks for, a page
with several variants and a name that does not say which, a cycle page that
mentions an HP amendment, or a Yatta cross-check that disagrees by more than
1% — each stops that floor from being written and is printed. A floor without
HP keeps the equal-HP assumption in the engine.

## Usage

    python3 scripts/sync-abyss-monster-hp.py [cycle.json ...]

Network access required.
"""

from __future__ import annotations

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.parse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
CYCLES = os.path.join(DATA, "abyss-monsters")
TABLE = os.path.join(DATA, "enemy-hp.json")
WIKI = "https://genshin-impact.fandom.com/api.php"
YATTA = "https://gi.yatta.moe/api/v2"
UA = "ns-launcher/monster-hp (github.com/ngosangns/ns-launcher)"
PROBLEMS: list[str] = []
CHECKED: list[str] = []


def fetch(url: str) -> dict:
    for _ in range(3):
        result = subprocess.run(["curl", "-sSL", "--max-time", "60", "-A", UA, url],
                                capture_output=True, text=True)
        try:
            return json.loads(result.stdout)
        except ValueError:
            continue
    sys.exit(f"could not read {url}")


def wikitext(page: str) -> tuple[str, str, int] | None:
    query = urllib.parse.urlencode({"action": "parse", "page": page, "prop": "wikitext|revid",
                                    "redirects": 1, "format": "json"})
    data = fetch(f"{WIKI}?{query}")
    if "parse" not in data:
        return None
    parse = data["parse"]
    return parse["wikitext"]["*"], parse["title"], parse["revid"]


# MARK: - Tables


def hp_table() -> tuple[dict[str, dict[int, float]], int]:
    text, _, revid = wikitext("Module:Enemy Stats/HP")
    table: dict[str, dict[int, float]] = {}
    current = None
    for line in text.splitlines():
        if m := re.match(r"\s*\['(\w+)'\]\s*=\s*\{\s*$", line):
            current = m.group(1)
            table[current] = {}
        elif current and (m := re.match(r"\s*\['(\d+)'\]\s*=\s*'([\d.]+)'", line)):
            table[current][int(m.group(1))] = float(m.group(2))
    if not table:
        sys.exit("Module:Enemy Stats/HP did not parse")
    return table, revid


def floor_multipliers() -> tuple[dict[int, float], int]:
    text, _, revid = wikitext("Spiral Abyss")
    section = text[text.index("===Enemy HP==="):]
    multipliers: dict[int, float] = {}
    for m in re.finditer(r"Floors? (\d+)(?:&ndash;|–|-)?(\d+)?: HP (\d+)% vs open world", section):
        low, high = int(m.group(1)), int(m.group(2) or m.group(1))
        for floor in range(low, high + 1):
            multipliers[floor] = int(m.group(3)) / 100
    if not multipliers:
        sys.exit("Spiral Abyss 'Enemy HP' section did not parse")
    return multipliers, revid


# MARK: - A cycle page


def domain_enemies(text: str) -> dict[int, dict[int, dict[int, dict[str, int]]]]:
    """floor -> chamber -> half -> {wiki name: count}."""
    floors: dict[int, dict[int, dict[int, dict[str, int]]]] = {}
    parts = re.split(r"(?m)^===Floor (\d+)===\s*$", text)
    for index in range(1, len(parts), 2):
        floor = int(parts[index])
        body = parts[index + 1]
        if re.search(r"(?i)\bHP\b", body.split("{{Domain Enemies")[0]):
            PROBLEMS.append(f"floor {floor}: the cycle page mentions HP outside the enemy list — "
                            "an amendment to check by hand")
        chambers: dict[int, dict[int, dict[str, int]]] = {}
        # An editor's comment on a count is a count the editor doubts.
        for comment in re.findall(r"<!--(.*?)-->", body, re.S):
            if re.search(r"(?i)unsure|not sure|\?", comment):
                PROBLEMS.append(f"floor {floor}: a count is marked uncertain on the wiki ({comment.strip()})")
                floors[floor] = {}
                break
        else:
            floors[floor] = chambers
        if floors[floor] is not chambers:
            continue
        body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
        for m in re.finditer(r"\|enemies(\d+)_(\d+)\s*=\s*([^\n|]*)", body):
            chamber, half = int(m.group(1)), int(m.group(2))
            counts: dict[str, int] = {}
            for group in m.group(3).split("//"):
                for item in group.split(";"):
                    item = item.strip()
                    if not item:
                        continue
                    name, _, count = item.partition("*")
                    counts[name.strip()] = counts.get(name.strip(), 0) + int(count or 1)
            chambers.setdefault(chamber, {})[half] = counts
    return floors


def match(wiki_names: dict[str, int], lines: list[str]) -> dict[str, str] | None:
    """Cycle line name -> wiki name. A wiki name may add a title after " - "
    ("Iniquitous Baptist - Invoker of Fire, Frost, and Fulmination")."""
    result: dict[str, str] = {}
    unused = set(wiki_names)
    for name in lines:
        candidates = [w for w in unused if w == name]
        if not candidates:
            candidates = [w for w in unused if w.startswith(name + " - ") or w.startswith(name + ": ")]
        if len(candidates) != 1:
            return None
        result[name] = candidates[0]
        unused.discard(candidates[0])
    return result if not unused else None


# MARK: - A monster page

STATS = re.compile(r"\{\{Enemy Stats(.*?)\}\}", re.S)


def scaling(wiki_name: str, cache: dict) -> dict | None:
    if wiki_name in cache:
        return cache[wiki_name]
    variant_hint = "Battle-Hardened" if wiki_name.startswith("Battle-Hardened ") else None
    page = wikitext(wiki_name)
    if page is None and " - " in wiki_name:
        page = wikitext(wiki_name.split(" - ")[0])
    if page is None:
        PROBLEMS.append(f"{wiki_name}: no wiki page")
        cache[wiki_name] = None
        return None
    text, title, revid = page
    blocks = []
    stats_at = text.find("==Stats==")
    for m in STATS.finditer(text):
        # Variant headings live under "==Stats==": the "===Energy===" above it
        # is not a variant.
        scope = text[stats_at:m.start()] if 0 <= stats_at < m.start() else ""
        heading = re.findall(r"(?m)^===\s*([^=]+?)\s*===\s*$", scope)
        fields = dict(re.findall(r"\|\s*(\w+)\s*=\s*([^\n|]*)", m.group(1)))
        if "hp_ratio" in fields:
            blocks.append((heading[-1] if heading else "", fields))
    chosen = None
    if variant_hint:
        chosen = next((b for b in blocks if b[0] == variant_hint), None)
    elif len({b[1]["hp_ratio"] for b in blocks if b[0] not in ("Local Legend",)}) == 1:
        chosen = blocks[0]
    elif blocks and blocks[0][0] in ("Normal", ""):
        chosen = blocks[0]
    if chosen is None:
        PROBLEMS.append(f"{wiki_name}: page {title} has variants {[b[0] for b in blocks]} and the name picks none")
        cache[wiki_name] = None
        return None
    heading, fields = chosen
    entry = {"page": title, "variant": heading or "Normal", "ratio": float(fields["hp_ratio"]),
             "type": fields.get("hp_type", "1").strip() or "1", "revid": revid}
    cache[wiki_name] = entry
    return entry


def cross_check(game_id: int | None, entry: dict, table: dict, curves: dict, level: int) -> None:
    if game_id is None or entry["variant"] != "Normal":
        return
    monster = fetch(f"{YATTA}/en/monster/{game_id}")["data"]["entries"].get(str(game_id))
    if monster is None:
        return
    prop = next(p for p in monster["prop"] if p["propType"] == "FIGHT_PROP_BASE_HP")
    game = prop["initValue"] * curves[str(level)]["curveInfos"][prop["type"]]
    wiki = entry["ratio"] * table[entry["type"]][level]
    CHECKED.append(entry["page"])
    if abs(game - wiki) > 0.01 * game:
        PROBLEMS.append(f"{entry['page']}: wiki HP {wiki:.0f} at level {level} disagrees with the game's {game:.0f}")


# MARK: - Writing


def rewrite(path: str, floors_hp: dict, spawn: dict, hp: dict, multipliers: dict) -> None:
    with open(path) as handle:
        lines = handle.read().split("\n")
    floor = chamber = wave = None
    out = []
    for line in lines:
        if m := re.match(r'\s*"chamber": (\d+),', line):
            chamber = int(m.group(1))
        if m := re.match(r'\s*"wave": (\d+),', line):
            wave = int(m.group(1))
        if m := re.match(r'(\s*)"floor": (\d+),\s*$', line):
            floor = int(m.group(2))
            out.append(line)
            if floor in floors_hp:
                out.append(f'{m.group(1)}"enemyHPMultiplier": {multipliers[floor]:g},')
            continue
        if re.match(r'\s*"enemyHPMultiplier":', line):
            continue
        if floor in floors_hp and (m := re.match(r'(\s*\{ "name": )("[^"]*")(.*?)( \},?\s*)$', line)):
            name = json.loads(m.group(2))
            key = (floor, chamber, wave, name)
            rest = re.sub(r', "spawns": \d+', "", m.group(3))
            rest = re.sub(r', "hp": \{[^}]*\}', "", rest)
            if key in spawn:
                rest += f', "spawns": {spawn[key]}, "hp": {json.dumps(hp[key], ensure_ascii=False)}'
            line = m.group(1) + m.group(2) + rest + m.group(4)
        out.append(line)
    with open(path, "w") as handle:
        handle.write("\n".join(out))


def main() -> None:
    paths = sys.argv[1:] or sorted(os.path.join(CYCLES, name) for name in os.listdir(CYCLES)
                                   if name.endswith(".json"))
    table, table_revid = hp_table()
    multipliers, abyss_revid = floor_multipliers()
    curves = fetch(f"{YATTA}/static/monsterCurve")["data"]
    cache: dict = {}

    with open(TABLE, "w") as handle:
        lines = ["{"]
        lines.append('  "_doc": ' + json.dumps(
            "Monster HP by level, per HP scaling type: the Genshin Impact wiki's Module:Enemy Stats/HP "
            "(the game's monster HP curve × 13.584; scripts/sync-abyss-monster-hp.py checks it against "
            "gi.yatta.moe). A monster's HP is its wiki hp_ratio × this table at its level × the floor's "
            "enemyHPMultiplier. Generated — do not edit.", ensure_ascii=False) + ",")
        lines.append(f'  "source": "https://genshin-impact.fandom.com/wiki/Module:Enemy_Stats/HP?oldid={table_revid}",')
        lines.append(f'  "fetchedOn": "{datetime.date.today().isoformat()}",')
        lines.append('  "types": {')
        items = sorted(table.items(), key=lambda item: item[0])
        for index, (kind, levels) in enumerate(items):
            values = [levels[level] for level in sorted(levels)]
            comma = "," if index < len(items) - 1 else ""
            lines.append(f'    "{kind}": {json.dumps(values)}{comma}')
        lines.append("  }")
        lines.append("}")
        handle.write("\n".join(lines) + "\n")

    for path in paths:
        with open(path) as handle:
            cycle = json.load(handle)
        page = wikitext(f"Spiral Abyss/Floors/{cycle['periodStart']}")
        if page is None:
            PROBLEMS.append(f"{os.path.basename(path)}: no wiki page for {cycle['periodStart']}")
            continue
        enemies = domain_enemies(page[0])
        spawn: dict = {}
        hp: dict = {}
        written: set[int] = set()
        for floor in cycle["floors"]:
            number = floor["floor"]
            ok = number in enemies and number in multipliers
            floor_spawn, floor_hp = {}, {}
            for chamber in floor["chambers"]:
                waves = sorted(chamber["waves"], key=lambda wave: wave["wave"])
                for half, wave in enumerate(waves, start=1):
                    number_wave = wave["wave"]
                    wiki = enemies.get(number, {}).get(chamber["chamber"], {}).get(half)
                    names = [monster["name"] for monster in wave["monsters"]]
                    pairs = match(wiki, names) if wiki else None
                    if pairs is None:
                        PROBLEMS.append(f"floor {number} chamber {chamber['chamber']} half {half}: "
                                        f"cycle {names} vs wiki {wiki}")
                        ok = False
                        continue
                    for monster in wave["monsters"]:
                        entry = scaling(pairs[monster["name"]], cache)
                        if entry is None:
                            ok = False
                            continue
                        cross_check(monster.get("gameId"), entry, table, curves, chamber["monsterLevel"])
                        key = (number, chamber["chamber"], number_wave, monster["name"])
                        floor_spawn[key] = wiki[pairs[monster["name"]]]
                        floor_hp[key] = {k: entry[k] for k in ("page", "variant", "ratio", "type")}
            if ok:
                spawn.update(floor_spawn)
                hp.update(floor_hp)
                written.add(number)
        rewrite(path, written, spawn, hp, multipliers)
        print(f"{os.path.basename(path)}: floors written {sorted(written)} "
              f"(cycle page revid {page[2]}, Spiral Abyss revid {abyss_revid})")

    print(f"HP checked against gi.yatta.moe for {len(set(CHECKED))} monsters")
    for problem in PROBLEMS:
        print("  !", problem)


if __name__ == "__main__":
    main()
