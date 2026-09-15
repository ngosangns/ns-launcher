#!/usr/bin/env python3
"""Writes Resources/Abyss/particles.json: how many Elemental Particles each
character's Elemental Skill generates, as the Genshin Impact wiki records it.

## Why this exists

Phase 3 of docs/redesign.md models energy: how often a burst is actually up,
which is what gives Energy Recharge a value. That needs one number per
character that no game file the project reads carries — the particle count of
the skill. Yatta has cooldowns, burst costs, gauge units and ICD, but not
particles; they live in the game's ability configs and are measured by the
community. The wiki writes them in one template on each skill's page,

    {{Talent Note|particles|2.25|3}}                 press 2.25, hold 3
    {{Talent Note|particles|5}}                      one number
    {{Talent Note|particles|each of Oz's attacks|0.67}}   per event
    {{Talent Note|particles|0}}                      none

and that template is what this script reads. gcsim's character code
(github.com/genshinsim/gcsim) was used to cross-check the per-event shape: a
summon's particles are per hit and bounded by an ICD, which is why "per
event" entries cannot be turned into a per-cast number here. How many events
one cast produces is a fact about how the kit is played, and it lives in
`character-kits.json` → `energy.eventsPerCast`, with its reasoning.

## What is written

Each character's page title and revision id, the template parameters
verbatim, and a normalised reading of them:

- `press` / `hold` — particles per cast, for the numeric shapes;
- `perEvent` — `{event, count}`, for the "each X" shape.

A shape the rules below do not recognise is reported and not written — the
character then has no entry, which `AbyssDataLibrary` reports in turn. A page
with no template at all is recorded with empty `notes` so the gap is visible
in the file rather than only in a log.

## Usage

    python3 scripts/sync-abyss-particles.py

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
import time
import urllib.parse

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(REPO, "Sources", "NSLauncherApp", "Resources", "Abyss")
TALENTS = os.path.join(DATA, "talent-params.json")
OUTPUT = os.path.join(DATA, "particles.json")
API = "https://genshin-impact.fandom.com/api.php?"
UA = "ns-launcher/particles (github.com/ngosangns/ns-launcher)"


def fetch(page: str) -> dict:
    url = API + urllib.parse.urlencode(
        dict(action="parse", page=page, prop="wikitext|revid", format="json", redirects=1))
    result = subprocess.run(["curl", "-sSL", "--max-time", "60", "-A", UA, url],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"curl failed for {page}: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    if "parse" not in data:
        raise SystemExit(f"{page}: {data.get('error', data)}")
    return data["parse"]


def templates(text: str, name: str) -> list[list[str]]:
    """Every `{{name|...}}` in `text`, split into top-level parameters. Nested
    templates and links (`{{Not a Typo|...}}`, `[[A|B]]`) stay inside the
    parameter they belong to instead of splitting it."""
    found = []
    start = 0
    opener = "{{" + name + "|"
    while (i := text.find(opener, start)) >= 0:
        depth, j, params, current = 0, i + 2, [], ""
        while j < len(text):
            pair = text[j:j + 2]
            if pair in ("{{", "[["):
                depth += 1
                current += pair
                j += 2
                continue
            if pair in ("}}", "]]"):
                if depth == 0 and pair == "}}":
                    break
                depth -= 1
                current += pair
                j += 2
                continue
            if text[j] == "|" and depth == 0:
                params.append(current)
                current = ""
            else:
                current += text[j]
            j += 1
        params.append(current)
        found.append([p.strip() for p in params[1:]])  # drop the template name
        start = j
    return found


def number(value: str) -> float | None:
    """A particle count as the wiki writes it. `~4.3` is the wiki's own
    approximation marker and is kept as the number it approximates, and a
    `{{Not a Typo|0.67}}` wrapper is the wiki vouching for the number inside
    it; anything else that is not a plain decimal is refused."""
    cleaned = plain(value).lstrip("~")
    return float(cleaned) if re.fullmatch(r"\d+(\.\d+)?", cleaned) else None


def plain(value: str) -> str:
    """Wiki markup out of an event description: `[[A|B]]` → B, `{{T|x}}` → x."""
    value = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", value)
    value = re.sub(r"\{\{[^|}]*\|([^}]*)\}\}", r"\1", value)
    return value.strip()


def reading(params: list[str]) -> dict | None:
    """The template's own branches (Template:Talent_Note, `particles`):
    a numeric first parameter is a count, with an optional numeric second for
    hold; a non-numeric first parameter is the event, and the second its count.
    `particles` itself is params[0]."""
    args = params[1:]
    if not args:
        return None
    first = number(args[0])
    if first is not None:
        if len(args) == 1:
            return {"press": first}
        second = number(args[1])
        # A non-numeric second parameter after a count renders as garbage on
        # the wiki ("… 5 if pressed and 'Ring-A-Ding-Ding! DMG' if held"): the
        # count is the page's intent, the rest is an editing slip.
        return {"press": first, "hold": second} if second is not None else {"press": first}
    count = number(args[-1])
    if count is None:
        return None
    return {"perEvent": {"event": plain("|".join(args[:-1])), "count": count}}


def main() -> int:
    with open(TALENTS, encoding="utf-8") as handle:
        talents = json.load(handle)["characters"]

    characters: dict[str, dict] = collections.OrderedDict()
    refused: list[str] = []
    for slug in sorted(talents):
        page = talents[slug]["elementalSkill"]["name"]
        parsed = fetch(page)
        notes = [p for p in templates(parsed["wikitext"]["*"], "Talent Note") if p and p[0] == "particles"]
        readings = []
        for params in notes:
            value = reading(params)
            if value is None:
                refused.append(f"{slug}: {params}")
                continue
            readings.append(value)
        characters[slug] = collections.OrderedDict([
            ("page", parsed["title"]),
            ("revid", parsed["revid"]),
            ("notes", [p[1:] for p in notes]),
            ("readings", readings),
        ])
        print(f"  {slug}: {readings or 'no note'}")
        time.sleep(0.4)

    if refused:
        print("refused shapes:\n  " + "\n  ".join(refused), file=sys.stderr)
        return 1

    output = collections.OrderedDict([
        ("_doc", "Số hạt nguyên tố Kỹ năng Nguyên tố của từng nhân vật tạo ra, đúng như Genshin Impact Wiki ghi "
                 "({{Talent Note|particles|...}} trên trang kỹ năng). SINH TỰ ĐỘNG bằng scripts/sync-abyss-particles.py — "
                 "đừng sửa tay. `notes` là tham số template nguyên văn; `readings` là cách đọc: press/hold = hạt mỗi lần "
                 "dùng, perEvent = hạt mỗi SỰ KIỆN (mỗi đòn của Oz, mỗi hơi của Guoba) — số sự kiện mỗi lần dùng là tri thức "
                 "kit, nằm ở character-kits.json → energy.eventsPerCast. `notes` rỗng = trang không có ghi chú, số hạt phải "
                 "bổ sung ở character-kits.json → energy.particlesPerCast kèm nguồn. Số liệu do cộng đồng đo, không phải "
                 "file game; gcsim (github.com/genshinsim/gcsim) dùng để đối chiếu."),
        ("source", "genshin-impact.fandom.com/api.php?action=parse — trang Elemental Skill theo tên trong talent-params.json"),
        ("fetchedOn", datetime.date.today().isoformat()),
        ("characters", characters),
    ])
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(output, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print(f"wrote {len(characters)} characters to {os.path.relpath(OUTPUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
