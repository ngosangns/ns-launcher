#!/usr/bin/env python3
"""Writes Resources/Abyss/talent-params.json: every character's talent
multipliers as the game states them, at every level, from gi.yatta.moe.

## Why this exists

`characters/*.json` carries each talent's scaling table as wiki-transcribed
prose — a Vietnamese label and a string like `"172.53% DEF"` per level — and
`AbyssTextParser` turns that back into numbers with twenty-six regexes. It is
the most fragile thing in the model, and checking it against the game's own
files on one character (Hu Tao) found three transcription errors at once: an
ATK *buff* counted as a hit, two simultaneous hits read as alternatives, and a
charged-attack multiplier copied from the wrong row.

The game's files already hold every talent as structured data: a list of
`Label|{paramN:FMT}` lines and a `params` array per level. The label is the
game's own English ("Blood Blossom DMG", "Charged Attack Stamina Cost"), the
format says what kind of number it is (`P`/`F1P`/`F2P` are percentages), and
a suffix after the placeholder names the scaling stat (" Max HP", " DEF",
" Elemental Mastery"; none means ATK). None of that needs a regex over prose —
it needs a small grammar over a closed vocabulary, which is what
`AbyssTalentReader` is.

This script writes the game's data down **verbatim**: the description lines
as the game phrases them and the raw `params` per level. No classification
happens here. Which rows are damage, which are alternatives of one another,
and how "5-Hit DMG|{param5:F1P}+{param6:F1P}" adds up is decided in Swift,
where every rule is a test — so a wrong reading is a red test, not a wrong
number in a data file.

All fifteen levels are kept, not just the one the model scores at. The
seven-line-per-level cost is a few hundred KB, and it means a showcase's real
talent levels, or a C3/C5 talent boost, can be read for any character rather
than only the ones whose prose happened to carry an `lv13` column.

## Not covered

The seven Traveler variants share one Yatta avatar with per-element skill
depots, and `game-ids.json` maps them by depot rather than by avatar id. They
have no entry here and keep the prose path — `AbyssDataLibrary` falls back
per character, so nothing else changes for them.

## Usage

    python3 scripts/sync-abyss-talent-params.py

Network access required (118 requests, one per non-Traveler character).
Refuses to write if any mapped character fails to fetch or comes back without
the three combat talents, so the file is never half game data and half stale.
"""

from __future__ import annotations

import collections
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
GAME_IDS = os.path.join(DATA, "game-ids.json")
OUTPUT = os.path.join(DATA, "talent-params.json")

YATTA = "https://gi.yatta.moe/api/v2/en/avatar/{id}"

# Yatta's `type` on a talent: 0 for the normal attack *and* the skill (the
# first type-0 entry is the normal attack, the second the skill), 1 for the
# burst, 2 for passives. Order of the keys is the game's own talent order.
NORMAL, SKILL, BURST = "normalAttack", "elementalSkill", "elementalBurst"


def fetch(url: str) -> dict:
    """Fetches JSON with curl — Yatta answers urllib with a 403."""
    result = subprocess.run(
        ["curl", "-sSL", "--max-time", "60", "-A",
         "ns-launcher/talent-params (github.com/ngosangns/ns-launcher)", url],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {url}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def has_table(talent: dict) -> bool:
    """Whether a levelled talent actually carries a level-10 scaling table.
    An alternate sprint (Ayaka's "Kamisato Art: Senho", Mona's "Illusory
    Torrent") is type 0 with a `promote` block and no rows in it."""
    level_ten = talent.get("promote", {}).get("10")
    return bool(level_ten and any(line.strip() for line in level_ten["description"]))


def combat_talents(avatar: dict) -> dict[str, dict]:
    """The three levelled talents, keyed by slot, in the game's own order.

    Yatta types the normal attack and the skill both as 0; the normal attack
    comes first and is the one whose table has numbered hits. A third type-0
    entry is an alternate sprint and has no table — see `has_table`."""
    levelled = [t for _, t in sorted(avatar["talent"].items(), key=lambda kv: int(kv[0])) if has_table(t)]
    type_zero = [t for t in levelled if t["type"] == 0]
    bursts = [t for t in levelled if t["type"] == 1]
    if len(type_zero) != 2 or len(bursts) != 1:
        raise SystemExit(f"{avatar['name']}: expected 2 type-0 talents with tables and 1 burst, "
                         f"got {[t['name'] for t in type_zero]} and {[t['name'] for t in bursts]}")
    normal, skill = type_zero
    # The normal attack has no cooldown and the skill has one; that is the
    # invariant the order rests on, and it is checked rather than trusted. (A
    # "1-Hit" row is not the check: a single-hit catalyst like Ningguang's
    # writes its one hit as "Normal Attack DMG".)
    if normal.get("cooldown", 0) != 0 or skill.get("cooldown", 0) == 0:
        raise SystemExit(f"{avatar['name']}: type-0 talents {normal['name']!r} (cd {normal.get('cooldown')}) "
                         f"and {skill['name']!r} (cd {skill.get('cooldown')}) are not normal-attack-then-skill")
    return {NORMAL: normal, SKILL: skill, BURST: bursts[0]}


def shape(line: str) -> str:
    """A line with each placeholder's format reduced to the one bit the reader
    uses: percent or not. `{param5:F1P}` at one level and `{param5:P}` at
    another are the same row printed to a different precision."""
    return re.sub(r"\{param(\d+):([A-Z0-9]+)\}",
                  lambda m: "{param%s:%s}" % (m.group(1), "P" if m.group(2).endswith("P") else "N"), line)


def talent_record(talent: dict) -> dict:
    """One talent, verbatim: the lines as the game phrases them and the raw
    params per level. Levels are a 1-indexed list so `params[9]` is level 10,
    which is what the model scores at.

    The lines are *not* identical at every level, and that was checked rather
    than assumed: across 118 characters, 43 talents change format precision
    between levels (harmless), five change wording ("Cyclic" → "Cycling"), and
    two — Freminet's skill and Jean's burst at level 15 — renumber their
    placeholders, so level 15's lines read level 15's params differently from
    level 10's. Hence `lines` holds level 10's lines and `lineOverrides` holds
    the full line list for any level whose lines differ in anything the reader
    would see; a level absent from the overrides reads `lines`."""
    promote = talent["promote"]
    levels = sorted(int(k) for k in promote)
    if levels != list(range(1, len(levels) + 1)):
        raise SystemExit(f"{talent['name']}: levels are not 1..N: {levels}")
    if 10 not in levels:
        raise SystemExit(f"{talent['name']}: no level 10")

    def lines_at(level: int) -> list[str]:
        return [line for line in promote[str(level)]["description"] if line.strip()]

    base = lines_at(10)
    base_shape = [shape(line) for line in base]
    overrides = collections.OrderedDict()
    for level in levels:
        theirs = lines_at(level)
        if [shape(line) for line in theirs] != base_shape:
            overrides[str(level)] = theirs

    record = collections.OrderedDict([
        ("name", talent["name"]),
        ("cooldown", talent.get("cooldown", 0)),
        ("energyCost", talent.get("cost", 0)),
        ("lines", base),
    ])
    if overrides:
        record["lineOverrides"] = overrides
    record["params"] = [promote[str(level)]["params"] for level in levels]
    return record


def main() -> int:
    with open(GAME_IDS, encoding="utf-8") as handle:
        by_game_id = json.load(handle)["characters"]

    characters: dict[str, dict] = {}
    for game_id, slug in sorted(by_game_id.items(), key=lambda kv: kv[1]):
        avatar = fetch(YATTA.format(id=game_id))["data"]
        talents = combat_talents(avatar)
        characters[slug] = collections.OrderedDict(
            [("gameId", int(game_id))] + [(slot, talent_record(t)) for slot, t in talents.items()])
        print(f"  {slug}")

    output = collections.OrderedDict([
        ("_doc", "Hệ số talent của từng nhân vật đúng như file game ghi, mọi cấp 1-15, "
                 "lấy qua gi.yatta.moe/api/v2/en/avatar. SINH TỰ ĐỘNG bằng "
                 "scripts/sync-abyss-talent-params.py — đừng sửa tay. `lines` là dòng mô tả "
                 "nguyên văn ('Skill DMG|{param1:P} Max HP'), `params[i]` là mảng số của cấp i+1; "
                 "việc đọc dòng nào là damage, dòng nào là lựa chọn thay thế, cộng/nhân ra sao "
                 "nằm ở Swift (AbyssTalentReader), nơi mỗi luật là một test. Bảy Nhà Lữ Hành "
                 "không có ở đây (Yatta gộp chung một avatar), vẫn đi đường parse văn xuôi."),
        ("source", "gi.yatta.moe/api/v2/en/avatar/{id}, id từ game-ids.json"),
        ("characters", characters),
    ])
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print(f"wrote {len(characters)} characters to {os.path.relpath(OUTPUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
