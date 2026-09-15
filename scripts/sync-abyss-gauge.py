#!/usr/bin/env python3
"""Writes Resources/Abyss/gauge.json: the elemental gauge and internal cooldown of
every hit in each character's three combat talents, from gi.yatta.moe.

## Why this exists

Phase 4 of docs/redesign.md prices reactions from how often each member
applies their element, instead of a flat `amplifyingUptime` on every hit and
`transformativeReactionsPerRotation` for every team. The gcsim benchmark put
numbers on what the constants cost: Melt and Vaporize teams over-rated by
+0.16 to +0.25, Dendro+Electro teams under-rated by -0.20 to -0.28 because
Aggravate and Spread were never priced at all.

How often a hit applies its element is game data. Yatta's avatar API carries
it per talent, under `advancedProps`: one row per hit, with its gauge
("1U", "2U", "1U(w/ Dropoff)") and internal cooldown — a tag the hit shares
("Normal Attack", "Elemental Skill") and a rule ("2.5s/3 Hits", "0.5s").
A row reading "rowspan" shares the cooldown of the row above it.

## What is written

Per character, per talent, the rows verbatim (name, gauge text, ICD tag and
rule) and the parsed values: `units` (0 for "—" and "0U"), `icdTag` with
"rowspan" resolved to the tag above, `icdHits` and `icdSeconds`. A rule outside the two shapes the game uses almost
everywhere ("10s/1st, 3rd, 5th Hits Apply Element") keeps its text in
`icdRule`, parses to nulls, and is listed under `unrecognisedIcdRules` —
the Swift side reports those rows rather than guessing a rule. Rows that
describe no hit on an enemy — self auras ("Pyro To Self"), knockbacks — are
kept with `units` 0 so the file stays a mirror of the source. A gauge or ICD
text the parser does not recognise stops the script.

## Usage

    python3 scripts/sync-abyss-gauge.py

Network access required (one request per character with structured talents).
"""

from __future__ import annotations

import collections
import datetime
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
OUTPUT = os.path.join(DATA, "gauge.json")
YATTA = "https://gi.yatta.moe/api/v2/en/avatar/{id}"
UA = "ns-launcher/gauge (github.com/ngosangns/ns-launcher)"
UNRECOGNISED: list[str] = []
SLOTS = ("normalAttack", "elementalSkill", "elementalBurst")


def fetch(url: str) -> dict:
    result = subprocess.run(["curl", "-sSL", "--max-time", "60", "-A", UA, url], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def units(text: str | None, where: str) -> float:
    """'1U', '1.5U', '2U(w/ Dropoff)', '1U, 2.1s' (a timed self aura), '1' → units; '—', '0U' → 0."""
    if text is None:
        return 0.0
    cleaned = text.strip()
    if cleaned in ("—", "-", "", "0U", "0"):
        return 0.0
    match = re.fullmatch(r"(\d+(?:\.\d+)?)U?(?:\s*\(w/ Dropoff\))?(?:,\s*\d+(?:\.\d+)?s)?", cleaned)
    if not match:
        raise SystemExit(f"{where}: unrecognised gauge {text!r}")
    return float(match.group(1))


def icd_rule(text: str | None, where: str) -> tuple[int | None, float | None]:
    """'2.5s/3 Hits' → (3, 2.5); '0.5s' → (None, 0.5); '—'/None → (None, None)."""
    if text is None or text.strip() in ("—", "-", "", "No ICD"):
        return None, None
    cleaned = text.strip()
    match = re.fullmatch(r"(\d+(?:\.\d+)?)s\s*/\s*(\d+)\s*Hits?", cleaned)
    if match:
        return int(match.group(2)), float(match.group(1))
    match = re.fullmatch(r"(\d+(?:\.\d+)?)s", cleaned)
    if match:
        return None, float(match.group(1))
    UNRECOGNISED.append(f"{where}: {cleaned}")
    return None, None


def combat_talents(avatar: dict) -> dict[str, dict]:
    """Same selection as sync-abyss-talent-params.py: the two type-0 talents
    with a level-10 table (normal attack, then skill) and the type-1 burst."""
    def has_table(talent: dict) -> bool:
        level_ten = talent.get("promote", {}).get("10")
        return bool(level_ten and any(line.strip() for line in level_ten["description"]))
    levelled = [t for _, t in sorted(avatar["talent"].items(), key=lambda kv: int(kv[0])) if has_table(t)]
    type_zero = [t for t in levelled if t["type"] == 0]
    bursts = [t for t in levelled if t["type"] == 1]
    if len(type_zero) != 2 or len(bursts) != 1:
        raise SystemExit(f"{avatar['name']}: unexpected talent layout")
    return dict(zip(SLOTS, [type_zero[0], type_zero[1], bursts[0]]))


def rows(talent: dict, where: str) -> list[dict]:
    out = []
    tag = None
    hits: int | None = None
    seconds: float | None = None
    for row in talent.get("advancedProps") or []:
        icd = row.get("internalCooldown")
        if icd == "rowspan":
            pass  # shares the row above
        elif isinstance(icd, dict):
            tag = ((icd.get("tag") or {}).get("text") or "").strip() or None
            if tag == "—":
                tag = None
            hits, seconds = icd_rule((icd.get("type") or {}).get("text"), f"{where} {row['name']}")
        else:
            tag, hits, seconds = None, None, None
        rule = None
        if icd == "rowspan":
            rule = out[-1]["icdRule"] if out else None
        elif isinstance(icd, dict):
            rule = ((icd.get("type") or {}).get("text") or "").strip() or None
        out.append(collections.OrderedDict([
            ("name", row["name"]),
            ("gauge", row.get("elementalGaugeTheory")),
            ("units", units(row.get("elementalGaugeTheory"), f"{where} {row['name']}")),
            ("icdTag", tag), ("icdRule", rule), ("icdHits", hits), ("icdSeconds", seconds),
        ]))
    return out


def main() -> int:
    with open(os.path.join(DATA, "game-ids.json"), encoding="utf-8") as handle:
        by_game_id = json.load(handle)["characters"]
    characters = {}
    for game_id, slug in sorted(by_game_id.items(), key=lambda kv: kv[1]):
        avatar = fetch(YATTA.format(id=game_id))["data"]
        talents = combat_talents(avatar)
        characters[slug] = collections.OrderedDict(
            (slot, rows(talent, f"{slug} {slot}")) for slot, talent in talents.items())
        print(f"  {slug}: {sum(len(v) for v in characters[slug].values())} rows")
    output = collections.OrderedDict([
        ("_doc", "Gauge nguyên tố và ICD của từng hit trong ba talent chiến đấu, từ gi.yatta.moe (talent.advancedProps). "
                 "SINH TỰ ĐỘNG bằng scripts/sync-abyss-gauge.py — đừng sửa tay. units: số U (0 = không áp nguyên tố); "
                 "icdTag/icdHits/icdSeconds: nhóm ICD và luật của nó ('2.5s/3 Hits' → 3, 2.5), 'rowspan' đã quy về dòng trên. "
                 "Dùng ở Pha 4 docs/redesign.md để đếm số lần áp nguyên tố mỗi rotation."),
        ("source", "gi.yatta.moe/api/v2/en/avatar/{id} → talent[*].advancedProps"),
        ("fetchedOn", datetime.date.today().isoformat()),
        ("unrecognisedIcdRules", UNRECOGNISED),
        ("characters", characters),
    ])
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print(f"wrote {len(characters)} characters to {os.path.relpath(OUTPUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
